# Independent Wedin derivation and pinned-source audit — RaJIVE+ stage1

## Scope and outcome

This is an independently authored mathematical/source audit, **not an estimator
change, default change, benchmark, or promotion recommendation**. The audited
local baseline is commit `3fecb8124dc0d7a1681155ff65462bb3305b8961`;
the original comparison source is **ericaponzi/RaJIVE at
`7d494d11029e538587ee9b27688adacf7f1f9841`**. Baseline bytes were extracted
with `git show`, avoiding dependence on subsequent parent working-tree edits.

**Pivotal conclusions**

1. The operator-norm Wedin expression uses **max of the left and right noise
   norms**, divided by a **positive cross-matrix spectral separation**, capped
   at one, then squared when used on squared-singular-value scale. Replacing
   max by min is invalid in general; a two-by-two counterexample below proves it.
2. `K - sum(error_bound^2)` has a short, valid **conditional projector-sum/min–max
   derivation**. It is not intrinsically a bug. It applies to orthogonal
   projectors and classical eigenvalues/singular values, not automatically to
   raw robust factors and robust fitted amplitudes.
3. The original code combines **one error draw per block, per Monte Carlo
   replicate**, then takes the lower 5% quantile. At ordinary dimensions its
   `t(mapply(...))`/`colSums` is correctly oriented for that operation. The
   baseline instead computes `K - sum(Q_.05(per-block squared errors))`.
   These are not equivalent; even the tail direction differs. This does not
   justify copying the original, which has independent rank-capture and
   complement-sampling defects.
4. The baseline’s observed statistic is a robust refactorization amplitude of
   **unorthogonalized robust score factors**. Its denominator is a robust
   rank-one amplitude `d[r]`, not a certified smallest retained singular value.
   The classical theorem does **not** currently certify this pipeline.
5. Wedin is diagnostic-only by default. A finite Wedin diagnostic can coexist
   with an effective threshold of **`-Inf`** when it is the only requested
   threshold source and its participation option is off. This selects every
   finite observed amplitude before the identifiability filter; it is not
   evidence that Wedin selected the rank.
6. The **active** baseline sampler requires `2*r <= n` **and** `2*r <= p_k`
   because it requests `r` complement-frame columns on both sides. Its
   inactive candidate handles low/saturated complements differently. Public
   rank validation is weaker than the active sampler’s complement constraint.

Classification throughout: **supported** = exact algebra/source inspection;
**conditional** = proved under explicit hypotheses; **heuristic** = a statistical
approximation not established as a coverage theorem here; **unresolved** = the
needed connection to the actual robust implementation is not established.

## 1. Source provenance and citeable evidence

`wedin_source_evidence.json` in the stage-1 deliverables gives file SHA256, byte counts, commit-specific paths,
line/equation locations, claim classifications and check IDs. Tool citation
indices below are the indices assigned during this independent workstream:

| ID / citation index | Source and stable locator | Role |
|---|---|---|
| W / **[18]** | Ren-Cang Li, *Relative Perturbation Theory: (II) Eigenspace and Singular Subspace Variations*, LAPACK Working Note 85, July 1994 / revised January 1996; §3.2, Theorem 3.4, Eq. (3.10), PDF p.6; residuals Eq. (3.8), p.5. `https://www.netlib.org/lapack/lawnspdf/lawn85.pdf` | Authoritative restatement of Wedin’s separated-spectrum theorem in any unitarily invariant norm; distinguish Theorem 3.3’s Frobenius result. |
| A / **[1], [7]** | Feng, Jiang, Hannig & Marron (2018), *Angle-based joint and individual variation explained*, JMVA **166**, 241–265, DOI `10.1016/j.jmva.2018.03.008`; §2.2.2 Theorem 1 (journal p.247), Corollary 1 / Eq.(3) and resampling (p.248); §2.3.2 Lemma 3 / Eq.(7), p.252; Fig.7 caption p.253; Appendix A proof pp.261–262. `https://ar5iv.labs.arxiv.org/html/1704.02060` | AJIVE-specific theorem, isotropic resampling motivation and K-block inequality. Downloaded published PDF separately. |
| R / **[12]** | Ponzi, Thoresen & Ghosh, *RaJIVE: Robust Angle Based JIVE for Integrating Noisy Multi-Source Data*, arXiv `2101.09110`; §2.2 (`#S2.SS2`), Appendix A (`#A1`), Eqs.(4),(5). `https://ar5iv.labs.arxiv.org/html/2101.09110` | Huber alternating regression, normalized rank-one factors, sequential deflation; not a robust Wedin coverage theorem. |
| OJ / **[21]** | Pinned original `R/Rajive.R`, lines 119–175 | Sample-axis convention, raw scores, captured rank, per-draw aggregation and threshold. |
| OH / **[9]** | Pinned original `R/Rajive_helpfunctions.R`, lines 83–139 | Two side norms, capped squared ratio and replacement sampling. |
| OR / **[22]** | Pinned original `R/RobustSVD.R`, lines 12–32, 69–79 | Sequential rank-one deflation and individual-column normalization. |

Original Wedin bibliographic provenance: P.-Å. Wedin (1972), *Perturbation bounds
in connection with singular value decomposition*, BIT **12**, 99–111,
DOI `10.1007/BF01932678` (discovery indices [16],[17]). The primary 1972 full
text was **not** obtained; the mathematical theorem used here is grounded in
Li’s full theorem, AJIVE’s full statement, and the independent proof below,
not in a publisher abstract or a one-line search summary.

**Inherited material notice.** Downloaded papers and baseline source snapshots
were inspected separately and are **not included in the authored
deliverables**. Original RaJIVE `DESCRIPTION` declares `MIT + file LICENSE`;
the pinned `LICENSE` records `YEAR: 2021`, `COPYRIGHT HOLDER: Erica Ponzi`.
Retain those notices and applicable license terms if redistributing source.
Downloaded papers retain their authors’/publishers’ rights. Do not silently
bundle `inherited/` into a new authored artifact.

## 2. Orientation: original paper versus original and baseline implementation

AJIVE and the RaJIVE paper write `X_k` as **features × matched samples** and use
right singular subspaces in sample space. The pinned **implementation** does
the transpose convention:

- `X_k` is **n samples × p_k features**. Original simulation constructs
  `n × p_k` noise (`simulation.functions.R:48–55`).
- Original `Rajive.R:119–128` takes `n_obs = dim(blocks[[1]])[1]`, keeps
  `block_svd[[k]]$u[,1:r_k]`, and **column-concatenates** them into
  `M` of shape `n × sum(r_k)`.
- Baseline `R/Rajive.R:640–648` preserves that convention.
- Consequently the theoretical score projector is onto the **left** signal
  space of implementation `X_k`. The relevant operator is
  `M M' = sum_k Q_k Q_k'` when each score basis `Q_k` is orthonormal.
  AJIVE’s vertically stacked score matrix is its transpose.
- Helper flag `right_vectors=FALSE` means draw an `n × q` frame `U*` and
  compute `U*' X` (`q × p_k`), whose norm equals `||X' U*||_2`.
  `right_vectors=TRUE` means a `p_k × q` frame `V*` and `X V*` (`n × q`).
  **The flag does not identify the sample axis**; the sample axis is left in
  this implementation.

Swapping left/right names without transposing the matrices changes the target.
Both side norms enter the common max even though only one side is the
sample-score space.

## 3. Wedin’s operator-norm bound, including a direct derivation

Let `X=A+E`, and write a classical rank-`r` split

```
A = U1 Σ1 V1' + A0,           P_U=U1 U1', P_V=V1 V1',
X Vhat = Uhat Σhat,           X' Uhat = Vhat Σhat.
```

All retained factors are orthonormal, both retained spaces have dimension `r`,
and `Σhat` contains genuine singular values of `X`. Suppose

```
||A0||_2 <= α,        σ_min(Σhat) >= α+δ,        δ>0, α>=0.       (D1)
```

This is a **cross-matrix** gap: retained observed singular values against
discarded true signal singular values. It is not simply the observed adjacent
gap `d_r(X)-d_(r+1)(X)`, nor the midpoint threshold used in the later
identifiability filter. In Li’s Theorem 3.4 map `B=X`, `Btilde=A`, transposing
if necessary to meet its displayed rectangular orientation. The residuals then
have norms `||E Vhat||_2` and `||E' Uhat||_2`. The rank-correct α=0 case also
follows directly below, without a strict-α convention issue.

Define directed errors
`a=||(I-P_U)Uhat||_2`, `b=||(I-P_V)Vhat||_2`,
`R=||E Vhat||_2`, `S=||E' Uhat||_2`, and `d=σ_min(Σhat)`.
Project the two singular equations:

```
(I-P_U) Uhat Σhat = A0 Vhat + (I-P_U) E Vhat,
(I-P_V) Vhat Σhat = A0' Uhat + (I-P_V) E' Uhat.
```

Since `A0 V1=0` and `A0' U1=0`,

```
d a <= α b + R,                 d b <= α a + S.
```

Take `c=max(a,b)`. The inequality for the side attaining `c` gives
`(d-α)c <= max(R,S)`. Therefore

```
max(a,b) <= min(max(R,S)/δ, 1).                            (D2)
```

For **equal-dimensional** spaces, each directed error equals the spectral norm
of the corresponding difference of orthogonal projectors, equivalently the
sine of the largest principal angle. This proves the operator-norm form needed
here; it is not an assumption that the upstream formula must be right.

### Rank-correct denominator and side-specific sharpening

If `rank(A)=r`, `A0=0`, choose `δ=d>0`. The direct identities already imply

```
sin(theta_left,max)  <= min(||E Vhat||_2/d, 1),
sin(theta_right,max) <= min(||E' Uhat||_2/d, 1).
```

Using their **max** is a valid common, possibly looser bound. Using their **min**
is not a common bound, and is not generally valid even for the implementation’s
sample-left subspace. This distinction is important: a side-specific refinement
is not a license to replace max by min.

**Hand counterexample (C1).** Take

```
A = [[1,0],[0,0]],     X = [[1,0],[1/2,0]],     E=X-A.
Uhat=(2,1)'/sqrt(5),   Vhat=(1,0)',             d=sqrt(5)/2.
```

The actual left-space error is `1/sqrt(5)≈0.447214`.
`||E Vhat||=.5`, `||E' Uhat||=1/(2sqrt(5))≈.223607`.
The max ratio is the actual error; the min ratio is **.2**, too small.
Transpose this example to interchange left and right.

### Squaring, capping and gap limitations

The projector deficit is squared in the K-block inequality, so its bound is

```
b_k = [min(max(R_k,S_k)/δ_k, 1)]^2 in [0,1].              (D3)
```

The outer square is not another amplitude norm: it converts a sine bound into
a squared-sine/energy deficit. For a **positive** denominator, clipping before
or after squaring gives the same number. There is no validity for arbitrary
zero, negative or nonfinite denominators. E.g. `(3,4,d=10)` gives `.16`;
`(12,4,10)` gives `1`; a rank-correct `d=0` violates the premise.

If `r` underestimates true signal rank, (D1) needs the true discarded signal
norm; substituting `d_r(X)` as if `A0=0` is unjustified. One can instead regard
`A0` as additional perturbation when targeting `A1`, but then the numerator
contains `E+A0`, not just the original noise. The target retained signal must
still contain the common joint space for Section 4 to apply.

If true and estimated ranks differ, do **not** indiscriminately identify the
largest of `min(r,rhat)` principal angles with `||P-P_hat||_2`. Nested spaces
`span(e1)` and `span(e1,e2)` have listed principal angle zero but projector
difference norm one. For unequal ranks the useful quantity below is a
**directed** projection loss on the target joint space. Claims in AJIVE’s
rank-misspecification discussion require that care; they are not imported as a
blanket guarantee here.

## 4. Why `K - sum(error^2)` is conditionally correct

Let `J` be a genuine common subspace of dimension `j`, contained in every
true sample-signal space. Let `Q_k` be orthonormal bases for the estimated
sample spaces, `P_hat,k=Q_k Q_k'`, and assume the actual directed deficits satisfy

```
||(I-P_hat,k) P_J||_2 <= ε_k <= 1.
```

For every unit `x in J`,

```
x' (sum_k P_hat,k) x
  = sum_k ||P_hat,k x||^2
  = K - sum_k ||(I-P_hat,k)x||^2
 >= K - sum_k ε_k^2.                                     (D4)
```

The Courant–Fischer min–max principle gives

```
λ_j(sum_k P_hat,k) >= K - sum_k ε_k^2.
```

For `M=[Q_1 ... Q_K]`, these eigenvalues are the squared **classical** singular
values of `M`. Thus at least `j` values meet this lower bound. If Wedin’s
assumptions hold and `ε_k <= sqrt(b_k)`, one may replace `ε_k^2` by `b_k`.
This proves the conditional content of AJIVE Lemma 3, Eq.(7), independently of
its sequential appendix argument.

**What it does not prove:** that the leading observed vectors are individually
the true joint components; that all nonjoint values lie below the bound; exact
joint-rank recovery; or a false-positive/FWER/FDR guarantee. A threshold equal
to a lower bound is a segmentation device, not by itself a null test.
Strict `>` in source can also reject equality.

**C5:** two true rank-one sample spaces are `span(e1)`, with estimates
`(.8,.6)'` and `(.8,-.6)'`. Their projector sum has eigenvalues `1.28,.72`.
The bound `2 - .6² - .6² = 1.28` is attained.

## 5. Resampled quantities: approximation, pairing and quantiles

AJIVE §2.2.2 explicitly invokes an **isotropic error model** and approximates
unknown signal-direction noise norms by observed norms on random complement
subspaces. With a classical fitted rank-`r` signal and an orthonormal complement
frame, `X V* = (X-Ahat)V*` because `Ahat V*=0`; similarly for `U*' X`.
That algebraic equality does not prove the proposed resampling distribution
matches the unobserved noise norm: the estimated signal/complement depends on
the observed noise, and isotropy alone is not a finite-sample conditional
coverage theorem. Correlated/anisotropic errors and gross contamination need
additional justification. Treat that resampling step as **heuristic**, as
distinct from the deterministic theorem.

For per-block, per-replicate surrogate norms, the intended squared draw is

```
b[k,s] = min(max(a[k,s],c[k,s])/d[k],1)^2;
T[s] = K - sum_k b[k,s];
t_wedin = Q_.05(T[s]).                                   (D5)
```

The max is taken **within each replicate**, before squaring/reducing. A paired
product-distribution simulation presumes a specified dependence/coupling across
the two side norms and across blocks. Independently sampling both sides does
not establish the true joint law of two noise norms from one noise matrix.
The deterministic max theorem itself does not imply independence.

For R’s default empirical quantile interpolation (type 7), finite draws obey

```
Q_.05(K - sum_k b[k,s]) = K - Q_.95(sum_k b[k,s]).         (D6)
```

Neither side generally equals `K-sum_k Q_.05(b[k,])`, nor
`K-sum_k Q_.95(b[k,])`. Quantiles do not commute with summation or with general
paired bivariate max operations. Population quantiles do commute with suitable
scalar monotone transformations; R's type-7 interpolation need not commute
exactly with nonlinear squaring. The crucial noncommutation here is with the
across-block sum and the paired two-variable max, not a prohibition on all
monotone transformations.

**C3:** with two blocks, four replicates,

```
b[1,] = 0,0,1,1
b[2,] = 1,1,0,0,
```

every paired threshold draw equals `1`; its 5% quantile is `1`.
`2-sum(block Q_.05)` is `2`; `2-sum(block Q_.95)` is `0`. Thus simply
flipping `.05` to `.95` in a per-block reduction is **not** a proof of equivalence.

If one had independently validated simultaneous upper error certificates,
one could obtain a valid deterministic lower bound conditional on that event.
Separate nominal marginal certificates require an additional simultaneous
coverage argument (e.g. a union bound with allocated error probabilities).
No such certificate has been established for these resampled robust quantities,
and even a joint lower spectral bound is not an FWER rank-selection theorem.

### Actual original and baseline reductions

**Pinned original `Rajive.R:141–151`:**

- For ordinary `S>1`, `K>1`, `mapply` simplifies to an `S × K` matrix.
  The transpose is `K × S`; `colSums` sums **blocks within each replicate**.
  It does not sum all Monte Carlo draws into one threshold. C4 confirms this.
- Independently, `signal_rank=initial_signal_ranks[k]` inside the `mapply`
  closure captures `k` left over from the previous loop, hence **the last
  block’s rank is used for every block**.
- At `S=1`, `mapply` simplifies to a vector; transposition gives `1 × K`,
  so this shape logic degenerates. Missing `drop=FALSE` causes other boundaries.

**Baseline `R/Rajive.R:662–683`:**

- An explicit indexed `lapply` corrects the captured rank.
- `block_wedin_bounds[k]=Q_.05(block_wedin_draws[[k]])`.
- `wedin_samples` is now the **scalar**
  `K - sum(block_wedin_bounds)`, and is also the Wedin threshold.
- `block_wedin_samples` is a `1 × K` matrix of reduced bounds, not raw draws;
  raw per-block draw vectors are not stored in the returned diagnostic there.

The baseline comments at lines 665–671 about a dimensionally invalid
“per-draw” aggregation **do not accurately describe the pinned original’s
ordinary-dimension `colSums`**. They may describe an intermediate local version;
this audit does not establish that history. The baseline reduction is a
different heuristic and cannot be defended by those comments or by original
parity.

## 6. The robust-factor/amplitude mismatch

RaJIVE’s paper Appendix A defines a robust rank-one amplitude as a product of
factor norms, normalizes each factor, then repeats on the deflated residual
([12], Eqs.(4),(5) and ensuing paragraphs). Pinned `RobustSVD.R:12–32,69–79`
does exactly this sequential construction. There is no explicit cross-column
orthogonalization or amplitude sorting. Baseline
`src/RobustSVD.cpp:150–168,198–268` also normalizes individual columns and
appends deflated factors without an orthogonalization/sorting step.

Consequently, source does **not ensure**:

1. `U' U=I` or `V' V=I`;
2. robust amplitude `d[r]` is the smallest retained classical singular value;
3. classical singular equations `X V=U diag(d)` and `X' U=V diag(d)`;
4. `M M'=sum(projectors)` when raw block factors are concatenated;
5. robust amplitudes from another robust factorization of `M` equal the
   classical singular values needed in (D4).

This is a failure to establish the prerequisites, not a claim that every robust
fit must violate them. In particular, deflation alone does not impose the
Euclidean orthogonality that classical least-squares SVD has.

**C6, independent of any fitted dataset:** let columns of `U` be
`e1` and `.6 e1+.8 e2` in R³. Both have norm one, but
`U' U=[[1,.6],[.6,1]]`. For two identical blocks with the same exact signal
plane, `[U,U]` has squared singular values `3.2,.8,0`, even though the two
**orthogonal** projectors onto their common plane sum to eigenvalues `2,2,0`.
Thus the lower bound `2` for both joint directions fails for the raw matrix,
already before any robust refactorization. With `V=I` and amplitude labels
`d=(1,1)`, the reconstructed block has actual singular values
`sqrt(1.6),sqrt(.4)`, not `(1,1)`.

The active resampler **does QR-orthonormalize the signal basis locally**
(`R/Rajive_helpfunctions.R:162`) but the score stack at `Rajive.R:644–648`
remains raw and the denominator at helper line 129 remains robust `d[r]`.
Local QR therefore does not repair the global theorem/statistic mismatch.

For perspective, a possible mathematical extension would require orthonormal
trial spaces, a core with a **certified smallest singular value**, and residual
certificates for the failed singular equations. If
`F=X Q_V-Q_U C`, `G=X' Q_U-Q_V C'`, the projected bounds gain terms such as
`||E Q_V-F||` and `||E' Q_U-G||`, bounded above by separate noise and residual
norms. These certificates are not supplied by the current ratio. Merely using
the QR-core SVD of a reconstructed robust fit would not make it a classical
truncated SVD of raw `X`. **The robust transfer remains unresolved.**

## 7. Complement and denominator boundary audit

### Original complement bootstrap is not AJIVE’s random-frame target

Pinned helper `83–139` uses stored columns after the retained rank, sets the
resampling size to their **number**, samples those columns **with replacement**,
and takes a norm with no orthonormalization. This is not a random orthonormal
`r`-frame in the full complement:

- If stored factor count is `m=min(n,p)`, only `m-r` stored columns remain,
  whereas the ambient complement is `n-r` or `p-r`. Rectangular null-space
  directions may be absent.
- The draw has `m-r` columns, not necessarily `r`; repeated columns need not
  form a basis, and robust remaining columns need not be perpendicular to the
  retained factors.
- **C7:** for `X=diag(10,3,1)`, complement columns `e2,e3`, selecting `e2`
  twice gives norm `3sqrt(2)`, larger than the full orthonormal complement
  operator norm `3`.
- Extraction omits `drop=FALSE`; one remaining column becomes a vector and
  `dim(perp_basis)[2]` is `NULL`. Empty complements are not explicitly handled.

These differences forbid treating the original bootstrap as theorem-grounded
ground truth, even though its ordinary per-draw aggregation has the intended
orientation.

### Baseline active path versus inactive candidate/reference

Let a side have ambient dimension `d`, requested signal rank `r`, and
complement dimension `c=d-r`.

| Boundary | Active baseline `wedin_bound_resampling` + C++ | Candidate/reference and mathematical interpretation |
|---|---|---|
| `r=0` | Internal norm sampler returns zeros. Public input disallows rank zero. | Candidate returns zeros; no nonempty signal angle/denominator. The higher ratio helper is **not** a valid zero-rank contract: C10 shows deterministic zero norms with `d[0]` produce ones in its expression. |
| `0<r<=c` | Requests an `r`-column projected Gaussian frame. C++ accepts dimensions; full projected column rank is still required for a genuine frame. | Feasible AJIVE-sized complement frame when the basis is full rank. |
| `0<c<r` | Requests `r` columns anyway; `src/RankBounds.cpp:31–33` throws “second dimension must fit the orthogonal complement.” | `.wedin_bound_resampling_candidate` uses `min(r,c)` columns, a **changed target dimension**, not a proof of the rank-`r` resampling approximation. If `q=c` and the projected frame spans the full complement, the operator norm is invariant over frame rotations: the conditional norm has no frame Monte Carlo variability. |
| `c=0,r>0` | Same C++ feasibility guard throws; no special active saturation return. | Candidate returns zero with `boundary="saturated_signal_space"`; that is a convention for **that side’s** absent complement, not evidence of zero signal error/noise on both sides. Other-side contribution may remain. |

The full-complement norm invariance also applies at the active feasible boundary
`r=c`: the frame spans the entire complement, so a genuine orthonormal-frame
rotation does not change that side's operator norm.

The active wrapper passes `q=r` on both sides, so feasibility requires
`2r<=n` and `2r<=p_k`. Baseline `input_contracts.R:164–169` instead accepts
`1<=r<=min(n,p_k)` and checks neither this complement constraint nor numerical
matrix rank. High allowed ranks can therefore fail even when Wedin is excluded
from the eventual threshold: it is computed before exclusion.

`R/wedin_reference.R:39–61` defines the min-rank/saturated candidate, but
no production call site uses it; the active helper calls the Rcpp function
directly. Do **not** report candidate boundary behavior as the fitted estimator’s
current behavior.

QR itself is not a rank certificate. The active wrapper, candidate and R
reference retain a requested number of QR columns without checking numerical
rank. If a basis is deficient or a projected deterministic draw has deficient
rank, QR may complete a frame with directions outside the desired complement.
**C8:** the projection of `raw=e1` away from `signal=e1` is zero, yet the first
QR-completion vector can be `e1`, with leakage one. For continuous Gaussian
draws this exact event is probability zero in a feasible exact-arithmetic
full-rank setting, but numerical or explicitly supplied draws need auditing.
The R reference has no C++-equivalent low-complement dimension guard.

### Denominator boundary, not cured by clipping

`get_wedin_bound_samples` uses raw `SVD$d[signal_rank]` with no explicit positive
finite scalar check. Public rank validation bounds dimensions, not the attained
robust amplitude. For its exact R expression:

| Denominator / numerator | Arithmetic consequence |
|---|---|
| finite `d>0` | In-range capped squared ratio; theorem still needs genuine singular-value/gap meaning. |
| `d=0`, max numerator `>0` | `Inf` clips to `1`, an arithmetic convention, not fulfillment of Wedin’s positive-gap premise. |
| `d=0`, max numerator `=0` | `0/0=NaN`; default quantile rejects missing/NaN draws before the later scalar finite-threshold check. |
| absent `d[r]` or `NA/NaN` | Nonfinite draws; quantile generally fails first. |
| `d=Inf`, finite numerator | Ratio zero can misleadingly produce a maximal `K` threshold. |
| `d<0` | Not a singular value; because clipping is only above, e.g. `(3/-2)^2=2.25`, outside `[0,1]`. |

Negative/Inf are defensive arithmetic cases, not assertions that the current
robust backend normally returns them. The audit establishes the missing
contract and its consequences, not a measured incidence.

## 8. Effective threshold flags and no-effect configurations

Baseline `R/Rajive.R:98–111` defines
`.wedin_participates_in_default()` as
`isTRUE(getOption("rajiveplus.wedin_in_default_threshold", FALSE))`.
Baseline lines `743–760` exclude finite Wedin diagnostics when that returns
false, compute

```
max(wedin_effective, rand_dir_q95, perm_q95, na.rm=TRUE),
```

and store `fit$joint_rank_sel$wedin$participates_in_threshold` when a Wedin
diagnostic exists. The “default” wording in the helper name does not imply it
is active; the option value is authoritative.

| Requested / effective setup | Actual implication |
|---|---|
| Estimated joint rank, default option FALSE, default random directions present | Wedin diagnostic calculated but does not affect final cutoff. Random/permutation cutoff(s) do. |
| `n_wedin_samples=NA` | No Wedin diagnostic or participation field there. |
| Fixed `joint_rank` | Rank-selection threshold branch skipped; Wedin not used for choosing rank. |
| Option TRUE and finite Wedin diagnostic | Wedin enters max, but may be numerically dominated by another cutoff. Participation is not proof of a material rank effect. |
| Option FALSE, Wedin requested, both `n_rand_dir_samples=NA` and `n_perm_samples=NA`, estimated joint rank | Initial “at least one requested” guard is satisfied by Wedin, then all **effective** cutoff inputs are NA. `max(...,na.rm=TRUE)` returns **`-Inf`** with a warning. No all-effective-sources-missing guard intervenes. |

C9 checks this arithmetic exactly. All finite observed squared amplitudes,
including zero, exceed `-Inf`; the subsequent identifiability filter may still
remove directions. Do not attribute that final rank to Wedin calibration.
`method_profiles.R:3–16` labels the rule
`max_available_wedin_random_permutation`; that label alone omits the participation
option and is insufficient provenance. Likewise, function documentation claiming
a combined Wedin threshold is not a substitute for the effective flag.

## 9. Reproducible deterministic checks and limits

Run the independently authored base-R arithmetic checks:

From the package checkout:

```sh
Rscript scripts/check_stage1_wedin.R .
```

Observed result: **all C1–C10 passed**. They use exact small matrices/base
linear algebra and a private deterministic stub only to evaluate the baseline’s
ratio helper at rank zero. They perform **no robust fitting, no randomized
resampling, no simulator generation, and no calibration/confirmatory benchmark**.
The local `rajiveplus` namespace was not installed; none is needed for these
checks. C++ feasibility behavior is established by the pinned source guard,
not a compiled execution.

For source integrity and targeted review:

```sh
git show 3fecb8124dc0d7a1681155ff65462bb3305b8961:R/Rajive.R
```

Compare SHA256 against `wedin_source_evidence.json`, which also inventories the
baseline snapshots, downloaded full papers and external citation metadata.
The working tree was clean on the initial inspection. The parent subsequently
advanced HEAD and modified simulator/design files during this audit, as
expected; all claims above refer to the immutable baseline snapshots, not those
concurrent edits. No repository files were changed by this workstream. No
machines were created and no remote writes occurred.

**Decision boundary for the parent:** supported theorem algebra and conditional
projector aggregation are available now. The current robust statistic,
denominator, resampling joint law/coverage, and quantile reduction do not yet
form a proved end-to-end Wedin rank-selection method. Keep those classifications
explicit; neither upstream parity nor the deterministic checks supply the
missing robust theorem or a FWER guarantee.
