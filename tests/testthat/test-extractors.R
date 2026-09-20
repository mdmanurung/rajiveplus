test_that(".block_decomp_index pins the three-role flat layout", {
  expect_identical(rajiveplus:::.block_decomp_index(1L, "individual", 2L), 1L)
  expect_identical(rajiveplus:::.block_decomp_index(1L, "joint", 2L), 2L)
  expect_identical(rajiveplus:::.block_decomp_index(1L, "residual", 2L), 3L)
  expect_identical(rajiveplus:::.block_decomp_index(2L, "individual", 2L), 4L)
  expect_identical(rajiveplus:::.block_decomp_index(2L, "joint", 2L), 5L)
  expect_identical(rajiveplus:::.block_decomp_index(2L, "residual", 2L), 6L)
})

test_that(".block_decomp_index rejects invalid internal arguments", {
  expect_error(rajiveplus:::.block_decomp_index(1, "joint", 2L), "integer")
  expect_error(rajiveplus:::.block_decomp_index(0L, "joint", 2L), "block")
  expect_error(rajiveplus:::.block_decomp_index(3L, "joint", 2L), "block")
  expect_error(rajiveplus:::.block_decomp_index(1L, "Joint", 2L), "component")
  expect_error(rajiveplus:::.block_decomp_index(1L, "joint", 0L), "n_blocks")
})

test_that(".get_block_decomp returns the exact stored record", {
  fx <- make_small_rajive_fixture()

  expect_identical(
    rajiveplus:::.get_block_decomp(fx$fit, 1L, "individual"),
    fx$fit$block_decomps[[1L]]
  )
  expect_identical(
    rajiveplus:::.get_block_decomp(fx$fit, 2L, "joint"),
    fx$fit$block_decomps[[5L]]
  )
  expect_identical(
    rajiveplus:::.get_block_decomp(fx$fit, 2L, "residual"),
    fx$fit$block_decomps[[6L]]
  )
})

test_that(".get_block_decomp validates only the consumed layout", {
  expect_error(
    rajiveplus:::.get_block_decomp(list(), 1L, "joint"),
    "block_decomps"
  )
  expect_error(
    rajiveplus:::.get_block_decomp(list(block_decomps = list(1, 2)), 1L, "joint"),
    "three entries"
  )
})

test_that(".get_component_matrix prefers stored matrices", {
  fx <- make_extractor_fixture()
  stored <- fx$fit$block_decomps[[2L]]$full
  fx$fit$block_decomps[[2L]]$u <- matrix(999, nrow(stored), 1L)

  expect_identical(
    rajiveplus:::.get_component_matrix(fx$fit, 1L, "joint"),
    stored
  )
  expect_identical(
    rajiveplus:::.get_component_matrix(fx$fit, 1L, "residual"),
    fx$fit$block_decomps[[3L]]
  )
})

test_that(".get_component_matrix reconstructs u d v and preserves names", {
  fx <- make_extractor_fixture(keep_full = FALSE)

  got <- rajiveplus:::.get_component_matrix(fx$fit, 1L, "joint")

  expect_equal(got, fx$joint[[1L]], tolerance = 1e-10)
  expect_identical(rownames(got), rownames(fx$fit$block_decomps[[2L]]$u))
  expect_identical(colnames(got), rownames(fx$fit$block_decomps[[2L]]$v))
})

test_that(".get_component_matrix returns named zero matrices for rank zero", {
  u <- matrix(numeric(), nrow = 3L, ncol = 0L,
              dimnames = list(c("s1", "s2", "s3"), NULL))
  v <- matrix(numeric(), nrow = 2L, ncol = 0L,
              dimnames = list(c("f1", "f2"), NULL))
  fit <- structure(
    list(block_decomps = list(
      list(u = u, d = numeric(), v = v),
      list(u = u, d = numeric(), v = v),
      matrix(0, 3L, 2L)
    )),
    class = "rajive"
  )

  got <- rajiveplus:::.get_component_matrix(fit, 1L, "joint")
  expect_identical(dim(got), c(3L, 2L))
  expect_true(all(got == 0))
  expect_identical(dimnames(got), list(c("s1", "s2", "s3"), c("f1", "f2")))
})

test_that(".get_component_matrix signals structured unavailable conditions", {
  fx <- make_extractor_fixture(keep_full = FALSE)
  fx$fit$block_decomps[[3L]] <- NA
  residual_error <- tryCatch(
    rajiveplus:::.get_component_matrix(fx$fit, 1L, "residual"),
    error = identity
  )
  expect_s3_class(residual_error, "rajiveplus_component_matrix_unavailable")
  expect_identical(residual_error$block, 1L)
  expect_identical(residual_error$component, "residual")
  expect_identical(residual_error$reason, "residual_not_stored")

  fx$fit$block_decomps[[2L]] <- list(u = matrix(1, 2L, 1L))
  record_error <- tryCatch(
    rajiveplus:::.get_component_matrix(fx$fit, 1L, "joint"),
    error = identity
  )
  expect_s3_class(record_error, "rajiveplus_component_matrix_unavailable")
  expect_identical(record_error$reason, "invalid_component_record")

  fx$fit$block_decomps[[3L]] <- "unsupported"
  residual_type_error <- tryCatch(
    rajiveplus:::.get_component_matrix(fx$fit, 1L, "residual"),
    error = identity
  )
  expect_s3_class(residual_type_error, "rajiveplus_component_matrix_unavailable")
  expect_identical(residual_type_error$reason, "unsupported_component_matrix")
})

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

test_that("get_block_matrix preserves full false compatibility", {
  fx <- make_extractor_fixture(keep_full = FALSE)

  expect_true(is.na(get_block_matrix(fx$fit, k = 1L, type = "joint")))
  expect_true(is.na(get_block_matrix(fx$fit, k = 1L, type = "individual")))
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
