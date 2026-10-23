# Defect B1: the benchmark generator must produce an identifiable ground truth.
#
# `ajive.data.sim()` draws each block's Individual scores independently of the
# joint scores, so its truth violates the model the estimator targets. Before
# validating an estimator, its benchmark has to be valid. These tests validate
# the generator, separately from validating any estimator against it.

sim_fixture <- function(seed = 11L) {
  simulate_blocks(n = 60L, pks = c(50L, 40L, 30L),
                  joint_rank = 2L, individual_ranks = c(5L, 4L, 3L),
                  noise_sd = 1, signal_sd = 1, seed = seed)
}

test_that("generated truth is exactly self-consistent", {
  sim <- sim_fixture()
  for (k in seq_along(sim$blocks)) {
    X <- sim$blocks[[k]]
    J <- sim$truth$joint[[k]]
    I <- sim$truth$individual[[k]]
    E <- sim$truth$residual[[k]]
    expect_equal(X, J + I + E, tolerance = 1e-12,
                 label = paste("block", k))
    expect_identical(dim(X), dim(J))
    expect_identical(dim(X), dim(I))
  }
})

test_that("the joint score basis is orthonormal", {
  sim <- sim_fixture()
  Q <- sim$truth$joint_basis
  expect_equal(dim(Q), c(60L, 2L))
  expect_equal(crossprod(Q), diag(2L), tolerance = 1e-10)
})

test_that("individual score bases are orthonormal", {
  sim <- sim_fixture()
  for (k in seq_along(sim$truth$individual_bases)) {
    S <- sim$truth$individual_bases[[k]]
    expect_equal(crossprod(S), diag(ncol(S)), tolerance = 1e-10,
                 label = paste("block", k))
  }
})

test_that("individual score bases are orthogonal to the joint basis", {
  # This is the property the legacy generator violates. The archived probe
  # measured a normalised joint/individual truth overlap of 0.35.
  sim <- sim_fixture()
  Q <- sim$truth$joint_basis
  for (k in seq_along(sim$truth$individual_bases)) {
    S <- sim$truth$individual_bases[[k]]
    cross <- crossprod(Q, S)
    expect_equal(cross, matrix(0, nrow = ncol(Q), ncol = ncol(S)), tolerance = 1e-10,
                 label = paste("block", k))
    overlap <- norm(cross, "F") / max(norm(Q, "F") * norm(S, "F"), .Machine$double.eps)
    expect_lte(overlap, 1e-10, label = paste("overlap block", k))
  }
})

test_that("the legacy generator is documented as overlapping-truth", {
  # `ajive.data.sim()` stays available as a misspecification stress case, but it
  # must not be mistaken for an identifiable target.
  expect_true(is.function(ajive.data.sim))
  sim <- ajive.data.sim(K = 2, rankJ = 1, rankA = c(3, 2), n = 40,
                        pks = c(20, 15), dist.type = 1)
  S1 <- sim$truth$As_true[[1L]]
  S2 <- sim$truth$As_true[[2L]]
  cross <- crossprod(S1, S2)
  overlap <- norm(cross, "F") / max(norm(S1, "F") * norm(S2, "F"), .Machine$double.eps)
  expect_gt(overlap, 1e-6,
            label = "legacy truth overlap should be non-zero, which is why it is a stress case")
})

test_that("zero ranks and edge shapes are supported", {
  sim <- simulate_blocks(n = 20L, pks = c(8L, 6L),
                         joint_rank = 0L, individual_ranks = c(2L, 0L),
                         seed = 3L)
  expect_identical(ncol(sim$truth$joint_basis), 0L)
  expect_identical(ncol(sim$truth$individual_bases[[1L]]), 2L)
  expect_identical(ncol(sim$truth$individual_bases[[2L]]), 0L)
  expect_equal(sim$blocks[[2L]], sim$truth$residual[[2L]], tolerance = 1e-12)
})

test_that("block names are honoured", {
  sim <- simulate_blocks(n = 30L, pks = c(10L, 8L, 6L),
                         joint_rank = 1L, individual_ranks = c(2L, 2L, 2L),
                         block_names = c("rna", "prot", "metab"), seed = 4L)
  expect_named(sim$blocks, c("rna", "prot", "metab"))
  expect_named(sim$truth$joint, c("rna", "prot", "metab"))
  expect_named(sim$truth$individual_bases, c("rna", "prot", "metab"))
})

test_that("invalid generator arguments are rejected with classed conditions", {
  expect_error(simulate_blocks(n = 0, pks = 5L, joint_rank = 1L, individual_ranks = 1L),
               class = "rajiveplus_invalid_input")
  expect_error(simulate_blocks(n = 10, pks = c(5L, 5L), joint_rank = 1L,
                               individual_ranks = 1L),
               class = "rajiveplus_invalid_input")
  expect_error(simulate_blocks(n = 10, pks = 5L, joint_rank = 1L,
                               individual_ranks = c(1L, 2L)),
               class = "rajiveplus_invalid_input")
  expect_error(simulate_blocks(n = 5, pks = 5L, joint_rank = 4L,
                               individual_ranks = 4L),
               class = "rajiveplus_invalid_input")
  expect_error(simulate_blocks(n = 10, pks = c(5L, 5L), joint_rank = 1L,
                               individual_ranks = c(1L, 1L),
                               block_names = c("a", "a")),
               class = "rajiveplus_invalid_input")
})

test_that("generation is reproducible under a seed", {
  a <- sim_fixture(seed = 99L)
  b <- sim_fixture(seed = 99L)
  expect_equal(a$blocks, b$blocks)
  c2 <- sim_fixture(seed = 100L)
  expect_false(isTRUE(all.equal(a$blocks, c2$blocks)))
})

test_that("latent scores have unit variance across samples", {
  # The bases are orthonormal, so a component built directly from them would
  # have energy of order `rank` instead of `n`, making the joint signal far
  # weaker than any real multi-view data. The latent scores carry the magnitude.
  sim <- sim_fixture()
  js <- sim$truth$joint_scores
  expect_equal(colSums(js^2) / nrow(js), rep(1, ncol(js)), tolerance = 1e-10,
               label = "joint latent score variance")
  for (k in seq_along(sim$truth$individual_scores)) {
    s <- sim$truth$individual_scores[[k]]
    expect_equal(colSums(s^2) / nrow(s), rep(1, ncol(s)), tolerance = 1e-10,
                 label = paste("individual latent score variance block", k))
  }
})

test_that("signal magnitude is comparable to the legacy generator", {
  # A valid generator that produces a different signal scale would silently
  # change every calibration number. Compare joint component energy against the
  # legacy generator at matched settings.
  sim <- simulate_blocks(n = 60L, pks = c(50L, 40L, 30L),
                         joint_rank = 2L, individual_ranks = c(5L, 4L, 3L),
                         noise_sd = 1, signal_sd = 1, seed = 21L)
  legacy <- ajive.data.sim(K = 3, rankJ = 2, rankA = c(5, 4, 3), n = 60,
                           pks = c(50, 40, 30), dist.type = 1)

  ratio_new <- sum(sim$truth$joint[[1L]]^2) / sum(legacy$truth$J_true[, 1:50]^2)
  expect_gt(ratio_new, 0.25)
  expect_lt(ratio_new, 4)
})
