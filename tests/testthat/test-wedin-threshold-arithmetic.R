# Defect W1/W2: the Wedin joint threshold is dimensionally invalid.
#
# `get_wedin_bound_samples()` returns `num_samples` independent draws per block,
# each a value in [0, 1]. The caller reduces them with
# `K - colSums(block_wedin_samples)`, which treats the draws as per-block
# contributions to be summed and subtracted from the block count. The result is
# therefore always large and negative, and because the combined rule takes
# `max(wedin, rand_dir, perm)` the Wedin term is never binding.
#
# A squared singular-value threshold cannot be negative. These tests pin both
# the arithmetic and the documented participation of the Wedin term.

test_that("Wedin joint threshold is finite and non-negative", {
  set.seed(4242L)
  blocks <- null_blocks(K = 3L, n = 60L, pks = c(50L, 40L, 30L), seed = 4242L)
  fit <- Rajive(blocks, c(5L, 4L, 3L),
                n_wedin_samples = 50L, n_rand_dir_samples = 50L, seed = 11L)

  threshold <- fit$joint_rank_sel$wedin$wedin_svsq_threshold
  expect_true(is.finite(threshold))
  expect_gte(
    threshold, 0,
    label = paste0("Wedin squared-singular-value threshold = ", signif(threshold, 4))
  )
})

test_that("Wedin threshold does not scale with the number of Wedin draws", {
  # Reducing the per-block draws to a per-block bound is what makes the
  # threshold well defined. Before the fix, the value fell by roughly
  # `num_samples * K`, because the whole draw vector was summed. The 5%
  # quantile estimated from 10 draws is legitimately noisier than from 40, so
  # this asserts the threshold stays inside the feasible range rather than
  # demanding exact agreement.
  set.seed(4243L)
  blocks <- null_blocks(K = 3L, n = 60L, pks = c(50L, 40L, 30L), seed = 4243L)

  thresholds <- vapply(c(10L, 40L), function(draws) {
    fit <- Rajive(blocks, c(5L, 4L, 3L),
                  n_wedin_samples = draws, n_rand_dir_samples = 50L, seed = 12L)
    fit$joint_rank_sel$wedin$wedin_svsq_threshold
  }, numeric(1L))

  # K - sum(K bounds in [0, 1]) is confined to [0, K].
  expect_true(all(thresholds >= 0))
  expect_true(all(thresholds <= 3))
  expect_lt(max(abs(thresholds - thresholds[[1L]])), 1,
            label = paste0("thresholds: ",
                           paste(signif(thresholds, 6), collapse = " vs ")))
})

test_that("the Wedin term is excluded from the default threshold and says so", {
  # A squared singular-value threshold computed from an unverified across-block
  # combination must not silently drive rank selection. It stays reported and
  # inspectable, and the exclusion is recorded rather than accidental.
  set.seed(4246L)
  blocks <- null_blocks(K = 3L, n = 60L, pks = c(50L, 40L, 30L), seed = 4246L)
  withr::with_options(list(rajiveplus.wedin_diagnostic_informed = FALSE), {
    messages <- capture_messages(
      fit <<- Rajive(blocks, c(5L, 4L, 3L),
                     n_wedin_samples = 50L, n_rand_dir_samples = 50L, seed = 14L)
    )
  })
  expect_true(any(grepl("excluded from\\s+the default joint-rank threshold",
                        messages)))

  sel <- fit$joint_rank_sel
  expect_false(sel$wedin$participates_in_threshold)
  expect_true(is.finite(sel$wedin$wedin_svsq_threshold))
  expect_gte(sel$wedin$wedin_svsq_threshold, 0)
  expect_equal(unname(sel$overall_sv_sq_threshold),
               unname(sel$rand_dir$rand_dir_svsq_threshold))
})

test_that("the Wedin term can be opted back in", {
  set.seed(4247L)
  blocks <- null_blocks(K = 3L, n = 60L, pks = c(50L, 40L, 30L), seed = 4247L)
  withr::with_options(list(rajiveplus.wedin_in_default_threshold = TRUE), {
    fit <- Rajive(blocks, c(5L, 4L, 3L),
                  n_wedin_samples = 50L, n_rand_dir_samples = 50L, seed = 15L)
  })
  sel <- fit$joint_rank_sel
  expect_true(sel$wedin$participates_in_threshold)
  expect_equal(sel$overall_sv_sq_threshold, sel$wedin$wedin_svsq_threshold)
})

test_that("the combined threshold equals the maximum of the participating bounds", {
  set.seed(4244L)
  blocks <- null_blocks(K = 3L, n = 60L, pks = c(50L, 40L, 30L), seed = 4244L)
  fit <- Rajive(blocks, c(5L, 4L, 3L),
                n_wedin_samples = 50L, n_rand_dir_samples = 50L, seed = 13L)

  sel <- fit$joint_rank_sel
  participating <- c(rand_dir = sel$rand_dir$rand_dir_svsq_threshold,
                     perm = sel$perm$perm_svsq_threshold)
  if (isTRUE(sel$wedin$participates_in_threshold)) {
    participating <- c(wedin = sel$wedin$wedin_svsq_threshold, participating)
  }
  participating <- participating[is.finite(participating)]

  expect_equal(unname(sel$overall_sv_sq_threshold), max(unname(participating)),
               label = "combined threshold must equal the maximum of the participating bounds")
  expect_length(participating, 1L)
})

test_that("Wedin per-block draws reduce to one bound per block", {
  # The aggregation consumes a per-block bound, so it must be told one. Assert
  # the shape contract directly on the sampler.
  set.seed(4245L)
  x <- null_blocks(K = 1L, n = 40L, pks = c(30L), seed = 4245L)[[1L]]
  svd_x <- rajiveplus:::get_svd_robustH(x)

  draws <- rajiveplus:::get_wedin_bound_samples(
    x, svd_x, signal_rank = 4L, num_samples = 30L, num_cores = 1L
  )
  expect_length(draws, 30L)
  expect_true(all(is.finite(draws)))
  expect_gte(min(draws), 0)
  expect_lte(max(draws), 1)
})
