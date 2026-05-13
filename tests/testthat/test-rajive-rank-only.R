expect_rank_only_equivalent <- function(full, rank_only, tol = 1e-10) {
  expect_s3_class(rank_only, "rajive_rank_only")
  expect_equal(rank_only$joint_rank, full$joint_rank)
  expect_equal(
    rank_only$joint_rank_sel$joint_rank_estimate,
    full$joint_rank_sel$joint_rank_estimate
  )
  expect_equal(
    rank_only$joint_rank_sel$obs_svals,
    full$joint_rank_sel$obs_svals,
    tolerance = tol
  )
  expect_equal(
    rank_only$joint_rank_sel$overall_sv_sq_threshold,
    full$joint_rank_sel$overall_sv_sq_threshold,
    tolerance = tol
  )
  expect_equal(
    rank_only$joint_rank_sel$identif_dropped,
    full$joint_rank_sel$identif_dropped
  )
  expect_equal(
    rank_only$joint_rank_sel$identifiability_norm,
    full$joint_rank_sel$identifiability_norm
  )

  if (!is.na(full$joint_rank) && full$joint_rank > 0L) {
    expect_equal(rank_only$joint_scores, full$joint_scores, tolerance = tol)
    full_basis <- qr.Q(qr(full$joint_scores))
    rank_only_basis <- qr.Q(qr(rank_only$joint_scores))
    angles <- svd(crossprod(full_basis, rank_only_basis))$d
    expect_true(all(angles > 1 - 1e-8))
  } else {
    expect_equal(ncol(rank_only$joint_scores), 0L)
  }
}

test_that(".Rajive_rank_only matches full Rajive for fixed rank", {
  fx <- make_small_rajive_fixture(seed = 9101L)

  full <- Rajive(
    fx$blocks,
    initial_signal_ranks = fx$initial_signal_ranks,
    joint_rank = 1L,
    n_wedin_samples = NA,
    n_rand_dir_samples = NA,
    num_cores = 1L,
    seed = 101L
  )
  rank_only <- rajiveplus:::.Rajive_rank_only(
    fx$blocks,
    initial_signal_ranks = fx$initial_signal_ranks,
    joint_rank = 1L,
    n_wedin_samples = NA,
    n_rand_dir_samples = NA,
    num_cores = 1L,
    seed = 101L
  )

  expect_rank_only_equivalent(full, rank_only)
  expect_null(rank_only$block_decomps)
})

test_that(".Rajive_rank_only matches full Rajive for estimated rank", {
  blocks <- signal_blocks(K = 2, n = 18, pks = c(12L, 10L),
                          rankJ = 1L, rankA = c(1L, 1L), seed = 9102L)
  ranks <- c(2L, 2L)

  full <- with_lecuyer_seed(102L, {
    Rajive(
      blocks,
      initial_signal_ranks = ranks,
      joint_rank = NA,
      n_wedin_samples = 5L,
      n_rand_dir_samples = 5L,
      n_perm_samples = NA,
      num_cores = 1L
    )
  })
  rank_only <- with_lecuyer_seed(102L, {
    rajiveplus:::.Rajive_rank_only(
      blocks,
      initial_signal_ranks = ranks,
      joint_rank = NA,
      n_wedin_samples = 5L,
      n_rand_dir_samples = 5L,
      n_perm_samples = NA,
      num_cores = 1L
    )
  })

  expect_rank_only_equivalent(full, rank_only)
  expect_equal(
    rank_only$joint_rank_sel$wedin$wedin_svsq_threshold,
    full$joint_rank_sel$wedin$wedin_svsq_threshold,
    tolerance = 1e-10
  )
  expect_equal(
    rank_only$joint_rank_sel$rand_dir$rand_dir_svsq_threshold,
    full$joint_rank_sel$rand_dir$rand_dir_svsq_threshold,
    tolerance = 1e-10
  )
})

test_that("rank-only refits match full refits for clustered bootstrap indices", {
  dat <- signal_blocks_clustered(
    K = 2,
    n_clusters = 6L,
    obs_per_cluster = 2L,
    pks = c(8L, 7L),
    rankJ = 1L,
    rankA = c(1L, 1L),
    seed = 9103L
  )
  ranks <- c(2L, 2L)

  set.seed(103L)
  idx_list <- replicate(
    3L,
    rajiveplus:::.bootstrap_resample_indices(
      n = nrow(dat$blocks[[1L]]),
      sample_frac = 1,
      cluster = dat$cluster,
      resample = "cluster"
    ),
    simplify = FALSE
  )

  full_ranks <- rank_only_ranks <- integer(length(idx_list))
  for (i in seq_along(idx_list)) {
    b_list <- lapply(dat$blocks, function(x) x[idx_list[[i]], , drop = FALSE])
    full <- Rajive(
      b_list,
      initial_signal_ranks = ranks,
      joint_rank = NA,
      n_wedin_samples = 4L,
      n_rand_dir_samples = 4L,
      n_perm_samples = NA,
      num_cores = 1L,
      seed = 9103L
    )
    rank_only <- rajiveplus:::.Rajive_rank_only(
      b_list,
      initial_signal_ranks = ranks,
      joint_rank = NA,
      n_wedin_samples = 4L,
      n_rand_dir_samples = 4L,
      n_perm_samples = NA,
      num_cores = 1L,
      seed = 9103L
    )
    expect_rank_only_equivalent(full, rank_only)
    full_ranks[[i]] <- full$joint_rank
    rank_only_ranks[[i]] <- rank_only$joint_rank
  }

  expect_equal(rank_only_ranks, full_ranks)
})
