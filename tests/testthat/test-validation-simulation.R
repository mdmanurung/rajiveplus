test_that("identifiable simulations satisfy score-space invariants", {
  sim <- rajiveplus:::.simulate_identifiable_data(
    K = 3L, n = 30L, pks = c(8L, 9L, 10L), rank_joint = 2L,
    rank_individual = c(2L, 3L, 2L), joint_strength = c(4, 2),
    individual_strength = list(c(3, 1), c(3, 2, 1), c(2, 1)),
    snr = c(5, 3, 2), seed = 9701L
  )

  expect_silent(rajiveplus:::.validate_identifiable_simulation(sim))
  expect_equal(crossprod(rep(1, 30), sim$truth$joint_scores),
               matrix(0, 1, 2), tolerance = 1e-12)
  for (k in seq_len(3L)) {
    expect_equal(crossprod(sim$truth$joint_scores,
                           sim$truth$individual_scores[[k]]),
                 matrix(0, 2, c(2L, 3L, 2L)[k]), tolerance = 1e-12)
    expect_equal(sim$noisy[[k]], sim$clean[[k]] + sim$noise[[k]],
                 tolerance = 1e-12)
    expect_equal(qr(sim$clean[[k]])$rank,
                 2L + c(2L, 3L, 2L)[k])
    expect_equal(norm(sim$clean[[k]], "F") / norm(sim$noise[[k]], "F"),
                 c(5, 3, 2)[k], tolerance = 1e-10)
  }
})

test_that("requested subset overlap is exact and never all-block Individual", {
  sim <- rajiveplus:::.simulate_identifiable_data(
    K = 3L, n = 25L, pks = rep(7L, 3L), rank_joint = 1L,
    rank_individual = rep(2L, 3L), subset_overlap = list(
      list(blocks = c(1L, 2L), rank = 1L)
    ), seed = 9702L
  )
  scores <- sim$truth$individual_scores
  expect_equal(rajiveplus:::.subspace_intersection_rank(scores[c(1, 2)]), 1L)
  expect_equal(rajiveplus:::.subspace_intersection_rank(scores), 0L)
  expect_silent(rajiveplus:::.validate_identifiable_simulation(sim))
})

test_that("simulation contract rejects impossible dimensions", {
  expect_error(
    rajiveplus:::.simulate_identifiable_data(
      K = 2L, n = 5L, pks = c(4L, 4L), rank_joint = 3L,
      rank_individual = c(2L, 1L)
    ),
    class = "rajiveplus_invalid_simulation"
  )
  expect_error(
    rajiveplus:::.simulate_identifiable_data(
      K = 2L, n = 10L, pks = c(4L, 4L), rank_joint = 1L,
      rank_individual = c(1L, 1L),
      subset_overlap = list(list(blocks = c(1L, 2L), rank = 1L))
    ),
    class = "rajiveplus_invalid_simulation"
  )
})

test_that("legacy simulation is explicitly labeled as misspecified", {
  expect_identical(rajiveplus:::.legacy_simulation_fixture_status(),
                   "misspecification_fixture")
})
