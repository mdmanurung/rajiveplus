# Defects G1 and G2: the shipped default does not satisfy the geometry the rest
# of the pipeline assumes.
#
# `RJP-BASE` declares `basis_extraction_tolerance = "none_raw_robust_factors"`,
# so per-block robust score bases are used as-is. AJIVE treats score matrices as
# orthonormal subspace bases, and the Individual Component is obtained by
# projecting into the joint complement and then refitting without constraint, so
# joint variation leaks back in.
#
# These tests state the contract and assert the target, so they fail on the
# current default. They are the executable form of the open scientific gate and
# must not be relaxed to make the suite green.
#
# They are gated behind RAJIVE_RUN_GEOMETRY_GATE=1 rather than left permanently
# red, so that an open scientific question does not mask unrelated regressions.
# `audits/DEFECT_REGISTER.md` rows G1 and G2 track them. Promote them to the
# default suite in the same change that fixes the geometry.

skip_if_not_geometry_gate <- function() {
  skip_if_not(
    identical(Sys.getenv("RAJIVE_RUN_GEOMETRY_GATE"), "1"),
    "set RAJIVE_RUN_GEOMETRY_GATE=1 to run the open geometry gate"
  )
}

geometry_fixture <- function(seed = 6161L) {
  sim <- simulate_blocks(n = 60L, pks = c(50L, 40L, 30L),
                         joint_rank = 2L, individual_ranks = c(5L, 4L, 3L),
                         seed = seed)
  list(blocks = sim$blocks,
       initial_signal_ranks = c(5L, 4L, 3L),
       fit = Rajive(sim$blocks, c(5L, 4L, 3L),
                    joint_rank = 2L, num_cores = 1L, seed = seed))
}

test_that("per-block robust score bases are orthonormal", {
  skip_if_not_geometry_gate()
  fx <- geometry_fixture()
  K <- length(fx$blocks)

  worst <- 0
  for (k in seq_len(K)) {
    for (role in seq_len(3L)) {
      record <- fx$fit$block_decomps[[3L * (k - 1L) + role]]
      if (!is.list(record) || is.null(record[["u"]])) {
        next
      }
      U <- record[["u"]]
      if (is.matrix(U) && ncol(U) > 0L) {
        gram_error <- max(abs(crossprod(U) - diag(ncol(U))))
        worst <- max(worst, gram_error)
      }
    }
  }

  expect_lte(
    worst, 1e-10,
    label = paste0("worst max|U'U - I| = ", signif(worst, 4),
                   "; AJIVE geometry assumes < 1e-10")
  )
})

test_that("the Individual Component does not leak into the joint space", {
  skip_if_not_geometry_gate()
  fx <- geometry_fixture()
  Q <- fx$fit$joint_scores
  skip_if(ncol(Q) == 0L, "fixture produced a zero-column joint basis")

  worst <- 0
  for (k in seq_along(fx$blocks)) {
    I <- rajiveplus:::.get_component_matrix(fx$fit, k, "individual")
    leakage <- norm(crossprod(Q, I), "F") / max(norm(I, "F"), .Machine$double.eps)
    worst <- max(worst, leakage)
  }

  expect_lte(
    worst, 1e-8,
    label = paste0("worst relative ||QJ'I||F/||I||F = ", signif(worst, 4),
                   "; must be < 1e-8")
  )
})

test_that("the joint score basis itself is orthonormal", {
  # This one currently holds, and is pinned so that any future canonicalisation
  # or refactor cannot silently break it.
  skip_if_not_geometry_gate()
  fx <- geometry_fixture()
  Q <- fx$fit$joint_scores
  skip_if(ncol(Q) == 0L, "fixture produced a zero-column joint basis")
  expect_lte(max(abs(crossprod(Q) - diag(ncol(Q)))), 1e-10)
})
