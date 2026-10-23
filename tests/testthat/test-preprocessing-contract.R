# Defect S1: `Rajive()` neither centres nor scales. The documentation states
# the user must centre (and Frobenius-normalise) but nothing detects or
# records the block preprocessing status, so a forgotten centreing silently
# corrupts the joint-rank estimate.
#
# Contract (red-first): the method profile records the centreing/scaling
# policy, and a fit on clearly uncentred blocks emits a documented warning
# that names the offending block. Centred blocks must not warn.

test_that("method profile records the preprocessing policy", {
  manifest <- rajiveplus:::.method_profile_manifest()
  for (id in c("RJP-BASE", "RJP-COMPAT", "RJP-NATIVE-BASE")) {
    expect_true(all(c("preprocessing_centering", "preprocessing_scaling")
                      %in% names(manifest[[id]]$config)),
                label = paste0(id, " records preprocessing policy"))
  }
  expect_identical(manifest$`RJP-BASE`$config$preprocessing_centering,
                   "none_user_responsibility")
  expect_identical(manifest$`RJP-BASE`$config$preprocessing_scaling,
                   "none_user_responsibility")
})

test_that("clearly uncentred blocks emit a documented warning naming the block", {
  set.seed(42)
  blocks <- list(
    block1 = matrix(rnorm(60), nrow = 20) + 5,
    block2 = matrix(rnorm(60), nrow = 20) + 3
  )

  expect_warning(
    fit <- Rajive(blocks, c(2L, 2L), joint_rank = 1L,
                  n_wedin_samples = NA, n_rand_dir_samples = NA,
                  num_cores = 1L),
    class = "rajiveplus_uncentered_blocks"
  )
  expect_s3_class(fit, "rajive")
})

test_that("centred blocks do not trigger the preprocessing warning", {
  set.seed(43)
  blocks <- list(
    block1 = matrix(rnorm(60), nrow = 20),
    block2 = matrix(rnorm(60), nrow = 20)
  )

  fit <- expect_no_warning(
    suppressMessages(Rajive(blocks, c(2L, 2L), joint_rank = 1L,
                            n_wedin_samples = NA, n_rand_dir_samples = NA,
                            num_cores = 1L))
  )
  expect_s3_class(fit, "rajive")
})

test_that("the uncentred-block warning names every offending block", {
  set.seed(44)
  blocks <- list(
    block1 = matrix(rnorm(60), nrow = 20),
    block2 = matrix(rnorm(60), nrow = 20) + 4
  )

  messages <- capture_warnings(
    fit <- Rajive(blocks, c(2L, 2L), joint_rank = 1L,
                  n_wedin_samples = NA, n_rand_dir_samples = NA,
                  num_cores = 1L)
  )
  expect_true(any(grepl("block2", messages)))
  expect_false(any(grepl("block1[^s]", messages)))
})
