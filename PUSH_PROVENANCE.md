# Stage-2 worktree provenance and push instructions

Snapshot: 2026-10-23. Branch: `publication/stage1-truth-wedin-design-20261022`.

## State

- The working tree is clean; every stage-2 change is committed.
- The branch tip is a strict linear descendant of the PR #9 head `8ceabeed`
  (`git merge-base --is-ancestor 8ceabeed HEAD` holds), so publishing is a
  fast-forward of `miss-data-handling`.
- The session sandbox has NO GitHub write credentials: direct `git push` has
  no token, and the GitHub API integration token returns 403 on tree creation
  for `mdmanurung/rajiveplus`. Nothing was pushed from the sandbox.

## Commits on this branch not yet on the GitHub PR branch

4817b76 test: reproduce actual-fit variance energy inconsistencies
906b0c0 fix: report reconstructed component energies on observed entries
3fecb81 docs: preserve terminal stage-zero validation dispositions
f14b0e5 test: reproduce infeasible simulation truth and require certification
bf823cd test: avoid integer-overflow diagnostics in RNG rejection assertion
5a2e9d7 Certify realized simulator truth and reject infeasible rank contracts
38a72db Add isolated paired fixed-rank geometry and Individual-constraint adapters
8ef0df5 Document pinned Wedin limits and strengthen numerical boundary controls
27557df Name experimental leakage explicitly as fitted-span leakage
d1cd445 Record bounded validation evidence and normalize test whitespace
ec080a5 Fix default estimator geometry (G1/G2): orthonormal bases, constrained Individual refit
ab25281 Record preprocessing policy and warn on clearly uncentred blocks (S1)
e4a5fcf Fix citation DOI, Description DOI form, withr listing, and RaJIVE MIT notice
5019b6d Point README vignette link at the repository while pkgdown articles are undeployed
cdf5967 Match the permutation null to the observed statistic; identifiability threshold at the noise floor
d0b02ba Shrink the native-missing vignette fixture to a render-budget footprint
1ec173e Record stage-2 provenance, push instructions, and confirmation status

## How to publish (from a machine with push rights)

Option A - push the working tree directly:

```
git remote add github https://github.com/mdmanurung/rajiveplus.git  # if needed
git push github publication/stage1-truth-wedin-design-20261022:miss-data-handling
```

Option B - fetch from the session bundle `rajiveplus_stage2.bundle` (full
history, all binaries, standalone):

```
git clone rajiveplus_stage2.bundle rajiveplus-stage2
cd rajiveplus-stage2
git push origin publication/stage1-truth-wedin-design-20261022:miss-data-handling
```

Both options fast-forward PR #9; no force push is needed.
