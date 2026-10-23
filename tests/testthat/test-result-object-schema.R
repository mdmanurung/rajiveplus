test_that(".new_rajive preserves the public complete-result layout", {
  fx <- make_extractor_fixture()

  fit <- rajiveplus:::.new_rajive(
    block_decomps = fx$fit$block_decomps,
    joint_scores = fx$fit$joint_scores,
    joint_rank = fx$fit$joint_rank,
    joint_rank_sel = list(method = "fixture")
  )

  expect_identical(
    names(fit),
    c("block_decomps", "joint_scores", "joint_rank", "joint_rank_sel")
  )
  expect_identical(class(fit), "rajive")
  expect_identical(fit$block_decomps, fx$fit$block_decomps)
})

test_that(".new_rajive validates complete component schema and shapes", {
  fx <- make_extractor_fixture()
  args <- list(
    block_decomps = fx$fit$block_decomps,
    joint_scores = fx$fit$joint_scores,
    joint_rank = fx$fit$joint_rank,
    joint_rank_sel = list(method = "fixture")
  )

  malformed <- args
  malformed$block_decomps[[2L]]$v <- NULL
  expect_error(
    do.call(rajiveplus:::.new_rajive, malformed),
    class = "rajiveplus_invalid_result"
  )

  bad_residual <- args
  bad_residual$block_decomps[[3L]] <- "residual"
  expect_error(
    do.call(rajiveplus:::.new_rajive, bad_residual),
    class = "rajiveplus_invalid_result"
  )

  bad_scores <- args
  bad_scores$joint_scores <- matrix(0, nrow = 3L, ncol = 1L)
  expect_error(
    do.call(rajiveplus:::.new_rajive, bad_scores),
    class = "rajiveplus_invalid_result"
  )
})

test_that(".new_rajive_rank_only enforces its compact schema", {
  scores <- matrix(seq_len(6), nrow = 3L, ncol = 2L)
  rank_only <- rajiveplus:::.new_rajive_rank_only(
    joint_scores = scores,
    joint_rank = 2L,
    joint_rank_sel = list(method = "fixture")
  )

  expect_identical(class(rank_only), "rajive_rank_only")
  expect_identical(
    names(rank_only), c("joint_scores", "joint_rank", "joint_rank_sel")
  )
  expect_error(
    rajiveplus:::.new_rajive_rank_only(scores, 1L, list()),
    class = "rajiveplus_invalid_result"
  )
})

test_that(".new_rajive_incomplete preserves class order and block alignment", {
  fx <- make_extractor_fixture()
  fit <- rajiveplus:::.new_rajive(
    fx$fit$block_decomps,
    fx$fit$joint_scores,
    fx$fit$joint_rank,
    list(method = "fixture")
  )
  missing <- list(
    mask = lapply(fx$blocks, function(x) matrix(TRUE, nrow(x), ncol(x))),
    observed = lapply(fx$blocks, length),
    patterns = list(sample_summary = data.frame()),
    original_blocks = fx$blocks,
    block_names = names(fx$blocks),
    initial_signal_ranks = c(1L, 1L),
    preprocess = NULL,
    control = list(),
    convergence = list()
  )

  incomplete <- rajiveplus:::.new_rajive_incomplete(fit, missing)

  expect_identical(class(incomplete), c("rajive_incomplete", "rajive"))
  expect_identical(incomplete$missing, missing)

  missing$mask <- missing$mask[1L]
  expect_error(
    rajiveplus:::.new_rajive_incomplete(fit, missing),
    class = "rajiveplus_invalid_result"
  )
})
