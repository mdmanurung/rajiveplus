test_that("full-refit jackstraw comparator declares its estimand", {
  fx <- make_small_rajive_fixture(seed = 9971L)
  out <- jackstraw_refit_rajive(
    fx$fit, fx$blocks, fx$initial_signal_ranks,
    n_refits = 2L, permuted_features = 1L, seed = 9972L
  )
  expect_s3_class(out, "rajiveplus_refit_jackstraw")
  expect_identical(out$metadata$rank_policy,
                   "fixed_reference_joint_and_initial_block_ranks")
  expect_identical(out$metadata$missing_component_policy,
                   "retain_replicate_with_NA_statistic")
  expect_true(all(c("refit_complete", "p_value", "p_adjusted") %in%
                    names(out$results)))
})

test_that("full-refit comparator retains rank-zero datasets", {
  fx <- make_small_rajive_fixture(seed = 9973L)
  fx$fit$joint_scores <- matrix(0, nrow(fx$fit$joint_scores), 0L)
  fx$fit$joint_rank <- 0L
  out <- jackstraw_refit_rajive(
    fx$fit, fx$blocks, fx$initial_signal_ranks, n_refits = 1L
  )
  expect_identical(out$metadata$status, "not_applicable_rank_zero")
  expect_true(out$metadata$rank_zero_datasets_retained)
  expect_equal(nrow(out$results), 0L)
})
