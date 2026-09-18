test_that(".extract_block_matrices returns original data blocks", {
  fx <- make_extractor_fixture()

  got <- rajiveplus:::.extract_block_matrices(fx$fit, fx$blocks, "data")

  expect_named(got, names(fx$blocks))
  expect_equal(got, fx$blocks)
})

test_that(".extract_block_matrices extracts joint and individual matrices", {
  fx <- make_extractor_fixture()

  joint <- rajiveplus:::.extract_block_matrices(fx$fit, fx$blocks, "joint")
  indiv <- rajiveplus:::.extract_block_matrices(fx$fit, fx$blocks, "individual")

  expect_equal(joint, fx$joint)
  expect_equal(indiv, fx$individual)
})

test_that(".extract_block_matrices reconstructs components when full matrices are absent", {
  fx <- make_extractor_fixture(keep_full = FALSE)

  joint <- rajiveplus:::.extract_block_matrices(fx$fit, fx$blocks, "joint")
  indiv <- rajiveplus:::.extract_block_matrices(fx$fit, fx$blocks, "individual")

  expect_equal(joint, fx$joint, tolerance = 1e-10)
  expect_equal(indiv, fx$individual, tolerance = 1e-10)
})

test_that(".extract_block_matrices computes residual from data minus components", {
  fx <- make_extractor_fixture()

  resid <- rajiveplus:::.extract_block_matrices(fx$fit, fx$blocks, "residual")

  expect_equal(lapply(resid, unname), lapply(fx$residual, unname))
})

test_that("get_block_matrix uses residual component vocabulary", {
  fx <- make_extractor_fixture()

  expect_equal(
    get_block_matrix(fx$fit, k = 1, type = "residual"),
    fx$residual[[1L]]
  )
  expect_error(
    get_block_matrix(fx$fit, k = 1, type = "noise"),
    regexp = 'type = "residual"'
  )
})

test_that(".extract_block_matrices rejects stale component dimensions", {
  fx <- make_extractor_fixture()
  fx$fit$block_decomps[[2L]]$full <- fx$fit$block_decomps[[2L]]$full[, -1L, drop = FALSE]

  expect_error(
    rajiveplus:::.extract_block_matrices(fx$fit, fx$blocks, "joint"),
    regexp = "dimensions do not match"
  )
  expect_error(
    rajiveplus:::.extract_block_matrices(fx$fit, fx$blocks, "residual"),
    regexp = "stale\\s+input\\s+blocks"
  )
})

test_that(".extract_block_matrices validates matched samples", {
  fx <- make_extractor_fixture()
  rownames(fx$blocks[[2]]) <- rev(rownames(fx$blocks[[2]]))

  expect_error(
    rajiveplus:::.extract_block_matrices(fx$fit, fx$blocks, "data"),
    regexp = "sample"
  )
})

test_that(".extract_block_matrices rejects non-numeric blocks", {
  fx <- make_extractor_fixture()
  fx$blocks[[1]][1, 1] <- NA_real_

  expect_error(
    rajiveplus:::.extract_block_matrices(fx$fit, fx$blocks, "data"),
    regexp = "finite"
  )
})
