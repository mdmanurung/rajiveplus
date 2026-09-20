make_component_decomp <- function(mat, keep_full = TRUE) {
  sv <- svd(mat)
  r <- length(sv$d)
  out <- list(
    u = sv$u[, seq_len(r), drop = FALSE],
    d = sv$d,
    v = sv$v[, seq_len(r), drop = FALSE],
    rank = r
  )
  if (keep_full) out$full <- mat
  out
}

make_extractor_fixture <- function(keep_full = TRUE) {
  J1 <- matrix(c(
    1, 0, 2,
    0, 0, 0,
    0, 0, 0,
    0, 3, 0
  ), nrow = 4, byrow = TRUE)
  I1 <- matrix(c(
    0, 0, 0,
    2, 0, 1,
    0, 0, 0,
    0, 0, 0
  ), nrow = 4, byrow = TRUE)
  E1 <- matrix(c(
    0, 0, 0,
    0, 0, 0,
    0, 1, 2,
    0, 0, 0
  ), nrow = 4, byrow = TRUE)

  J2 <- J1[, 1:2, drop = FALSE]
  I2 <- I1[, 1:2, drop = FALSE]
  E2 <- E1[, 1:2, drop = FALSE]

  blocks <- list(block1 = J1 + I1 + E1, block2 = J2 + I2 + E2)
  for (k in seq_along(blocks)) {
    rownames(blocks[[k]]) <- paste0("sample", seq_len(nrow(blocks[[k]])))
    colnames(blocks[[k]]) <- paste0(names(blocks)[k], "_feature", seq_len(ncol(blocks[[k]])))
  }

  fit <- list(
    block_decomps = list(
      make_component_decomp(I1, keep_full),
      make_component_decomp(J1, keep_full),
      E1,
      make_component_decomp(I2, keep_full),
      make_component_decomp(J2, keep_full),
      E2
    ),
    joint_scores = matrix(0, nrow = 4, ncol = 1),
    joint_rank = 1L
  )
  class(fit) <- "rajive"

  list(fit = fit, blocks = blocks, joint = list(block1 = J1, block2 = J2),
       individual = list(block1 = I1, block2 = I2),
       residual = list(block1 = E1, block2 = E2))
}

make_small_rajive_fixture <- function(seed = 7001L) {
  set.seed(seed)
  Y <- ajive.data.sim(K = 2, rankJ = 1, rankA = c(1, 1),
                      n = 12, pks = c(8, 6), dist.type = 1)
  fit <- Rajive(Y$sim_data, c(2L, 2L),
                joint_rank = 1L,
                n_wedin_samples = NA,
                n_rand_dir_samples = NA,
                num_cores = 1L)
  list(fit = fit, blocks = Y$sim_data, initial_signal_ranks = c(2L, 2L))
}
