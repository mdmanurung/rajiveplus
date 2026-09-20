test_that("independent Wedin reference matches production for fixed draws", {
  set.seed(9951L)
  x <- matrix(rnorm(48), 8, 6)
  signal <- qr.Q(qr(matrix(rnorm(16), 8, 2)))
  draws <- array(rnorm(8 * 2 * 10), c(8, 2, 10))
  production <- rajiveplus:::wedin_bound_resampling_cpp_draws(
    x, signal, FALSE, draws
  )
  reference <- rajiveplus:::.wedin_reference_from_draws(
    x, signal, FALSE, draws
  )
  expect_equal(as.numeric(production), reference, tolerance = 1e-10)
  expect_equal(stats::quantile(as.numeric(production), c(0.05, 0.5, 0.95)),
               stats::quantile(reference, c(0.05, 0.5, 0.95)),
               tolerance = 1e-10)
})

test_that("Wedin target contract records dimensions and low-complement rule", {
  x <- matrix(0, 6, 4)
  signal <- diag(6)[, 1:4, drop = FALSE]
  contract <- rajiveplus:::.wedin_target_contract(x, signal, FALSE)
  expect_identical(contract$matrix_dimensions, c(6L, 4L))
  expect_identical(contract$signal_rank, 4L)
  expect_identical(contract$complement_rank, 2L)
  expect_identical(contract$sampled_frame_rank, 2L)

  set.seed(9952L)
  observed <- rajiveplus:::.wedin_bound_resampling_candidate(
    x, signal, FALSE, num_samples = 4L
  )
  expect_identical(length(observed), 4L)
})

test_that("saturated Wedin behavior is explicit", {
  observed <- rajiveplus:::.wedin_bound_resampling_candidate(
    diag(3), diag(3), FALSE, num_samples = 2L
  )
  expect_equal(as.numeric(observed), c(0, 0))
  expect_identical(attr(observed, "boundary"), "saturated_signal_space")
})
