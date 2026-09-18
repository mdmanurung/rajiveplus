test_that("native_cv rank selection runs only in native missing mode", {
  blocks <- list(
    block1 = matrix(rnorm(60), nrow = 10),
    block2 = matrix(rnorm(50), nrow = 10)
  )

  expect_error(
    Rajive(blocks, c(2L, 2L), joint_rank = "native_cv"),
    class = "rajiveplus_invalid_input"
  )
})

test_that("native_cv records candidate diagnostics and selected rank", {
  set.seed(8801)
  blocks <- list(
    block1 = matrix(rnorm(60), nrow = 10),
    block2 = matrix(rnorm(50), nrow = 10)
  )
  mask <- lapply(blocks, function(x) matrix(TRUE, nrow(x), ncol(x)))
  mask$block1[2, 3] <- FALSE

  fit <- Rajive(blocks, c(2L, 2L), missing = "native",
                mask = mask, joint_rank = "native_cv",
                missing_control = rajive_missing_control(rank_candidates = 0:2))

  expect_s3_class(fit, "rajive_incomplete")
  expect_true(is.data.frame(fit$missing$rank_diagnostics))
  expect_true(fit$joint_rank %in% 0:2)
  expect_equal(fit$missing$selected_rank, fit$joint_rank)
})

test_that("native joint_rank NA defaults to native rank selection", {
  set.seed(8802)
  blocks <- list(
    block1 = matrix(rnorm(60), nrow = 10),
    block2 = matrix(rnorm(50), nrow = 10)
  )
  mask <- lapply(blocks, function(x) matrix(TRUE, nrow(x), ncol(x)))
  mask$block2[3, 2] <- FALSE

  fit <- Rajive(blocks, c(2L, 2L), missing = "native", mask = mask)

  expect_s3_class(fit, "rajive_incomplete")
  expect_true(is.data.frame(fit$missing$rank_diagnostics))
  expect_true(0L %in% fit$missing$rank_diagnostics$joint_rank)
  expect_equal(fit$missing$selected_rank, fit$joint_rank)
})

test_that("native rank selection can choose a shared rank when zero is a candidate", {
  set.seed(8804)
  samples <- sprintf("s%02d", seq_len(24))
  latent <- as.numeric(scale(seq(-2, 2, length.out = length(samples)) +
                               rnorm(length(samples), sd = 0.05)))
  make_block <- function(sample_idx, loadings, prefix) {
    x <- outer(latent[sample_idx], loadings) +
      matrix(rnorm(length(sample_idx) * length(loadings), sd = 0.03),
             nrow = length(sample_idx))
    rownames(x) <- samples[sample_idx]
    colnames(x) <- paste0(prefix, seq_along(loadings))
    x
  }
  raw_blocks <- list(
    block1 = make_block(1:18, c(1.3, -0.9, 0.7, -0.4), "a"),
    block2 = make_block(7:24, c(-1.1, 0.8, -0.6, 0.5), "b"),
    block3 = make_block(c(1:10, 15:24), c(1.0, -0.7, 0.6, -0.5), "c")
  )
  aligned <- lapply(raw_blocks, function(x) {
    out <- matrix(NA_real_, nrow = length(samples), ncol = ncol(x),
                  dimnames = list(samples, colnames(x)))
    out[match(rownames(x), samples), ] <- x
    out
  })
  mask <- lapply(aligned, is.finite)
  control <- rajive_missing_control(center = TRUE, scale = TRUE,
                                    normalize = TRUE,
                                    rank_candidates = 0:2)

  fit <- Rajive(aligned, c(2L, 2L, 2L), missing = "native",
                mask = mask, joint_rank = NA, full = FALSE,
                missing_control = control, seed = 8804)
  diag <- fit$missing$rank_diagnostics

  expect_gt(get_joint_rank(fit), 0L)
  expect_lt(diag$prediction_error[diag$joint_rank == 1L],
            diag$prediction_error[diag$joint_rank == 0L])
})

test_that("fixed native ranks do not run automatic diagnostics", {
  set.seed(8803)
  blocks <- list(
    block1 = matrix(rnorm(60), nrow = 10),
    block2 = matrix(rnorm(50), nrow = 10)
  )
  mask <- lapply(blocks, function(x) matrix(TRUE, nrow(x), ncol(x)))
  mask$block1[2, 3] <- FALSE

  fit <- Rajive(blocks, c(2L, 2L), missing = "native", mask = mask,
                joint_rank = 1L)

  expect_null(fit$missing$rank_diagnostics)
  expect_null(fit$missing$selected_rank)
  expect_equal(fit$joint_rank, 1L)
})

test_that("invalid native rank-selection strings are rejected", {
  blocks <- list(
    block1 = matrix(rnorm(60), nrow = 10),
    block2 = matrix(rnorm(50), nrow = 10)
  )

  expect_error(
    Rajive(blocks, c(2L, 2L), missing = "native", joint_rank = "bad_rank"),
    class = "rajiveplus_invalid_input"
  )
})
