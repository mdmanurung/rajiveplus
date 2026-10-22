#' Simulation of data blocks
#'
#' Simulates blocks of data with joint and individual structures
#'
#'
#' @param K Integer. Number of data blocks.
#' @param rankJ Integer. Joint rank.
#' @param rankA Vector of Integers. Individual Ranks.
#' @param n Integer. Number of data points.
#' @param pks Vector of Integers. Number of variables in each block.
#' @param dist.type Integer. 1 for normal, 2 for uniform, 3 for exponential
#' @param noise Integer. Standard deviation in dist
#' @return A list with two elements. `sim_data` is the list of simulated Data
#'   Block matrices. `truth` is a list with `J_true` (the full concatenated
#'   Joint Component), `As_true` (the per-block Individual Components),
#'   `rankJ`, and `rankA`.
#'
#' The Individual scores in this generator are drawn independently of the joint
#' scores, so the stored truth is \emph{not} an identifiable decomposition and
#' the joint and individual score spaces overlap. Use it as a misspecification
#' stress case. To validate whether an estimator recovers the truth, use
#' [simulate_blocks()], whose joint and individual score spaces are orthogonal
#' by construction.
#'
#' @export
#'
#' @examples
#' n <- 20
#' p1 <- 10
#' p2 <- 8
#' p3 <- 5
#' JrankTrue <- 2
#' initial_signal_ranks <- c(5, 2, 2)
#'  Y <- ajive.data.sim(K =3, rankJ = JrankTrue,
#'  rankA = initial_signal_ranks,n = n,
#'  pks = c(p1, p2, p3), dist.type = 1)





ajive.data.sim <- function(K = 3, rankJ = 2,
                          rankA = c(20, 15, 10),
                          n = 100,
                          pks,
                          dist.type = 1, noise = 1){

  p <- sum(pks)

  S <- sim_dist(num = dist.type, n = n, p = rankJ)
  U <- sim_dist(num = dist.type, n = rankJ, p = p)
  J <- S %*% U

  Xs <- As <- list()
  idx <- 1
  for (k in 1:K) {
    rankAk <- rankA[k]
    Sk <- sim_dist(num = dist.type, n = n, p = rankAk)
    Wk <- sim_dist(num = dist.type, n = rankAk, p = pks[k])
    Ak <- Sk %*% Wk
    As[[k]] <- Ak

    col_idx <- idx:(idx + pks[k] - 1)
    Xs[[k]] <- J[,col_idx] + Ak +
      matrix(rnorm(n = n*pks[k], mean = 0, sd = noise), nrow = n, ncol = pks[k])
    idx <- idx + pks[k]
  }


  truth <- list(J_true = J,
                As_true = As, rankJ = rankJ, rankA = rankA)
  Xsim <- list(sim_data = Xs, truth = truth)


  return(Xsim)
}

#' Simulation of single data block from distribution
#'
#'
#'
#' @param num Integer. Type of distribution. 1 for normal, 2 for uniform, 3 for exponential
#' @param n Integer. Number of data points.
#' @param p Integers. Number of variables in  block.
#'
#' @importFrom stats rnorm
#' @importFrom stats runif
#' @importFrom stats rexp
#'
sim_dist <- function(num, n, p) {
  # simulate from a random distribution and output n x pk matrix
  # num 1 for norm, 2 for unif, 3 for exp


  if (num == 1) {
    dist <- rnorm(n*p)
  } else if (num == 2) {
    dist <- runif(min=0, max=1, n=n*p)
  } else if (num == 3) {
    # mean-centred exponential so the noise is zero-mean like the others
    dist <- rexp(n = n*p, rate = 1) - 1
  } else {
    stop("sim_dist: 'num' must be 1 (normal), 2 (uniform), or 3 (exponential)",
         call. = FALSE)
  }
  out <- matrix(dist, nrow = n, ncol = p)
  return(out)
}


# ---------------------------------------------------------------------------
# Valid benchmark generator
# ---------------------------------------------------------------------------
#
# `ajive.data.sim()` draws each block's Individual scores independently of the
# joint scores, so its stored truth is not an identifiable decomposition: the
# Joint and Individual score spaces overlap. Measured overlap in the archived
# probe was 0.35. Comparisons against that truth penalise an estimator for
# failing to reproduce a model violation, so it cannot be used to accept a
# method correction.
#
# `simulate_blocks()` generates truth that satisfies the model the estimator
# targets: the joint score basis is orthonormal, and every block's Individual
# score basis is orthonormal and orthogonal to the joint basis. Ground truth is
# therefore the identifiable target, and a correct estimator should recover it.

#' Simulate multi-view Data Blocks with an identifiable ground truth
#'
#' Generates a list of Data Blocks whose Joint Component is shared across all
#' blocks and whose Individual Component is specific to each block, with score
#' spaces constructed so the decomposition is identifiable: the joint score
#' basis is orthonormal, and each block's individual score basis is orthonormal
#' and orthogonal to the joint basis. This is the generator to use when a
#' simulation is meant to test whether an estimator recovers the truth.
#'
#' For a deliberately misspecified stress case, where the joint and individual
#' score spaces are allowed to overlap, use [ajive.data.sim()].
#'
#' @param n Positive integer. Number of samples (rows) in each Data Block.
#' @param pks Positive integer vector. Number of features in each Data Block.
#' @param joint_rank Non-negative integer. Rank of the shared Joint Component.
#' @param individual_ranks Non-negative integer vector, one per Data Block. Rank
#'   of each block's Individual Component.
#' @param noise_sd Positive numeric. Standard deviation of the residual noise.
#' @param signal_sd Positive numeric. Standard deviation of the component
#'   loadings.
#' @param block_names Optional character vector of Data Block names.
#' @param seed Optional integer seed.
#'
#' @return A list with `blocks`, the list of simulated Data Blocks, and `truth`,
#'   a list containing the per-block Joint and Individual Component matrices,
#'   the residual, the joint and individual score bases, the per-block joint
#'   loadings, and the generating ranks.
#'
#' @seealso [ajive.data.sim()] for the overlapping-truth stress generator.
#'
#' @examples
#' sim <- simulate_blocks(n = 60, pks = c(50, 40, 30),
#'                        joint_rank = 2, individual_ranks = c(5, 4, 3),
#'                        seed = 1)
#' length(sim$blocks)
#' ncol(sim$truth$joint_basis)
#'
#' @export
simulate_blocks <- function(n, pks, joint_rank, individual_ranks,
                            noise_sd = 1, signal_sd = 1,
                            block_names = NULL, seed = NULL) {
  if (!is.numeric(n) || length(n) != 1L || !is.finite(n) ||
      n != as.integer(n) || n < 1) {
    cli::cli_abort("`n` must be a positive integer.", class = "rajiveplus_invalid_input")
  }
  if (!is.numeric(pks) || !length(pks) || any(!is.finite(pks)) ||
      any(pks != as.integer(pks)) || any(pks < 1)) {
    cli::cli_abort("`pks` must be a vector of positive integers.",
                   class = "rajiveplus_invalid_input")
  }
  if (!is.numeric(joint_rank) || length(joint_rank) != 1L ||
      !is.finite(joint_rank) || joint_rank != as.integer(joint_rank) ||
      joint_rank < 0) {
    cli::cli_abort("`joint_rank` must be a non-negative integer.",
                   class = "rajiveplus_invalid_input")
  }
  if (!is.numeric(individual_ranks) || !length(individual_ranks) ||
      length(individual_ranks) != length(pks) || any(!is.finite(individual_ranks)) ||
      any(individual_ranks != as.integer(individual_ranks)) ||
      any(individual_ranks < 0)) {
    cli::cli_abort("`individual_ranks` must be one non-negative integer per Data Block.",
                   class = "rajiveplus_invalid_input")
  }
  if (any(joint_rank + individual_ranks > n)) {
    cli::cli_abort(c(
      "The joint rank plus the largest individual rank must not exceed `n`.",
      "i" = paste0("joint_rank + max(individual_ranks) = ",
                   joint_rank + max(individual_ranks), " but n = ", n, ".")
    ), class = "rajiveplus_invalid_input")
  }
  if (!is.numeric(noise_sd) || length(noise_sd) != 1L || !is.finite(noise_sd) ||
      noise_sd < 0) {
    cli::cli_abort("`noise_sd` must be a non-negative finite numeric scalar.",
                   class = "rajiveplus_invalid_input")
  }
  if (!is.numeric(signal_sd) || length(signal_sd) != 1L || !is.finite(signal_sd) ||
      signal_sd <= 0) {
    cli::cli_abort("`signal_sd` must be a positive finite numeric scalar.",
                   class = "rajiveplus_invalid_input")
  }

  n <- as.integer(n)
  pks <- as.integer(pks)
  joint_rank <- as.integer(joint_rank)
  individual_ranks <- as.integer(individual_ranks)
  K <- length(pks)

  if (is.null(block_names)) {
    block_names <- paste0("block", seq_len(K))
  }
  if (length(block_names) != K || anyNA(block_names) ||
      any(!nzchar(block_names)) || anyDuplicated(block_names)) {
    cli::cli_abort("`block_names` must be one unique non-empty name per Data Block.",
                   class = "rajiveplus_invalid_input")
  }

  if (!is.null(seed)) {
    set.seed(seed)
  }

  # Orthonormal joint score basis, built from a Gaussian draw and reduced by QR.
  joint_basis <- .orthonormal_basis(n, joint_rank)

  # Each block's individual basis lives in the orthogonal complement of the
  # joint basis, so the two score spaces are orthogonal by construction.
  individual_bases <- lapply(seq_len(K), function(k) {
    .orthonormal_basis_in_complement(n, individual_ranks[k], joint_basis)
  })

  # The bases above are orthonormal, so each column has unit norm and a latent
  # component built from them has energy of order `rank` rather than `n`. The
  # latent scores are therefore rescaled to unit variance across samples, which
  # is the convention `ajive.data.sim()` implicitly follows. The bases are kept
  # alongside the scores because the basis is what defines the span, while the
  # scores are what set the signal magnitude.
  joint_scores <- joint_basis * sqrt(n)
  individual_scores <- lapply(individual_bases, function(basis) basis * sqrt(n))

  # The Joint Component is a single shared latent factor whose loadings are
  # sliced per block, which is what makes it joint rather than block-specific.
  p_total <- sum(pks)
  joint_loadings <- matrix(stats::rnorm(joint_rank * p_total, sd = signal_sd),
                           nrow = joint_rank, ncol = p_total)

  joint_matrices <- vector("list", K)
  individual_matrices <- vector("list", K)
  residual_matrices <- vector("list", K)
  individual_loadings <- vector("list", K)
  blocks <- vector("list", K)

  offset <- 0L
  for (k in seq_len(K)) {
    cols <- offset + seq_len(pks[k])
    offset <- offset + pks[k]

    J <- joint_scores %*% joint_loadings[, cols, drop = FALSE]

    W_k <- if (individual_ranks[k] == 0L) {
      matrix(numeric(0L), nrow = 0L, ncol = pks[k])
    } else {
      matrix(stats::rnorm(individual_ranks[k] * pks[k], sd = signal_sd),
             nrow = individual_ranks[k])
    }
    I <- individual_scores[[k]] %*% W_k
    E <- matrix(stats::rnorm(n * pks[k], sd = noise_sd), nrow = n, ncol = pks[k])

    individual_loadings[[k]] <- W_k
    joint_matrices[[k]] <- J
    individual_matrices[[k]] <- I
    residual_matrices[[k]] <- E
    blocks[[k]] <- J + I + E
  }

  names(blocks) <- block_names
  names(joint_matrices) <- block_names
  names(individual_matrices) <- block_names
  names(residual_matrices) <- block_names
  names(individual_loadings) <- block_names
  names(individual_bases) <- block_names

  colnames(joint_loadings) <- paste0("feature", seq_len(p_total))

  list(
    blocks = blocks,
    truth = list(
      joint = joint_matrices,
      individual = individual_matrices,
      residual = residual_matrices,
      joint_basis = joint_basis,
      individual_bases = individual_bases,
      joint_scores = joint_scores,
      individual_scores = individual_scores,
      joint_loadings = joint_loadings,
      individual_loadings = individual_loadings,
      joint_rank = joint_rank,
      individual_ranks = individual_ranks,
      block_names = block_names
    )
  )
}

#' Orthonormal basis with the requested number of columns
#' @noRd
.orthonormal_basis <- function(n, rank) {
  rank <- as.integer(rank)
  if (rank == 0L) {
    return(matrix(numeric(0L), nrow = n, ncol = 0L))
  }
  if (rank > n) {
    cli::cli_abort("A basis cannot have more columns than rows.",
                   class = "rajiveplus_invalid_input")
  }
  qr.Q(qr(matrix(stats::rnorm(n * rank), nrow = n, ncol = rank)))
}

#' Orthonormal basis for the orthogonal complement of an existing basis
#' @noRd
.orthonormal_basis_in_complement <- function(n, rank, basis) {
  rank <- as.integer(rank)
  n_basis <- ncol(basis)
  if (rank == 0L) {
    return(matrix(numeric(0L), nrow = n, ncol = 0L))
  }
  if (n_basis + rank > n) {
    cli::cli_abort(
      "The requested rank does not fit outside the supplied basis.",
      class = "rajiveplus_invalid_input"
    )
  }
  complement <- qr.Q(qr(cbind(basis, matrix(stats::rnorm(n * (n - n_basis)),
                                               nrow = n, ncol = n - n_basis))))
  complement[, n_basis + seq_len(rank), drop = FALSE]
}
