#!/usr/bin/env python3
"""Ranking-aware predictor forms for the same-layer pre-attention forecast.

Protocol `xla4-form-20260926`, arms (b) and (c) of
[[records/plan/2026-09-26-pre-attention-forecast-form-and-issue-decision]]. The reader is the one the
pre-attention paper itself uses ([[sources/references/2026/09/2026-09-26-pre-attention-expert-prediction]]):

  * the objective is multi-label classification over the expert axis, weighted binary cross-entropy
    with w = 3.0 for the real top-10, 1.5 for ranks 11 to 30 and 0.5 otherwise, plus `lambda` times a
    pairwise hinge ranking term over the pairs inside the top-10;
  * the forms are a rank-128 linear map (the shipped correction's own form, arm LR) and two linear
    layers with a SiLU between them (the paper's architecture 2, arm L2).

Two deliberate departures, both recorded in the registration and in `fit.json`:

  * the paper's intermediate size 2048 costs 6.29M parameters per layer at d = 2560, E = 512, while
    the adopted 35.2 MiB FP16 correction budget allows about 384k. `--hidden` defaults to 128, which
    is 393,216 parameters, the rank-128 form's exact count, so the forms are parameter-matched
    instead of matched to the paper's headline size;
  * every arm predicts a correction to the tap's own score, `s = p + f(u)`, and the loss is computed on
    the total. The shipped correction is a regression of the same residual, so this holds the tap
    term, the lead time and the parameter count fixed and isolates the objective and the form. The
    ranking term is normalized by the number of pairs where the paper writes a raw sum; `lambda`
    keeps its published value 0.3.

The frozen tools are not touched: this module imports them. Run `collect` from
`Tools/expert_lookahead_learned.py` first; the cache layout is that tool's.

    python3 Tools/expert_lookahead_ranking.py fit --cache <run>/cache --out <run>/fit-l2 \
            --arm two_layer --model-dir ~/.slotstream/models/qwen38-flash-next-mlx-4bit
    python3 Tools/expert_lookahead_ranking.py fit --cache <run>/cache --out <run>/fit-lr --arm linear
    python3 Tools/expert_lookahead_ranking.py compare --fits <run>/fit-ridge <run>/fit-lr <run>/fit-l2
"""

import argparse
import json
import time
from pathlib import Path

import numpy as np

import expert_lookahead as xla
import expert_lookahead_learned as learned
import expert_lookahead_probes as xp

LAYERS, EXPERTS, TOPK = learned.LAYERS, learned.EXPERTS, learned.TOPK
TARGETS, WIDTH, RANK = learned.TARGETS, learned.WIDTH, learned.RANK

# The paper's own constants (v1 source, equations for the ranking-aware loss).
W_TOP10, W_TOP30, W_REST = 3.0, 1.5, 0.5
RANK_LAMBDA, RANK_MARGIN = 0.3, 0.1

HIDDEN = RANK                      # 128 keeps the two-linear-layer form parameter-matched
EPOCHS, PATIENCE, BATCH, SEED = 20, 3, 1024, 1729
GRID = [(lr, wd) for lr in (1e-4, 3e-4, 1e-3) for wd in (0.0, 1e-2)]
SEARCH_LAYERS = [2, 16, 32, 46]


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


# ---------------------------------------------------------------- the objective

def labels(z):
    """Weight per (row, expert) and the top-10 sets, straight from the true router logits."""
    order = np.argsort(-z, axis=1, kind="stable")
    rank_of = np.empty_like(order)
    np.put_along_axis(rank_of, order, np.arange(order.shape[1])[None, :].repeat(len(z), 0), axis=1)
    weight = np.where(rank_of < TOPK, W_TOP10, np.where(rank_of < 30, W_TOP30, W_REST)).astype(np.float32)
    positive = np.zeros_like(z, dtype=bool)
    np.put_along_axis(positive, order[:, :TOPK], True, axis=1)
    return weight, positive, order[:, :TOPK]


def objective(s, z, weight, positive, top):
    """Weighted BCE over the expert axis plus the pairwise hinge inside the top-10."""
    n, e = s.shape
    sigma = 1.0 / (1.0 + np.exp(-np.clip(s, -30, 30)))
    ll = np.where(positive, np.log(np.maximum(sigma, 1e-12)), np.log(np.maximum(1.0 - sigma, 1e-12)))
    wbce = -float((weight * ll).sum()) / (n * e)
    s_top = np.take_along_axis(s, top, axis=1)                      # already ordered by z
    diff = s_top[:, :, None] - s_top[:, None, :]
    pairs = np.triu(np.ones((TOPK, TOPK), dtype=bool), 1)
    hinge = np.maximum(RANK_MARGIN - diff[:, pairs], 0.0)
    ranking = float(hinge.mean())
    return wbce + RANK_LAMBDA * ranking, wbce, ranking


# ---------------------------------------------------------------- the two forms

def init_params(arm, rng, d, e, hidden):
    if arm == "linear":
        return dict(a=(rng.standard_normal((d, hidden)) * 0.02).astype(np.float32), b=np.zeros((hidden, e), np.float32))
    if arm == "two_layer":
        return dict(w1=(rng.standard_normal((d, hidden)) * 0.02).astype(np.float32), b1=np.zeros(hidden, np.float32),
                    w2=np.zeros((hidden, e), np.float32), b2=np.zeros(e, np.float32))
    raise SystemExit(f"unknown arm: {arm}")


def forward(params, arm, x):
    if arm == "linear":
        return (x @ params["a"]) @ params["b"]
    h = x @ params["w1"] + params["b1"]
    return (h / (1.0 + np.exp(-h))) @ params["w2"] + params["b2"]


def backward(params, arm, x, s_total, z, weight, positive, top):
    """Gradients of `objective` w.r.t. the form's parameters, through the sigmoid and the hinge."""
    n, e = s_total.shape
    sigma = 1.0 / (1.0 + np.exp(-np.clip(s_total, -30, 30)))
    ds = weight * (sigma - positive) / (n * e)                      # d(wbce)/ds
    s_top = np.take_along_axis(s_total, top, axis=1)
    diff = s_top[:, :, None] - s_top[:, None, :]
    pairs = np.triu(np.ones((TOPK, TOPK), dtype=bool), 1)
    active = (RANK_MARGIN - diff[:, pairs]) > 0
    if active.any():
        rows, which = np.nonzero(active)
        a_idx, b_idx = np.nonzero(pairs)
        pair_a, pair_b = a_idx[which], b_idx[which]
        scale = RANK_LAMBDA / (n * pairs.sum())
        np.add.at(ds, (rows, top[rows, pair_a]), -scale)
        np.add.at(ds, (rows, top[rows, pair_b]), scale)
    # Gradients stay float64: the hinge term only touches a few entries of a (n, 512) matrix, and
    # rounding it to float32 first loses most of its significant digits. The update is cast instead.
    if arm == "linear":
        ha = x @ params["a"]
        return dict(a=x.T @ (ds @ params["b"].T), b=ha.T @ ds)
    h = x @ params["w1"] + params["b1"]
    act = h / (1.0 + np.exp(-h))
    dact = (1.0 / (1.0 + np.exp(-h))) * (1.0 + h * (1.0 - 1.0 / (1.0 + np.exp(-h))))  # SiLU'
    dh = (ds @ params["w2"].T) * dact
    return dict(w1=x.T @ dh, b1=dh.sum(0), w2=act.T @ ds, b2=ds.sum(0))


def adam_step(params, grads, state, lr, wd, step):
    b1, b2, eps = 0.9, 0.999, 1e-8
    for k, p in params.items():
        g = grads[k] + wd * p
        state.setdefault(k, [np.zeros_like(p), np.zeros_like(p)])
        m, v = state[k]
        m *= b1
        m += (1 - b1) * g
        v *= b2
        v += (1 - b2) * g * g
        mh = m / (1 - b1 ** step)
        vh = v / (1 - b2 ** step)
        p -= (lr * mh / (np.sqrt(vh) + eps)).astype(p.dtype)
    return state


# ---------------------------------------------------------------- training

def train_arm(x_tr, p_tr, z_tr, r_tr, x_va, p_va, r_va, arm, lr, wd, hidden, epochs, batch, seed, log_layer=None):
    weight, positive, top = labels(z_tr)
    rng = np.random.default_rng(seed)
    params = init_params(arm, rng, x_tr.shape[1], z_tr.shape[1], hidden)
    state, best = {}, dict(agreement=-1.0, epoch=-1, params=None, history=[])
    step, stale = 0, 0
    for epoch in range(1, epochs + 1):
        order = rng.permutation(len(x_tr))
        total = 0.0
        for start in range(0, len(order), batch):
            idx = order[start:start + batch]
            s = p_tr[idx] + forward(params, arm, x_tr[idx])
            g = backward(params, arm, x_tr[idx], s, z_tr[idx], weight[idx], positive[idx], top[idx])
            step += 1
            adam_step(params, g, state, lr, wd, step)
            total += float(objective(s, z_tr[idx], weight[idx], positive[idx], top[idx])[0]) * len(idx)
        # `learned.agreement_sum` is the frozen fit's own metric, kept so the arms are comparable; it
        # reads that module's TOPK, which is the same 10 as here, and returns a *sum* over rows (the
        # frozen fit only ever compares folds of equal size). Divide here so every reported and
        # selected value is an agreement fraction.
        val = float(learned.agreement_sum(p_va + forward(params, arm, x_va), r_va)) / max(len(r_va), 1)
        best["history"].append(dict(epoch=epoch, train_loss=total / len(x_tr), validation_agreement=val))
        if log_layer:
            log_layer(epoch, total / len(x_tr), val)
        if val > best["agreement"]:
            best.update(agreement=val, epoch=epoch, params={k: v.copy() for k, v in params.items()})
            stale = 0
        else:
            stale += 1
            if stale >= PATIENCE:
                break
    return best


def load_split(cache, rids, t):
    u, p, z, r = learned.load_rows(cache, rids, t)
    return (u.astype(np.float32), p.astype(np.float32), z.astype(np.float32), r)


def cmd_fit(args):
    learned.GATES = xp.load_gates(args.model_dir)
    cache, out = Path(args.cache), Path(args.out)
    (out / "forecasts").mkdir(parents=True, exist_ok=True)
    collected = xla.read_json(cache / "collect.json")
    train, val = collected["train"], collected["validation"]
    hidden, arm = args.hidden, args.arm

    chosen, search = GRID[0], []
    if args.search:
        for t in args.search_layers:
            x_tr, p_tr, z_tr, r_tr = load_split(cache, train, t)
            x_va, p_va, _, r_va = load_split(cache, val, t)
            for lr, wd in GRID:
                got = train_arm(x_tr, p_tr, z_tr, r_tr, x_va, p_va, r_va, arm, lr, wd, hidden,
                                args.epochs, args.batch, args.seed + t)
                search.append(dict(target=t, learning_rate=lr, weight_decay=wd, validation_agreement=got["agreement"],
                                   epochs_run=len(got["history"]), best_epoch=got["epoch"]))
                log(f"search T={t} lr={lr:g} wd={wd:g}: validation {got['agreement']:.4f} at epoch {got['epoch']}")
        mean = {}
        for lr, wd in GRID:
            rows = [r["validation_agreement"] for r in search if r["learning_rate"] == lr and r["weight_decay"] == wd]
            mean[(lr, wd)] = float(np.mean(rows))
        chosen = max(GRID, key=lambda k: (round(mean[k], 9), -GRID.index(k)))
        log(f"chosen hyperparameters: lr={chosen[0]:g} wd={chosen[1]:g} (mean validation {mean[chosen]:.4f})")

    val_rows = [int(np.load(cache / f"{rid}.where.npy", mmap_mode="r").shape[0]) for rid in val]
    bounds = np.concatenate([[0], np.cumsum(val_rows)])
    groups = {name: np.zeros((LAYERS, 5)) for name in ("tap", "arm")}
    per_request = {rid: {k: np.zeros((len(TARGETS), n, WIDTH), np.uint16 if k.startswith("ids") else np.float32)
                         for k in ("ids_full", "margins_full", "ids_rank", "margins_rank")}
                    for rid, n in zip(val, val_rows)}
    layers = []
    for t in TARGETS:
        started = time.time()
        x_tr, p_tr, z_tr, r_tr = load_split(cache, train, t)
        x_va, p_va, _, r_va = load_split(cache, val, t)
        got = train_arm(x_tr, p_tr, z_tr, r_tr, x_va, p_va, r_va, arm, chosen[0], chosen[1], hidden,
                        args.epochs, args.batch, args.seed + t)
        scores = p_va + forward(got["params"], arm, x_va)
        groups["tap"][t] = learned.metrics(p_va, r_va)
        groups["arm"][t] = learned.metrics(scores, r_va)
        ids, margins = learned.forecast_arrays(scores)
        for i, rid in enumerate(val):
            for key in ("full", "rank"):
                per_request[rid][f"ids_{key}"][t - 1] = ids[bounds[i]:bounds[i + 1]]
                per_request[rid][f"margins_{key}"][t - 1] = margins[bounds[i]:bounds[i + 1]]
        layers.append(dict(target=t, train_rows=len(x_tr), validation={n: learned.summarize(groups[n][t])
                                                                      for n in groups},
                           best_epoch=got["epoch"], history=got["history"]))
        v = layers[-1]["validation"]
        log(f"T={t}: arm {v['arm']['top10_agreement']:.4f} tap {v['tap']['top10_agreement']:.4f} "
            f"(epoch {got['epoch']}, {time.time() - started:.1f} s)")
    for rid in val:
        np.savez(out / "forecasts" / f"{rid}.npz", where=np.load(cache / f"{rid}.where.npy"), **per_request[rid])
    gate_rows = slice(2, LAYERS)
    pooled = {n: learned.summarize(acc[gate_rows].sum(axis=0)) for n, acc in groups.items()}
    params_per_layer = (2560 * hidden + hidden * 512 + 512) if arm == "linear" else (2560 * hidden + hidden + hidden * 512 + 512)
    report = dict(schema="expert-lookahead-ranking-fit-v1", arm=arm, hidden=hidden, cache=str(cache),
                  train=train, validation=val, chosen=dict(learning_rate=chosen[0], weight_decay=chosen[1]),
                  grid=GRID, search=search, epochs=args.epochs, patience=PATIENCE, batch=args.batch,
                  seed=args.seed, rank_lambda=RANK_LAMBDA, rank_margin=RANK_MARGIN,
                  weights=dict(top10=W_TOP10, top30=W_TOP30, rest=W_REST),
                  layers=layers, validation_pooled=pooled,
                  gain_over_tap=pooled["arm"]["top10_agreement"] - pooled["tap"]["top10_agreement"],
                  per_layer_parameters=int(params_per_layer),
                  fp16_weight_mib=float(params_per_layer * len(TARGETS) * 2 / 2**20),
                  duplicate_forms=True,
                  duplicate_forms_note=("this run trains one form, so ids_full and ids_rank carry the same "
                                        "forecasts; the twin's two codes are identical here by construction"),
                  checks=dict(stride0=collected["stride0_top10_set_match"],
                              offline_tap=collected["offline_tap_top10_set_match"]))
    xla.write_json(out / "fit.json", report)
    print(f"{'form':8s} {'rows':>8s} {'top10':>7s} {'exact':>7s} {'rec16':>7s} {'rec24':>7s}")
    for name, s in pooled.items():
        print(f"{name:8s} {s['rows']:8d} {s['top10_agreement']:7.4f} {s['exact_top10']:7.4f} {s['recall16']:7.4f} {s['recall24']:7.4f}")
    print(f"gain over tap {report['gain_over_tap']:+.4f}; {params_per_layer:,} parameters/layer, "
          f"FP16 {report['fp16_weight_mib']:.2f} MiB over {len(TARGETS)} target layers")


def cmd_compare(args):
    """One table for gate G5: every fitted form on the same rows and splits."""
    rows = []
    for path in args.fits:
        fit = xla.read_json(Path(path) / "fit.json")
        gate = slice(2, LAYERS)
        for name in ("tap", "full", "rank", "arm"):
            if name in fit.get("validation_pooled", {}):
                s = fit["validation_pooled"][name]
                rows.append(dict(fit=Path(path).name, form=name, rows=s["rows"], top10=s["top10_agreement"],
                                 exact=s["exact_top10"], rec16=s["recall16"], rec24=s["recall24"]))
    if not rows:
        raise SystemExit("no fit.json found under: " + ", ".join(args.fits))
    print(f"{'fit':22s} {'form':6s} {'top10':>7s} {'exact':>7s} {'rec16':>7s} {'rec24':>7s}")
    for r in rows:
        print(f"{r['fit']:22s} {r['form']:6s} {r['top10']:7.4f} {r['exact']:7.4f} {r['rec16']:7.4f} {r['rec24']:7.4f}")
    if args.out:
        xla.write_json(Path(args.out), dict(schema="expert-lookahead-ranking-compare-v1", rows=rows,
                                            gate_rows=[2, LAYERS - 1]))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="command", required=True)
    f = sub.add_parser("fit", help="train one ranking-aware form over every target layer")
    f.add_argument("--cache", required=True)
    f.add_argument("--out", required=True)
    f.add_argument("--arm", choices=("linear", "two_layer"), default="two_layer")
    f.add_argument("--hidden", type=int, default=HIDDEN)
    f.add_argument("--model-dir", default=str(xla.MODEL))
    f.add_argument("--epochs", type=int, default=EPOCHS)
    f.add_argument("--batch", type=int, default=BATCH)
    f.add_argument("--seed", type=int, default=SEED)
    f.add_argument("--search", action="store_true", help="run the declared grid on --search-layers and use its best")
    f.add_argument("--search-layers", type=int, nargs="+", default=SEARCH_LAYERS)
    f.set_defaults(func=cmd_fit)
    c = sub.add_parser("compare", help="one table across fitted forms (gate G5)")
    c.add_argument("--fits", nargs="+", required=True)
    c.add_argument("--out", default=None)
    c.set_defaults(func=cmd_compare)
    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
