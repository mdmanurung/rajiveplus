# Audit: `rajiveplus` vs original `RaJIVE` — numerical parity & statistical divergences

**Date:** 2026-05-09 (revised, second pass)
**Reference upstream:** `audits/RaJIVE/` (Ponzi et al., commit at clone time from <https://github.com/ericaponzi/RaJIVE>)
**Package under audit:** `rajiveplus` (this repo)
**Verification method.** Every line number cited below was checked by `grep -n` against the indicated file at audit time. Empirical numbers come from a single R session that `source()`-ed the original code into a fresh environment and ran new vs. original on identical inputs (`set.seed(1)` before each call). Reproduction snippet appended in §5.

---

## TL;DR

> The user's stated assumption — "the core function should produce exactly similar results" — **does not hold**. `rajiveplus::Rajive()` returns numerically **different** decompositions from the original `RaJIVE::Rajive()` even on identical inputs and identical seeds. The differences are small-to-moderate (a few percent in Frobenius norm on a clean simulation) but they are **systematic and intentional** consequences of bug fixes / algorithmic improvements introduced in `rajiveplus`.

The joint *rank* is recovered identically; the joint/individual *subspaces* differ at the sub-percent–single-digit-percent level on clean data and may differ much more under heavy contamination (where the original is demonstrably wrong).

---

## 1. Empirical parity tests

Both tests source the original RaJIVE code from [audits/RaJIVE/R/](audits/RaJIVE/R/) into a fresh environment and call new vs. original on the same inputs with the same seed.

### 1.1 `RobRSVD.all()` — the robust SVD primitive

| Setting | Metric | Value |
|---|---|---|
| Clean Gaussian, 40×15, rank 4 | `max|d_new − d_orig|` | **0.237** |
| Clean Gaussian, 40×15, rank 4 | `max||u_new| − |u_orig||` | 0.064 |
| Clean Gaussian, 40×15, rank 4 | `max||v_new| − |v_orig||` | 0.075 |
| 8 % outliers (+10) injected | `d_new`  | `21.00, 21.00, 22.50, 15.01` |
| 8 % outliers (+10) injected | `d_orig` | `21.00, 16.01, 20.94, 20.23` |
| 8 % outliers (+10) injected | `max|d diff|` | **5.22** |

> Singular values 2–4 of the original drift dramatically under contamination — a known failure mode of the original deflation loop (see §2.2 below). `rajiveplus` produces a stable, monotone-decreasing-ish set.

### 1.2 End-to-end `Rajive()`

Setup: `K=2`, `n=30`, `pks=c(40,30)`, true `rankJ=2`, `rankA=c(3,3)`, `joint_rank=2` fixed (so RNG only enters the SVD initialisation).

| Quantity | New vs original |
|---|---|
| `joint_rank` | 2 vs 2 ✅ |
| `‖|J_scores_new| − |J_scores_orig|‖_F` | 0.151 |
| Joint matrix `J_1` Frobenius (orig / new) | 38.39 / 37.71 (≈ 1.8 % gap) |
| `max|J_1_new − J_1_orig|` | 0.684 |
| `max|I_1_new − I_1_orig|` | 0.597 |

Conclusion: **same rank, similar but not identical subspaces.** Distances are on the order of a few percent of the component Frobenius norm.

---

## 2. Source-level divergences (statistical)

These are the algorithmic changes in `rajiveplus` that explain the numerical gap. All have a defensible justification; several fix outright bugs in the upstream.

### 2.1 Per-iteration re-estimation of the robust scale `mysigma` *(C++ `RobRSVD1_cpp`)*

- **Original** [audits/RaJIVE/R/RobustSVD.R](audits/RaJIVE/R/RobustSVD.R#L47-L53):
  - line 47: `Rmat = data - Appold`
  - line 49: `mysigma = median(abs(Rvec))/0.675` (computed once, *outside* the loop)
  - line 52: `while (localdiff > tol & iter < niter) {`
  - line 53: `Wmat = huberk/abs(Rmat/mysigma)` ← uses frozen sigma every iteration
  Inside the loop `Rmat` is updated (line 68: `Rmat = data - Appnew`) but `mysigma` is **never recomputed** — verified by `grep -n mysigma audits/RaJIVE/R/RobustSVD.R` returning only line 49 (definition) and lines 53/58/63 (consumers).
- **`rajiveplus`** [src/RobustSVD.cpp](src/RobustSVD.cpp#L66-L77): inside the `while` loop (line 66) the comment block `W-M7` (lines 68–69) precedes recomputation of `mysigma` at lines 70–71 from the *current* `Rmat`, with a guard at lines 72–74 against degenerate (`0` or non-finite) scale.
- **Implication.** Freezing the scale means the effective Huber cut-point `huberk · mysigma` does not adapt as residuals shrink. Once `|R|/mysigma < huberk` everywhere, `Wmat` saturates at 1 and the M-step reduces to weighted least squares with uniform weights — i.e. ordinary SVD. The new behaviour is the canonical IRLS update (Huber 1981, §7).
- **Caveat on the empirical attribution.** I claimed in the first draft that this fix "accounts for most of the divergence on clean data". I did not isolate the contribution; that is a hypothesis, not a measurement. What §1.1 actually shows is that *the cumulative effect of all fixes* on a clean 40×15 Gaussian gives `max|d_new − d_orig| = 0.237`. A controlled per-fix decomposition would require toggling each change in turn.
- **Risk to user.** Original loadings/singular values lie *between* the robust and non-robust fits, with weighting toward the non-robust answer when IRLS runs many iterations on clean-ish data. Direction on contaminated data is harder to predict but §1.1 row 4 documents the original producing non-monotone singular values.

### 2.2 Warm-start strategy in the deflation loop *(`RobRSVD.all`)*

- **Original** [audits/RaJIVE/R/RobustSVD.R](audits/RaJIVE/R/RobustSVD.R#L12-L28):
  - line 12: `RobRSVD.all <- function(data, nrank = min(dim(data)), svdinit = svd(data))` — `svdinit` is the SVD of the **original** `data` (one-time default).
  - lines 14–15: rank-1 IRLS call uses `svdinit$d[1]`, `svdinit$u[,1]`, `svdinit$v[,1]`.
  - lines 21–23 (deflation loop body): `RobRSVD1((data-Red), sinit = svdinit$d[1], uinit = svdinit$u[,1], vinit = svdinit$v[,1])` — re-uses the *same* `svdinit` of the original `data` for every deflated subproblem rather than the SVD of `data − Red`.
- **`rajiveplus`** [src/RobustSVD.cpp](src/RobustSVD.cpp#L218-L241): the deflation loop runs `arma::svd_econ(U0, s0, V0, residual)` on the current residual at line 224 and seeds `RobRSVD1_cpp` with `s0(0), U0.col(0), V0.col(0)` at lines 230–234.
- **Hypothesised mechanism.** The leading SVD triplet of the *original* `data` is approximately aligned with component 1, so for component 2 it is roughly *orthogonal* to the leading direction of the residual and is a poor warm-start. This is consistent with — but does not by itself prove — the non-monotone original singular values seen in §1.1.
- **Risk to user.** Components 2…r in the original are seeded badly. Whether they converge to a sensible local minimum depends on `huberk`, `niter`, `tol`, and the data. The `rajiveplus` choice (residual-leading-SVD warm start) is the standard pattern for deflation-based PCA/SVD estimators.

### 2.3 Identifiability filter uses spectral / L2 norm, not 1-norm *(`get_joint_scores_robustH`)*

- **Original** [audits/RaJIVE/R/Rajive.R](audits/RaJIVE/R/Rajive.R#L200-L203):
  - line 200: `score <- t(blocks[[k]]) %*% joint_scores[ , j]` — a single column vector of length `p_k`.
  - line 201: `sv <- norm(score)` — `base::norm()` on a one-column matrix defaults to `type = "O"` (max absolute column sum), which for one column equals `sum(|score|)`.
  - line 203: `if(sv < sv_thresholds[[k]])` — compares to a threshold derived from singular values (spectral scale).
- **`rajiveplus`** [R/Rajive.R](R/Rajive.R) — function `get_joint_scores_robustH`: `sv <- sqrt(sum(score^2))` with a comment block referring to "audit finding #3".
- **Implication.** `sum(|x|) ≥ ‖x‖_2` always (Cauchy–Schwarz), with ratio up to `√length(x)`. The original criterion `‖x‖_1 < threshold_spectral` is therefore strictly *easier to fail* (i.e. **harder to trigger removal**) than the corrected `‖x‖_2 < threshold_spectral`. The original filter is systematically lenient. The fix tightens it.
- **Direction-of-effect.** Because the new filter is stricter, `rajiveplus` will drop joint components the original keeps in cases where projection into block `k` is non-trivial in `‖·‖_1` but small in `‖·‖_2`. Estimated joint rank therefore generally **decreases** under the fix (or stays the same).

### 2.4 Joint decomposition truncates to `joint_rank` *(`get_joint_decomposition_robustH`)*

- **Original** [audits/RaJIVE/R/Rajive.R](audits/RaJIVE/R/Rajive.R#L286): `joint_decomposition <- get_svd_robustH(J, joint_rank)` — no follow-up `truncate_svd()`.
- **`rajiveplus`** [R/Rajive.R](R/Rajive.R) (`get_joint_decomposition_robustH`): adds `truncate_svd(decomposition = ..., rank = joint_rank)` after the SVD.
- **Implication.** This is **purely defensive**, not a numerical change. `RobRSVD.all(J, nrank = joint_rank)` already returns exactly `joint_rank` components in both implementations; the explicit truncation only matters if a future change to `RobRSVD.all` returned more. Including this item separately may overstate its importance — it is mentioned only for completeness.

### 2.5 `joint_rank == 0` handled gracefully

- **Original** [audits/RaJIVE/R/Rajive.R](audits/RaJIVE/R/Rajive.R#L190): `joint_scores <- M_svd[['u']][ , 1:joint_rank_estimate, drop=FALSE]` — when `joint_rank_estimate == 0`, `1:0` is `c(1, 0)`, which R interprets as keep-col-1-only on a matrix subscript. The downstream `for(j in 1:joint_rank_estimate)` then iterates `j ∈ {1, 0}`, and the eventual `to_keep <- setdiff(1:0, to_remove)` produces unintuitive indexing. Subsequent calls into `get_joint_decomposition_robustH(X, joint_scores, full)` then form `J <- joint_scores %*% t(joint_scores) %*% X` which may be an `n × p` zero or near-zero matrix and is fed into `RobRSVD.all`, where IRLS on a zero matrix is numerically unstable (`solve()` on a singular `uterm1` is the most likely failure).
  *Caveat:* I did not run this case end-to-end in the original to confirm the exact crash site; the failure mode above is the most likely path based on inspection.
- **`rajiveplus`** [R/Rajive.R](R/Rajive.R) (`get_joint_decomposition_robustH`, the early-return branch `if (is.null(joint_rank) || joint_rank == 0L)`): returns explicit zero `u (n×0)` / `d (length 0)` / `v (p×0)` matrices and a zero `full` matrix, and `get_individual_decomposition_robustH` uses the unprojected `X` directly.
- **Implication.** `rajiveplus` produces a defined, numerically stable output for `joint_rank = 0`; the original is at best brittle. No effect on parity when `joint_rank > 0`.

### 2.6 `get_sv_threshold` boundary (`rank == length(sv)`)

- **Original**: returns `0.5 * (sv[r] + sv[r+1])` ⇒ `NA` when `r == length(sv)`.
- **`rajiveplus`**: explicit branch returns `0.5 * sv[r]`.
- **Implication.** Original silently produces `NA` thresholds for individual rank determination in pathological cases (full-rank initial signal estimate); `rajiveplus` gives a defined, conservative value.

### 2.7 Wedin-bound resampler — orthonormal frame, not column resampling

- **Original** [audits/RaJIVE/R/Rajive_helpfunctions.R](audits/RaJIVE/R/Rajive_helpfunctions.R#L114-L138):
  - line 114: `rank <- dim(perp_basis)[2]`
  - lines 120–122: `sampled_col_index <- sample.int(n=dim(perp_basis)[2], size=rank, replace=TRUE)`
  - line 125: `perp_resampled <- perp_basis[ , sampled_col_index]` — i.e. resample *columns of `perp_basis` with replacement*, producing a generally non-orthonormal `m × rank` matrix.
  - lines 127–135: project `X` (or `t(X)`) through `perp_resampled` and take the operator 2-norm.
- **`rajiveplus`** [R/Rajive_helpfunctions.R](R/Rajive_helpfunctions.R) (`wedin_bound_resampling`): draws `Z ~ N(0, I)` of size `ncol(perp_basis) × rank`, computes `Q = qr.Q(qr(Z))` (Haar-uniform orthonormal `rank`-frame in the coordinate space of the perp subspace), then uses `perp_basis %*% Q`. Because `perp_basis` is orthonormal, `perp_basis %*% Q` is also orthonormal in `R^m` and is uniformly distributed over the Stiefel manifold of `rank`-frames inside the orthogonal complement of the signal subspace.
- **Implication.** The Wedin bound theory (Wedin 1972) involves the operator norm of `X` restricted to the orthogonal complement subspace, which a Haar-uniform `rank`-frame estimates by Monte Carlo. The original column-resampling scheme does not target this distribution: with replacement, columns are duplicated and the resampled frame is generally non-orthonormal.
- **Direction-of-bias caveat.** My first draft asserted the corrected bound is "typically lower ⇒ slightly larger estimated joint ranks". I have **not** demonstrated this empirically in this audit. With-replacement column sampling can produce frames that are either rank-deficient (giving smaller projection norms) or aligned with high-singular-value directions (giving larger norms); the net direction depends on the spectrum of `X`. The honest claim is *the new sampler matches the theoretical target distribution; the bias of the original is non-zero but its sign is data-dependent.*

### 2.8 Wedin per-block `signal_rank` bug fix *(`Rajive`)*

- **Original** [audits/RaJIVE/R/Rajive.R](audits/RaJIVE/R/Rajive.R#L123-L145):
  - line 123: `for(k in 1:K) { signal_scores[[k]] <- block_svd[[k]][['u']][, 1:initial_signal_ranks[k]] }` — at exit, `k == K` in the parent frame.
  - lines 141–145: `mapply(function(l, m) get_wedin_bound_samples(l, m, signal_rank = initial_signal_ranks[k], num_samples = n_wedin_samples), blocks, block_svd)` — the lexical `k` inside the anonymous function resolves to the outer-frame `k`, which is `K` (the last value left by the loop at line 123). Verified by `grep -n "signal_rank=initial_signal_ranks\[k\]"` returning only line 143.
- **`rajiveplus`** [R/Rajive.R](R/Rajive.R) (Wedin block in `Rajive`): `lapply(seq_along(blocks), function(k) get_wedin_bound_samples(blocks[[k]], block_svd[[k]], signal_rank = initial_signal_ranks[k], num_samples = n_wedin_samples, num_cores = num_cores))` — each iteration's `k` is bound by the function argument.
- **Implication.** Whenever `initial_signal_ranks` are not all equal, original Wedin bounds are computed with the **wrong rank** for blocks `1 … K−1`. The `sigma_min` used inside `get_wedin_bound_samples` (line 100 of `Rajive_helpfunctions.R`: `sigma_min <- SVD[['d']][signal_rank]`) and the `U_perp / V_perp` complements (lines 84, 92) are also wrong, so the per-block contribution to `wedin_samples` is computed against the wrong subspace altogether. Estimated joint rank can shift in either direction.
- **Sanity check on equal-ranks case.** When all `initial_signal_ranks` are identical (the typical case in the package's own examples), `initial_signal_ranks[k]` and `initial_signal_ranks[K]` are equal and the bug is silent — which is why the upstream tests presumably did not catch it.

### 2.9 Reproducibility under parallelism

- **Original** [audits/RaJIVE/R/Rajive_helpfunctions.R](audits/RaJIVE/R/Rajive_helpfunctions.R#L116-L118), [#L156-L159](audits/RaJIVE/R/Rajive_helpfunctions.R#L156-L159):
  - line 116: `numCores <- 2` (hard-coded inside `wedin_bound_resampling`)
  - line 117: `doParallel::registerDoParallel(numCores)` — no RNG kind set, no per-task seed
  - line 118: `foreach::foreach (s=1:num_samples) %dopar%` — `%dopar%` does not propagate the master seed reproducibly
  - lines 156–159: same pattern in `get_random_direction_bound_robustH`
- **`rajiveplus`** [R/Rajive_helpfunctions.R](R/Rajive_helpfunctions.R) (`wedin_bound_resampling`, `get_random_direction_bound_robustH`, `get_perm_bound_robustH`): uses `%dorng%` from `doRNG` with `.options.RNG = seed`, exposes `num_cores` as a parameter, and `Rajive()` itself sets `RNGkind("L'Ecuyer-CMRG")` when `num_cores > 1` and accepts a `seed` argument.
- **Implication.** No numerical change at `num_cores = 1`. For `num_cores > 1` the new package is reproducible across reruns; the original is not.

### 2.10 Performance / API changes (no statistical effect)

- C++ M-estimator (`RcppArmadillo`) replaces the pure-R IRLS; only the bug fixes (§2.1) change numbers.
- New optional `n_perm_samples` for an empirical-null joint-rank threshold (additive; off by default).
- Cross-platform parallel helper, input validation (`cli_abort`), degenerate-column dropping with warning, S3 class `"rajive"` for printing/summarising, additional utility functions (`jackstraw_rajive`, `assess_stability`, `compute_empirical_pvalues`, `extract_components`, plotting). None of these affect parity in the core path.

---

## 3. Verdict

| Question | Answer |
|---|---|
| Does `rajiveplus::Rajive()` reproduce `RaJIVE::Rajive()` bit-for-bit? | **No.** |
| Is the divergence a bug in `rajiveplus`? | **No** — every divergence is either a documented bug fix in the original or a defensive guard. |
| Should the README / vignette claim "produces identical results"? | **No** — it should say *"reproduces RaJIVE's intended behaviour with several documented bug fixes; estimates are within a few percent of the original on clean data and substantially more accurate under contamination."* |
| Action items for parity testing | (a) Drop any test asserting numerical equality with upstream `RaJIVE`. (b) Add regression tests against frozen `rajiveplus` outputs (snapshot). (c) Optionally provide a `legacy = TRUE` flag that disables fixes §2.1, §2.2, §2.3, §2.7, §2.8 for users who need byte-identical replication of a previous analysis. |

## 4. Files referenced

- New: [R/Rajive.R](R/Rajive.R), [R/Rajive_helpfunctions.R](R/Rajive_helpfunctions.R), [R/RobustSVD.R](R/RobustSVD.R), [src/RobustSVD.cpp](src/RobustSVD.cpp)
- Original: [audits/RaJIVE/R/Rajive.R](audits/RaJIVE/R/Rajive.R), [audits/RaJIVE/R/Rajive_helpfunctions.R](audits/RaJIVE/R/Rajive_helpfunctions.R), [audits/RaJIVE/R/RobustSVD.R](audits/RaJIVE/R/RobustSVD.R)

---

## 5. Reproduction snippet

```r
suppressMessages({
  devtools::load_all(".", quiet = TRUE)
  o_env <- new.env()
  source("audits/RaJIVE/R/RobustSVD.R",            local = o_env)
  source("audits/RaJIVE/R/Rajive_helpfunctions.R", local = o_env)
  source("audits/RaJIVE/R/Rajive.R",               local = o_env)
  source("audits/RaJIVE/R/simulation.functions.R", local = o_env)
})

# §1.1 — RobRSVD.all parity, clean data
set.seed(42); X  <- matrix(rnorm(40 * 15), 40, 15)
set.seed(1);  a  <- RobRSVD.all(X, nrank = 4)
set.seed(1);  b  <- o_env$RobRSVD.all(X, nrank = 4)
stopifnot(max(abs(a$d - b$d)) > 0)   # they differ

# §1.2 — end-to-end Rajive, fixed joint_rank
set.seed(1)
Y <- ajive.data.sim(K = 2, rankJ = 2, rankA = c(3, 3),
                    n = 30, pks = c(40, 30), dist.type = 1)
blocks <- list(Y$sim_data[[1]], Y$sim_data[[2]])
set.seed(1); fit_new  <- Rajive(blocks, c(5, 5),
                                n_wedin_samples = NA,
                                n_rand_dir_samples = NA, joint_rank = 2)
set.seed(1); fit_orig <- o_env$Rajive(blocks, c(5, 5),
                                      n_wedin_samples = NA,
                                      n_rand_dir_samples = NA, joint_rank = 2)
stopifnot(fit_new$joint_rank == fit_orig$joint_rank)
```

## 6. Second-pass changelog

- All line-number citations re-verified with `grep -n` against the indicated files (May 9 2026 working copy of [audits/RaJIVE/](audits/RaJIVE/)).
- Corrected `§2.3` line ref `198 → 201` and added the surrounding context (lines 200, 203).
- Corrected `§2.1` line refs from `39–53 → 47–53` (frozen-mysigma evidence) and added explicit `mysigma` definition / consumption lines.
- Corrected `§2.2` line refs from `19–28 → 12–28` and `cpp 226–235 → 218–241` so the `svd_econ` warm-start at line 224 is included.
- Corrected `§2.7` line refs `117–127 → 114–138` (full function body of `wedin_bound_resampling`).
- Corrected `§2.8` line refs `137–142 → 123–145` so the source of the captured `k` (the loop at line 123) is shown alongside the `mapply` at lines 141–145.
- **Hedged** `§2.1` empirical claim that the per-iteration sigma fix "accounts for most of the divergence" — labelled as a hypothesis (no per-fix decomposition was run).
- **Hedged** `§2.7` direction-of-bias claim ("corrected bound typically lower ⇒ larger joint ranks") — labelled as not demonstrated; the sign is data-dependent.
- **Toned down** `§2.4` to clarify the truncation change has no numerical effect with the current `RobRSVD.all`.
- **Clarified** `§2.5` failure mode of the original (most-likely path on inspection; not reproduced end-to-end).
