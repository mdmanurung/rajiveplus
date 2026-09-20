test_that("validation RNG streams are deterministic and restore global state", {
  set.seed(9703L)
  before <- .Random.seed
  a <- rajiveplus:::.with_validation_rng(11L, stats::runif(4L))
  expect_identical(.Random.seed, before)
  b <- rajiveplus:::.with_validation_rng(11L, stats::runif(4L))
  expect_identical(a, b)
  expect_identical(.Random.seed, before)
})

test_that("validation seed manifest separates data and method streams", {
  manifest <- rajiveplus:::.validation_seed_manifest(
    scenarios = c("clean", "noisy"), exploratory_replicates = 2L,
    final_replicates = 3L, master_seed = 9704L
  )
  expect_equal(nrow(manifest), 10L)
  expect_true(all(c("scenario_id", "replicate_id", "seed_set", "data_seed",
                    "method_seed", "rng_kind", "rng_version") %in% names(manifest)))
  expect_identical(anyDuplicated(manifest$data_seed), 0L)
  expect_identical(anyDuplicated(manifest$method_seed), 0L)
  expect_false(any(manifest$data_seed %in% manifest$method_seed))
  expect_identical(manifest, rajiveplus:::.validation_seed_manifest(
    c("clean", "noisy"), 2L, 3L, 9704L
  ))
})

test_that("per-replicate record schema is strict", {
  row <- rajiveplus:::.new_validation_replicate(
    scenario_id = "clean", replicate_id = "clean-final-001",
    seed_set = "final", data_seed = 1L, method_seed = 2L,
    method_profile_id = "RJP-BASE", method_profile_hash = "md5:abc",
    status = "PASS", metrics = list(projector_error = 0.01)
  )
  expect_s3_class(row, "rajiveplus_validation_replicate")
  expect_error(
    rajiveplus:::.new_validation_replicate(
      "clean", "bad", "final", 1L, 2L, "RJP-BASE", "md5:abc",
      "UNKNOWN", list()
    ),
    class = "rajiveplus_invalid_validation_record"
  )
})
