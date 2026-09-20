make_input_contract_blocks <- function() {
  set.seed(9601L)
  list(
    transcript = matrix(rnorm(30), nrow = 6L,
                        dimnames = list(paste0("s", 1:6), paste0("g", 1:5))),
    protein = matrix(rnorm(24), nrow = 6L,
                     dimnames = list(paste0("s", 1:6), paste0("p", 1:4)))
  )
}

expect_invalid_input_reason <- function(expr, argument, reason) {
  error <- tryCatch(force(expr), error = identity)
  expect_s3_class(error, "rajiveplus_invalid_input")
  expect_identical(error$argument, argument)
  expect_identical(error$reason, reason)
}

test_that("Rajive requires at least two nonempty numeric Data Blocks", {
  blocks <- make_input_contract_blocks()
  expect_invalid_input_reason(
    Rajive(blocks[1L], 1L, joint_rank = 0L),
    "blocks", "too_few_blocks"
  )

  empty <- blocks
  empty[[1L]] <- matrix(numeric(), nrow = 6L, ncol = 0L)
  expect_invalid_input_reason(
    Rajive(empty, c(1L, 1L), joint_rank = 0L),
    "blocks", "empty_block"
  )

  nonnumeric <- blocks
  nonnumeric[[1L]] <- matrix(letters[1:30], nrow = 6L)
  expect_invalid_input_reason(
    Rajive(nonnumeric, c(1L, 1L), joint_rank = 0L),
    "blocks", "non_numeric_block"
  )
})

test_that("Rajive enforces the frozen sample alignment contract", {
  blocks <- make_input_contract_blocks()

  mixed <- blocks
  rownames(mixed[[2L]]) <- NULL
  expect_invalid_input_reason(
    Rajive(mixed, c(1L, 1L), joint_rank = 0L),
    "blocks", "mixed_sample_names"
  )

  reordered <- blocks
  rownames(reordered[[2L]]) <- rev(rownames(reordered[[2L]]))
  expect_invalid_input_reason(
    Rajive(reordered, c(1L, 1L), joint_rank = 0L),
    "blocks", "sample_order_mismatch"
  )

  duplicate <- blocks
  rownames(duplicate[[1L]])[2L] <- rownames(duplicate[[1L]])[1L]
  expect_invalid_input_reason(
    Rajive(duplicate, c(1L, 1L), joint_rank = 0L),
    "blocks", "invalid_sample_names"
  )

  positional <- lapply(blocks, unname)
  fit <- Rajive(positional, c(1L, 1L), joint_rank = 0L)
  expect_s3_class(fit, "rajive")
})

test_that("Rajive generates or validates Data Block names", {
  blocks <- unname(make_input_contract_blocks())
  fit <- Rajive(blocks, c(1L, 1L), joint_rank = 0L)
  expect_identical(names(get_feature_map(fit)), c("block1", "block2"))

  names(blocks) <- c("block", "block")
  expect_invalid_input_reason(
    Rajive(blocks, c(1L, 1L), joint_rank = 0L),
    "blocks", "invalid_block_names"
  )
})

test_that("Rajive rejects fractional or out-of-range ranks and counts", {
  blocks <- make_input_contract_blocks()
  expect_invalid_input_reason(
    Rajive(blocks, c(1.5, 1), joint_rank = 0L),
    "initial_signal_ranks", "not_integer"
  )
  expect_invalid_input_reason(
    Rajive(blocks, c(1L, 1L), joint_rank = 1.5),
    "joint_rank", "not_integer"
  )
  expect_invalid_input_reason(
    Rajive(blocks, c(1L, 1L), joint_rank = 0L, n_wedin_samples = 2.5),
    "n_wedin_samples", "not_integer"
  )
  expect_invalid_input_reason(
    Rajive(blocks, c(6L, 1L), joint_rank = 0L),
    "initial_signal_ranks", "out_of_bounds"
  )
})

test_that("degenerate features retain mapping and original output dimensions", {
  blocks <- make_input_contract_blocks()
  blocks$transcript[, "g2"] <- 7

  fit <- expect_warning(
    Rajive(blocks, c(2L, 1L), joint_rank = 0L, full = TRUE),
    class = "rajiveplus_degenerate_block"
  )
  mapping <- get_feature_map(fit)

  expect_identical(mapping$transcript$feature, colnames(blocks$transcript))
  expect_false(mapping$transcript$retained[[2L]])
  expect_identical(dim(get_block_matrix(fit, 1L, "joint")), dim(blocks[[1L]]))
  expect_identical(dim(get_block_matrix(fit, 1L, "individual")), dim(blocks[[1L]]))
  expect_identical(dim(get_block_matrix(fit, 1L, "residual")), dim(blocks[[1L]]))
  expect_equal(
    get_block_matrix(fit, 1L, "residual")[, "g2"],
    setNames(rep(7, 6L), rownames(blocks[[1L]]))
  )
})
