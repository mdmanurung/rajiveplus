test_that("method-profile manifest defines every frozen decision field", {
  manifest <- rajiveplus:::.method_profile_manifest()
  required <- c(
    "block_factorization", "basis_extraction_tolerance",
    "aggregation_statistic", "wedin_target", "wedin_sampler",
    "wedin_denominator", "random_permutation_statistic",
    "threshold_rule", "identifiability_norm", "individual_constraint",
    "individual_refactorization", "robust_scale_policy", "fallback_behavior"
  )

  expect_true(all(c("RJP-BASE", "RJP-COMPAT", "RJP-NATIVE-BASE") %in%
                    names(manifest)))
  expect_true(all(vapply(manifest, function(x) {
    all(required %in% names(x$config))
  }, logical(1L))))
  expect_identical(manifest$`RJP-COMPAT`$status, "benchmark_only")
})

test_that("robust SVD profiles separate references and blocked upstream", {
  profiles <- rajiveplus:::.svd_profile_manifest()
  expect_identical(names(profiles),
                   c("upstream_rajive", "current_r_weighted",
                     "optimized_cpp_complete"))
  expect_identical(profiles$upstream_rajive$status, "BLOCKED")
  expect_true(is.na(profiles$upstream_rajive$source_pin))
  expect_identical(profiles$current_r_weighted$status, "EXECUTABLE")
})

test_that("method-profile config hashes are stable and configuration-sensitive", {
  a <- rajiveplus:::.resolve_method_profile("RJP-BASE", "l2")
  b <- rajiveplus:::.resolve_method_profile("RJP-BASE", "l2")
  c <- rajiveplus:::.resolve_method_profile("RJP-BASE", "l1")

  expect_identical(a$config_hash, b$config_hash)
  expect_match(a$config_hash, "^md5:[0-9a-f]{32}$")
  expect_false(identical(a$config_hash, c$config_hash))
})

test_that("complete, rank-only, and native fits record method profiles", {
  fx <- make_small_rajive_fixture(seed = 9602L)
  complete <- Rajive(
    fx$blocks, fx$initial_signal_ranks, joint_rank = 1L,
    n_wedin_samples = NA, n_rand_dir_samples = NA
  )
  rank_only <- rajiveplus:::.Rajive_rank_only(
    fx$blocks, fx$initial_signal_ranks, joint_rank = 1L,
    n_wedin_samples = NA, n_rand_dir_samples = NA
  )
  native <- Rajive(
    fx$blocks, fx$initial_signal_ranks, missing = "native", joint_rank = 1L,
    n_wedin_samples = NA, n_rand_dir_samples = NA
  )

  expect_identical(complete$method_profile$id, "RJP-BASE")
  expect_identical(rank_only$method_profile$config_hash,
                   complete$method_profile$config_hash)
  expect_identical(native$method_profile$id, "RJP-BASE")
  expect_identical(native$method_profile$config_hash,
                   complete$method_profile$config_hash)
})
