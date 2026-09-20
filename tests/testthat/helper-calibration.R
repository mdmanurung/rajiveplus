# Calibration / reproducibility helpers for rajiveplus tests.
# See PLANS.md "Phase 0 — Test harness".
#
# These helpers are sourced automatically by testthat (file name begins with
# "helper-").  They are *not* `test_that()` blocks, so sourcing this file
# produces 0 test results and 0 errors.

# ---------------------------------------------------------------------------
# skip_if_not_slow
# ---------------------------------------------------------------------------

#' Skip a test unless RAJIVE_RUN_SLOW=1 is set in the environment.
#'
#' Slow calibration tests are gated behind this helper so that
#' `devtools::test()` remains fast.  Run them with:
#'   RAJIVE_RUN_SLOW=1 Rscript -e "devtools::test(filter='calibration')"
skip_if_not_slow <- function() {
  testthat::skip_if_not(
    Sys.getenv("RAJIVE_RUN_SLOW") == "1",
    "set RAJIVE_RUN_SLOW=1 to run slow calibration tests"
  )
}

# ---------------------------------------------------------------------------
# with_lecuyer_seed
# ---------------------------------------------------------------------------

#' Evaluate `expr` after setting L'Ecuyer-CMRG RNG, seeded, restoring on exit.
#'
#' @param seed Integer seed passed to `set.seed()`.
#' @param expr Expression to evaluate.
#'
#' @return The value of `expr`.
with_lecuyer_seed <- function(seed, expr) {
  prev_kind <- RNGkind()
  RNGkind("L'Ecuyer-CMRG")
  set.seed(seed)
  on.exit(do.call(RNGkind, as.list(prev_kind)), add = TRUE)
  force(expr)
}

# ---------------------------------------------------------------------------
# null_blocks
# ---------------------------------------------------------------------------

#' Build K independent Gaussian blocks, each n x pks[k].
#'
#' @param K Integer. Number of blocks.
#' @param n Integer. Number of observations (rows).
#' @param pks Integer vector. Number of features per block.
#' @param seed Integer. RNG seed (uses base RNG kind).
#'
#' @return Named list of length K of n x pks[k] matrices.
null_blocks <- function(K, n, pks, seed = 42L) {
  set.seed(seed)
  lapply(seq_len(K), function(k) matrix(stats::rnorm(n * pks[k]), n, pks[k]))
}

# ---------------------------------------------------------------------------
# signal_blocks
# ---------------------------------------------------------------------------

#' Build blocks with known joint + individual structure via ajive.data.sim().
#'
#' @param K Integer. Number of blocks.
#' @param n Integer. Number of observations.
#' @param pks Integer vector. Number of features per block.
#' @param rankJ Integer. True joint rank.
#' @param rankA Integer vector. True individual ranks per block.
#' @param sd_noise Numeric. Ignored (kept for signature compatibility).
#' @param seed Integer. RNG seed.
#'
#' @return Named list of length K of n x pks[k] matrices with joint+individual
#'   structure embedded.
signal_blocks <- function(K, n, pks, rankJ, rankA, sd_noise = 1, seed = 42L) {
  set.seed(seed)
  Y <- ajive.data.sim(K = K, rankJ = rankJ, rankA = rankA, n = n, pks = pks)
  Y$sim_data
}

# ---------------------------------------------------------------------------
# haar_perp_sample
# ---------------------------------------------------------------------------

#' Draw r Haar-uniform random directions in the column space of perp_basis.
#'
#' Projects a random Gaussian n x r matrix onto the subspace spanned by
#' perp_basis (which must have orthonormal columns).  The result is Haar-uniform
#' on the Grassmannian G(r, dim(col space)).
#'
#' @param perp_basis Matrix. n x s orthonormal basis for the subspace.
#' @param r Integer. Number of directions to draw (r <= s).
#'
#' @return n x r matrix whose columns lie in the column space of perp_basis.
haar_perp_sample <- function(perp_basis, r) {
  if (r > ncol(perp_basis)) {
    stop("`r` cannot exceed the complement dimension.", call. = FALSE)
  }
  nr <- nrow(perp_basis)
  raw <- matrix(stats::rnorm(nr * r), nr, r)
  projected <- perp_basis %*% crossprod(perp_basis, raw)
  qr.Q(qr(projected), complete = FALSE)[, seq_len(r), drop = FALSE]
}

# ---------------------------------------------------------------------------
# null_blocks_clustered
# ---------------------------------------------------------------------------

#' Build K Gaussian null blocks with a shared cluster random effect.
#'
#' Each row belongs to one of `n_clusters` clusters; rows in the same cluster
#' share a per-feature offset drawn N(0, cluster_sd^2).  Used to validate
#' cluster bootstrap: naive observation-level bootstrap gives anti-conservative
#' CIs on these data because effective sample size is N_clusters, not n_obs.
#'
#' @param K Integer. Number of blocks.
#' @param n_clusters Integer. Number of distinct clusters (subjects/donors).
#' @param obs_per_cluster Integer scalar or length-`n_clusters` vector. Number
#'   of observations per cluster.
#' @param pks Integer vector of length K. Features per block.
#' @param cluster_sd Numeric. SD of the cluster-level random effect.
#' @param seed Integer. RNG seed.
#'
#' @return List with:
#'   \describe{
#'     \item{`blocks`}{Named list of length K of `n x pks[k]` matrices.}
#'     \item{`cluster`}{Integer vector of length n; cluster ID for each row.}
#'   }
null_blocks_clustered <- function(K, n_clusters, obs_per_cluster, pks,
                                  cluster_sd = 0.5, seed = 42L) {
  set.seed(seed)
  if (length(obs_per_cluster) == 1L) {
    obs_per_cluster <- rep(as.integer(obs_per_cluster), n_clusters)
  }
  stopifnot(length(obs_per_cluster) == n_clusters)
  cluster <- rep(seq_len(n_clusters), times = obs_per_cluster)
  n <- length(cluster)
  blocks <- lapply(seq_len(K), function(k) {
    offsets <- matrix(stats::rnorm(n_clusters * pks[k], sd = cluster_sd),
                      n_clusters, pks[k])
    noise <- matrix(stats::rnorm(n * pks[k]), n, pks[k])
    offsets[cluster, , drop = FALSE] + noise
  })
  names(blocks) <- paste0("block", seq_len(K))
  list(blocks = blocks, cluster = cluster)
}

# ---------------------------------------------------------------------------
# signal_blocks_clustered
# ---------------------------------------------------------------------------

#' Build blocks with known joint+individual structure PLUS a cluster effect.
#'
#' Constructs blocks via `ajive.data.sim()`, then adds a per-feature random
#' offset shared by all observations of the same cluster.  The joint structure
#' identifies a true joint signal; the cluster effect creates the within-row
#' correlation that motivates cluster bootstrap.
#'
#' @inheritParams null_blocks_clustered
#' @param rankJ Integer. True joint rank.
#' @param rankA Integer vector. True individual ranks per block.
#'
#' @return List with `blocks` and `cluster` (same shape as
#'   [`null_blocks_clustered`]).
signal_blocks_clustered <- function(K, n_clusters, obs_per_cluster, pks,
                                    rankJ, rankA,
                                    cluster_sd = 0.5, seed = 42L) {
  set.seed(seed)
  if (length(obs_per_cluster) == 1L) {
    obs_per_cluster <- rep(as.integer(obs_per_cluster), n_clusters)
  }
  stopifnot(length(obs_per_cluster) == n_clusters)
  cluster <- rep(seq_len(n_clusters), times = obs_per_cluster)
  n <- length(cluster)
  Y <- ajive.data.sim(K = K, rankJ = rankJ, rankA = rankA, n = n, pks = pks,
                      dist.type = 1)
  blocks <- lapply(seq_len(K), function(k) {
    offsets <- matrix(stats::rnorm(n_clusters * pks[k], sd = cluster_sd),
                      n_clusters, pks[k])
    Y$sim_data[[k]] + offsets[cluster, , drop = FALSE]
  })
  names(blocks) <- paste0("block", seq_len(K))
  list(blocks = blocks, cluster = cluster)
}

# ---------------------------------------------------------------------------
# binom_ci
# ---------------------------------------------------------------------------

#' Binomial sd_mult-sigma CI for proportion p estimated from B trials.
#'
#' Used to derive assertion tolerance comments above slow tests.
#'
#' @param p Numeric. Nominal proportion.
#' @param B Integer. Number of trials.
#' @param sd_mult Numeric. Half-width in standard deviations.
#'
#' @return Named numeric(2): c(low, high).
binom_ci <- function(p, B, sd_mult = 3) {
  sd <- sqrt(p * (1 - p) / B)
  c(low = p - sd_mult * sd, high = p + sd_mult * sd)
}
