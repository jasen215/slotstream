#!/usr/bin/env python3
#!/usr/bin/env python3
"""Checks for Tools/expert_lookahead_ranking.py: analytic gradients, and the intent of the objective.

Run from the repository root: `python3 Tools/expert_lookahead_ranking_check.py`. It needs no model and
no capture: every case is synthetic, and it exits non-zero on the first failure. Not yet part of
Tools/static_gates.sh; promotion to a gate is a separate change.

The two things it is here to catch: a sign or normalisation error in the pairwise hinge (against a
finite-difference reference), and a form that cannot learn a ranking the raw tap does not have -- the
whole reason the ranking objective is under test at all.
"""

import sys

import numpy as np

sys.path.insert(0, "Tools")
import expert_lookahead_ranking as rk

rng = np.random.default_rng(7)
D, E, H, N = 8, 6, 4, 40
rk.TOPK = 3                                    # small top-k so the pair set is checkable
rk.learned.TOPK = 3                            # learned.agreement_sum reads its own module global
PAIRS = rk.TOPK * (rk.TOPK - 1) // 2


def make():
    x = rng.standard_normal((N, D)).astype(np.float32)
    w_true = rng.standard_normal((D, E)).astype(np.float32)
    z = (x @ w_true).astype(np.float32)
    if np.random.default_rng(1).random() < 0:
        pass
    z += rng.standard_normal(z.shape).astype(np.float32) * 0.3
    p = rng.standard_normal((N, E)).astype(np.float32) * 0.5
    return x, p, z


def check_labels():
    x, p, z = make()
    w, pos, top = rk.labels(z)
    assert pos.sum(axis=1).tolist() == [rk.TOPK] * N, "positive count must be top-k per row"
    assert np.array_equal(np.sort(top, axis=1), np.sort(np.argsort(-z, axis=1)[:, :rk.TOPK], axis=1))
    order = np.argsort(-z, axis=1, kind="stable")
    ranked = np.take_along_axis(w, order, axis=1)
    assert np.allclose(ranked[:, :rk.TOPK], rk.W_TOP10)
    assert np.allclose(ranked[:, rk.TOPK:30], rk.W_TOP30) if E > rk.TOPK else True
    print(f"labels ok: weights {np.unique(w).tolist()}, {PAIRS} pairs/row")


def check_gradients(arm):
    x, p, z = make()
    x, p, z = x.astype(np.float64), p.astype(np.float64), z.astype(np.float64)
    weight, positive, top = rk.labels(z)
    params = rk.init_params(arm, np.random.default_rng(3), D, E, H)
    for k in params:
        params[k] = (params[k] + rng.standard_normal(params[k].shape) * 0.1).astype(np.float64)

    def loss_at(pp):
        s = p + rk.forward(pp, arm, x)
        return rk.objective(s, z, weight, positive, top)[0]

    s = p + rk.forward(params, arm, x)
    grads = rk.backward(params, arm, x, s, z, weight, positive, top)
    eps, worst = 1e-6, 0.0
    for k, arr in params.items():
        flat = arr.reshape(-1)
        idx = rng.choice(len(flat), size=min(6, len(flat)), replace=False)
        for i in idx:
            old = flat[i]
            flat[i] = old + eps
            hi = loss_at(params)
            flat[i] = old - eps
            lo = loss_at(params)
            flat[i] = old
            num = (hi - lo) / (2 * eps)
            ana = float(grads[k].reshape(-1)[i])
            rel = abs(num - ana) / max(abs(num), abs(ana), 1e-6)
            worst = max(worst, rel)
            assert rel < 2e-2, f"{arm}.{k}[{i}]: analytic {ana:.6f} vs numeric {num:.6f} (rel {rel:.4f})"
    print(f"gradients ok ({arm}): worst relative error {worst:.2e}")


def check_intent(arm):
    """The objective's purpose: recover a ranking the raw tap does not have."""
    x = rng.standard_normal((400, D)).astype(np.float32)
    w_true = rng.standard_normal((D, E)).astype(np.float32) * 3
    z = (x @ w_true).astype(np.float32)
    routes = np.argsort(-z, axis=1)[:, :rk.TOPK]
    p = np.zeros_like(z)                                   # tap carries no signal at all
    xv, zv = x[:100], z[:100]
    rv = np.argsort(-zv, axis=1)[:, :rk.TOPK]
    rk.TOPK = 3
    got = rk.train_arm(x, p, z, routes, xv, p[:100], rv, arm, 3e-3, 0.0, H, 40, 64, 1729)
    first, last = got["history"][0], got["history"][-1]
    base = float(rk.learned.agreement_sum(p[:100], rv)) / 100   # agreement_sum returns a sum
    # Chance agreement is not 0 here: with top-3 of 6 experts a random set already hits about half
    # the true experts, so the bar is both a clear margin over that and a high absolute level.
    assert last["validation_agreement"] > max(base + 0.2, 0.75), (last, base)
    assert last["train_loss"] < first["train_loss"], (first, last)
    print(f"intent ok ({arm}): tap {base:.3f} -> {last['validation_agreement']:.3f} "
          f"(loss {first['train_loss']:.4f} -> {last['train_loss']:.4f}, epoch {got['epoch']})")


def check_init_is_the_tap(arm):
    x, p, z = make()
    params = rk.init_params(arm, np.random.default_rng(5), D, E, H)
    assert np.allclose(rk.forward(params, arm, x), 0.0), "an arm must start at the tap, not somewhere else"
    print(f"init ok ({arm}): starts exactly at the tap's own score")


for arm in ("linear", "two_layer"):
    check_init_is_the_tap(arm)
    check_gradients(arm)
check_labels()
for arm in ("linear", "two_layer"):
    check_intent(arm)
print("ALL RANKING CHECKS PASS")
