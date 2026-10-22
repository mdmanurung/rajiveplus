ablation_fixture <- function() {
  .simulate_identifiable_data(
    K = 3, n = 20, pks = c(8, 7, 6), rank_joint = 2,
    rank_individual = c(1, 1, 1), joint_strength = c(4, 3),
    individual_strength = 2, snr = 4, seed = 1729
  )
}

test_that("orthonormal robust geometry and constrained refit reproduce the default path", {
  # Purpose (unchanged): the experimental adapter must faithfully reproduce the
  # shipped default path so ablation results transfer to it. Since RJP-BASE v2
  # adopted the orthonormal/constrained semantics, the arm that reproduces the
  # default is orthonormal representation + robust aggregation + constrained
  # refit; the raw/unconstrained arms are now legacy-only contrasts.
  sim <- ablation_fixture()
  cache <- .ablation_prepare(sim$noisy, c(3, 3, 3), seed = 11)
  set.seed(45)
  rng <- .Random.seed
  geometry <- .ablation_geometry(cache, 2, "orthonormal", "robust", seed = 12)
  reference <- .with_validation_rng(12, get_joint_scores_robustH(
    cache$blocks, cache$block_fits, cache$initial_ranks, cache$sv_thresholds,
    joint_rank = 2, identifiability_norm = "l2"
  ))
  expect_equal(geometry$joint_scores, reference$joint_scores, tolerance = 1e-12)
  expect_equal(geometry$identif_dropped, reference$rank_sel_results$identif_dropped)
  selected <- .ablation_select_individual(cache, geometry, 13)
  result <- .ablation_finish(cache, geometry, "constrained", 13, selected)
  for (k in seq_along(cache$blocks)) {
    baseline <- .with_validation_rng(13, get_final_decomposition_robustH(
      cache$blocks[[k]], geometry$joint_scores, cache$sv_thresholds[k], TRUE
    ))
    expect_equal(result$blocks[[k]]$joint, baseline$joint, tolerance = 1e-12)
    # The frozen adapter records `constraint_rank_tolerance` alongside the
    # schema fields and orders them differently; compare the mathematical
    # content field by field.
    ind <- result$blocks[[k]]$individual
    base_ind <- baseline$individual
    expect_equal(ind$u, base_ind$u, tolerance = 1e-12)
    expect_equal(ind$d, base_ind$d, tolerance = 1e-12)
    expect_equal(ind$v, base_ind$v, tolerance = 1e-12)
    expect_equal(ind$full, base_ind$full, tolerance = 1e-12)
    expect_identical(ind$rank, base_ind$rank)
    expect_equal(result$blocks[[k]]$residual, baseline$residual, tolerance = 1e-12)
  }
  expect_identical(.Random.seed, rng)
})

test_that("all eight arms are executable and I pairs share selected fits", {
  sim <- ablation_fixture()
  expect_identical(.certify_simulated_truth(sim)$status, "PASS")
  cache <- .ablation_prepare(sim$noisy, c(3, 3, 3), 11)
  for (R in c("raw", "orthonormal")) for (S in c("robust", "classical")) {
    geometry <- .ablation_geometry(cache, 2, R, S, 12)
    selected <- .ablation_select_individual(cache, geometry, 13)
    original <- .ablation_finish(cache, geometry, "original", 13, selected)
    constrained <- .ablation_finish(cache, geometry, "constrained", 13, selected)
    expect_identical(original$selected, constrained$selected)
    if (R == "orthonormal") {
      for (q in geometry$block_scores) {
        expect_lte(max(abs(crossprod(q) - diag(ncol(q))), 0), 1e-10)
      }
      q <- geometry$joint_scores
      expect_lte(max(abs(crossprod(q) - diag(ncol(q))), 0), 1e-10)
    }
    for (b in constrained$blocks) {
      expect_lte(b$individual_fitted_span_leakage, 1e-8)
      expect_lte(b$reconstruction_relative, 1e-12)
      expect_gte(b$individual_rank_drop, 0)
    }
  }
})

test_that("representation is not silently canonicalized by classical aggregation", {
  cache <- list(blocks = list(matrix(0, 4, 3), matrix(0, 4, 3)),
                initial_ranks = c(2L, 2L), sv_thresholds = c(-1, -1))
  u <- cbind(c(1, 0, 0, 0), c(.6, .8, 0, 0))
  cache$block_fits <- list(list(u = u), list(u = u[c(1, 3, 2, 4), ]))
  raw <- .ablation_geometry(cache, 2, "raw", "classical")
  orth <- .ablation_geometry(cache, 2, "orthonormal", "classical")
  expect_gt(norm(tcrossprod(raw$stacked_scores) -
                   tcrossprod(orth$stacked_scores), "F"), .1)
  expect_false(raw$projector_interpretation)
  expect_true(orth$projector_interpretation)
  expect_equal(raw$stacked_scores, do.call(cbind, lapply(cache$block_fits, `[[`, "u")))
  expect_equal(orth$amplitudes^2,
               eigen(tcrossprod(orth$stacked_scores), symmetric = TRUE)$values[1:4],
               tolerance = 1e-12)
})

test_that("span constraint handles nonorthogonal scores and rank loss", {
  q <- cbind(c(1, 0, 0), c(.6, .8, 0))
  I <- cbind(c(1, 2, 3), c(2, 1, 1))
  s <- svd(I)
  selected <- list(list(u = s$u, d = s$d, v = s$v, rank = 2L, full = I))
  cache <- list(blocks = list(I), sv_thresholds = 0)
  geometry <- list(joint_scores = q)
  out <- .ablation_finish(cache, geometry, "constrained", selected = selected)
  expect_lte(out$blocks[[1]]$individual_fitted_span_leakage, 1e-8)
  expect_equal(out$blocks[[1]]$individual$rank, 1L)
  expect_equal(out$blocks[[1]]$individual_rank_drop, 1L)
  expect_equal(out$blocks[[1]]$individual$full[1:2, ], matrix(0, 2, 2),
               tolerance = 1e-12)
})

test_that("zero Joint rank and unsupported thresholds are explicit", {
  sim <- ablation_fixture()
  cache <- .ablation_prepare(sim$noisy, c(3, 3, 3), 11)
  geometry <- .ablation_geometry(cache, 0, "orthonormal", "classical")
  expect_equal(geometry$post_filter_rank, 0L)
  selected <- .ablation_select_individual(cache, geometry, 13)
  a <- .ablation_finish(cache, geometry, "original", selected = selected)
  b <- .ablation_finish(cache, geometry, "constrained", selected = selected)
  for (k in seq_along(a$blocks)) {
    expect_equal(a$blocks[[k]]$individual$full, b$blocks[[k]]$individual$full,
                 tolerance = 1e-10)
  }
  expect_error(.ablation_require_threshold(c(NA, -Inf)), "BLOCKED")
  expect_equal(.ablation_require_threshold(c(NA, -Inf, 2)), 2)
})

test_that("exact span projection is invariant to Joint coordinates and removes full overlap", {
  q <- cbind(c(1, 0, 0, 0), c(.6, .8, 0, 0))
  I <- matrix(c(1, 2, 3, 4, 2, 1, 4, 3), 4, 2)
  s <- svd(I)
  selected <- list(list(u = s$u, d = s$d, v = s$v, rank = 2L, full = I))
  cache <- list(blocks = list(I))
  a <- .ablation_finish(cache, list(joint_scores = q), "constrained", selected = selected)
  b <- .ablation_finish(cache, list(joint_scores = q %*% matrix(c(2, 1, 1, 3), 2)),
                        "constrained", selected = selected)
  expect_equal(a$blocks[[1]]$individual$full, b$blocks[[1]]$individual$full,
               tolerance = 1e-12)
  q0 <- .ablation_basis(q)
  s0 <- svd(q0)
  all_joint <- list(list(u = s0$u, d = s0$d, v = s0$v, rank = 2L, full = q0))
  c <- .ablation_finish(list(blocks = list(q0)), list(joint_scores = q),
                        "constrained", selected = all_joint)
  expect_equal(c$blocks[[1]]$individual$rank, 0L)
  expect_equal(c$blocks[[1]]$individual_rank_drop, 2L)
  expect_equal(c$blocks[[1]]$individual$full, matrix(0, 4, 2))
  expect_equal(c$blocks[[1]]$individual_fitted_span_leakage, 0)
})
