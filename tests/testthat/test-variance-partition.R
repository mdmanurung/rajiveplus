test_that("joint_variance_partition returns tidy feature-level schema", {
  fx <- make_extractor_fixture()

  got <- joint_variance_partition(fx$fit, fx$blocks)

  expected <- c("feature", "block", "joint_ss", "individual_ss",
                "residual_ss", "component_total_ss", "data_total_ss",
                "joint_individual_cross", "joint_residual_cross",
                "individual_residual_cross", "energy_reconstruction_ss",
                "joint_prop", "individual_prop", "residual_prop",
                "reconstruction_error", "matrix_reconstruction_error",
                "energy_closure_error")
  expect_named(got, expected)
  expect_s3_class(got, "data.frame")
  expect_equal(nrow(got), sum(vapply(fx$blocks, ncol, integer(1))))
})

test_that("joint_variance_partition uses columns as features", {
  fx <- make_extractor_fixture()

  got <- joint_variance_partition(fx$fit, fx$blocks)
  block1 <- got[got$block == "block1", , drop = FALSE]

  expect_equal(block1$feature, colnames(fx$blocks$block1))
  expect_equal(block1$joint_ss, colSums(fx$joint$block1^2))
  expect_equal(block1$individual_ss, colSums(fx$individual$block1^2))
  expect_equal(block1$residual_ss, colSums(fx$residual$block1^2))
})

test_that("joint_variance_partition proportions sum to one for positive totals", {
  fx <- make_extractor_fixture()

  got <- joint_variance_partition(fx$fit, fx$blocks)
  positive <- got$component_total_ss > 0

  expect_equal(got$joint_prop[positive] +
                 got$individual_prop[positive] +
                 got$residual_prop[positive],
               rep(1, sum(positive)),
               tolerance = 1e-10)
  expect_equal(got$reconstruction_error, rep(0, nrow(got)), tolerance = 1e-10)
  expect_equal(got$matrix_reconstruction_error, rep(0, nrow(got)), tolerance = 1e-10)
  expect_equal(got$energy_closure_error, rep(0, nrow(got)), tolerance = 1e-10)
})

test_that("variance diagnostics expose cross terms without redefining legacy output", {
  fx <- make_extractor_fixture()
  got <- joint_variance_partition(fx$fit, fx$blocks)
  block1 <- got[got$block == "block1", , drop = FALSE]
  expect_equal(block1$joint_individual_cross,
               2 * colSums(fx$joint$block1 * fx$individual$block1))
  expect_equal(block1$joint_residual_cross,
               2 * colSums(fx$joint$block1 * fx$residual$block1))
  expect_equal(block1$individual_residual_cross,
               2 * colSums(fx$individual$block1 * fx$residual$block1))
  expect_equal(block1$reconstruction_error,
               abs(block1$data_total_ss - block1$component_total_ss))
})

test_that("variance diagnostics use the Observed Mask for incomplete blocks", {
  fx <- make_extractor_fixture()
  fx$blocks$block1[1, 1] <- NA_real_
  got <- joint_variance_partition(fx$fit, fx$blocks)
  row <- got[got$block == "block1" & got$feature == "block1_feature1", ]
  observed <- is.finite(fx$blocks$block1[, 1])
  expect_equal(row$data_total_ss,
               sum(fx$blocks$block1[observed, 1]^2))
  expect_true(is.finite(row$matrix_reconstruction_error))
})

test_that("joint_variance_partition returns finite values for zero-variance features", {
  fx <- make_extractor_fixture()
  fx$blocks$block1 <- cbind(fx$blocks$block1, zero_feature = 0)
  fx$fit$block_decomps[[1]]$full <- cbind(fx$fit$block_decomps[[1]]$full, 0)
  fx$fit$block_decomps[[2]]$full <- cbind(fx$fit$block_decomps[[2]]$full, 0)

  got <- joint_variance_partition(fx$fit, fx$blocks)
  zero <- got[got$feature == "zero_feature", , drop = FALSE]

  expect_equal(zero$component_total_ss, 0)
  expect_true(all(is.finite(unlist(zero[c("joint_prop", "individual_prop", "residual_prop")]))))
  expect_equal(zero$joint_prop, 0)
  expect_equal(zero$individual_prop, 0)
  expect_equal(zero$residual_prop, 0)
})

test_that("joint_variance_partition works without feature names", {
  fx <- make_extractor_fixture()
  colnames(fx$blocks$block2) <- NULL

  got <- joint_variance_partition(fx$fit, fx$blocks)
  block2 <- got[got$block == "block2", , drop = FALSE]

  expect_equal(block2$feature, paste0("feature", seq_len(ncol(fx$blocks$block2))))
})
