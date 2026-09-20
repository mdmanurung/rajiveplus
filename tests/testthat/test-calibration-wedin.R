# Slow calibration tests for the Wedin bound resampler.
#
# Verifies that wedin_bound_resampling() produces operator-norm samples
# consistent with a Haar-uniform reference, confirming that the QR-based
# sampling correctly implements the Grassmannian Haar measure.
#
# Run with:
#   RAJIVE_RUN_SLOW=1 conda run -n R4_51 Rscript -e \
#     "devtools::test_file('tests/testthat/test-calibration-wedin.R')"
#
# Reference: Wedin PA (1972) BIT 12:99-111.
# Haar reference: Stewart GW (1980) SIAM J. Numer. Anal. 17(3):403-409.

# ---------------------------------------------------------------------------
# W-M5: Wedin U-perp samples match Haar-uniform reference (KS test)
# ---------------------------------------------------------------------------

test_that("wedin_bound_resampling U-perp samples match Haar-uniform reference", {
  skip_if_not_slow()

  # KS two-sample critical value for n=m=200, alpha=0.01:
  #   D_crit ≈ 1.63 * sqrt((n+m)/(n*m)) = 1.63 * sqrt(400/40000) ≈ 0.163.
  # We assert KS p.value > 0.01 (i.e. D < D_crit).
  with_lecuyer_seed(13, {
    Y     <- ajive.data.sim(K = 2, rankJ = 2, rankA = c(5, 4),
                            n = 60, pks = c(40, 30), dist.type = 1)
    X        <- Y$sim_data[[1]]
    svd_X    <- svd(X)
    signal_r <- 5L
    signal_basis <- svd_X$u[, seq_len(signal_r), drop = FALSE]
    # For a tall matrix, the remaining columns of the thin SVD span only the
    # complement inside col(X). The Wedin contract samples the full ambient
    # complement of the signal basis, including the left nullspace of X.
    full_basis <- qr.Q(qr(signal_basis), complete = TRUE)
    perp_basis <- full_basis[, -(seq_len(signal_r)), drop = FALSE]

    num_samples <- 200L

    # -- Current implementation --
    cur <- rajiveplus:::wedin_bound_resampling(
      X            = X,
      signal_basis = signal_basis,
      right_vectors = FALSE,
      num_samples  = num_samples,
      num_cores    = 1L
    )

    # -- Haar-uniform reference (same norm computation) --
    ref <- replicate(num_samples, {
      q    <- haar_perp_sample(perp_basis, r = signal_r)
      norm(t(q) %*% X, type = "2")
    })

    ks <- stats::ks.test(cur, ref)
    expect_gt(ks$p.value, 0.01,
              label = paste0("U-perp KS p-value = ", signif(ks$p.value, 3),
                             "; should be > 0.01 if Haar-calibrated"))
  })
})

test_that("wedin_bound_resampling V-perp samples match Haar-uniform reference", {
  skip_if_not_slow()

  with_lecuyer_seed(14, {
    Y     <- ajive.data.sim(K = 2, rankJ = 2, rankA = c(5, 4),
                            n = 60, pks = c(40, 30), dist.type = 1)
    X        <- Y$sim_data[[1]]
    svd_X    <- svd(X)
    signal_r <- 5L
    signal_basis_v <- svd_X$v[, seq_len(signal_r), drop = FALSE]
    full_basis_v <- qr.Q(qr(signal_basis_v), complete = TRUE)
    perp_basis_v <- full_basis_v[, -(seq_len(signal_r)), drop = FALSE]

    num_samples <- 200L

    cur <- rajiveplus:::wedin_bound_resampling(
      X             = X,
      signal_basis  = signal_basis_v,
      right_vectors = TRUE,
      num_samples   = num_samples,
      num_cores     = 1L
    )

    ref <- replicate(num_samples, {
      q    <- haar_perp_sample(perp_basis_v, r = signal_r)
      norm(X %*% q, type = "2")
    })

    ks <- stats::ks.test(cur, ref)
    expect_gt(ks$p.value, 0.01,
              label = paste0("V-perp KS p-value = ", signif(ks$p.value, 3)))
  })
})

# ---------------------------------------------------------------------------
# W-M5: Wedin samples are non-degenerate (strictly positive)
# ---------------------------------------------------------------------------

test_that("wedin_bound_resampling returns positive norms", {
  skip_if_not_slow()

  with_lecuyer_seed(15, {
    Y     <- ajive.data.sim(K = 2, rankJ = 2, rankA = c(4, 3),
                            n = 50, pks = c(30, 25), dist.type = 1)
    X        <- Y$sim_data[[1]]
    svd_X    <- svd(X)
    signal_basis <- svd_X$u[, 1:4, drop = FALSE]

    cur <- rajiveplus:::wedin_bound_resampling(
      X             = X,
      signal_basis  = signal_basis,
      right_vectors = FALSE,
      num_samples   = 100L,
      num_cores     = 1L
    )
    expect_true(all(cur > 0))
  })
})
