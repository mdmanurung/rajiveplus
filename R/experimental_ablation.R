# Internal fixed-rank correctness adapter. Never called by Rajive().
# Inputs are already preprocessed; no centering, scaling, imputation or threshold
# calibration is performed here. Statistical use requires a separate protocol.
.ablation_basis <- function(x) {
  if (!ncol(x)) return(matrix(numeric(), nrow(x), 0L))
  s <- svd(x, nu = min(dim(x)), nv = 0L)
  tolerance <- max(dim(x)) * .Machine$double.eps * max(s$d, 0)
  s$u[, seq_len(sum(s$d > tolerance)), drop = FALSE]
}

.ablation_prepare <- function(blocks, initial_ranks, seed = 1L) {
  if (!is.list(blocks) || length(blocks) < 2L ||
      any(!vapply(blocks, function(x) is.matrix(x) && is.numeric(x) &&
                    all(is.finite(x)), logical(1L)))) {
    stop("Experimental adapter requires finite complete numeric blocks.")
  }
  n <- nrow(blocks[[1L]])
  maximum <- vapply(blocks, function(x) min(dim(x)), integer(1L))
  if (any(vapply(blocks, nrow, integer(1L)) != n) ||
      length(initial_ranks) != length(blocks) ||
      any(!is.finite(initial_ranks)) ||
      any(initial_ranks < 1 | initial_ranks != floor(initial_ranks) |
            initial_ranks > maximum)) {
    stop("Experimental initial ranks must be positive and fit every block.")
  }
  fits <- .with_validation_rng(seed, lapply(seq_along(blocks), function(k) {
    get_svd_robustH(blocks[[k]], rank = min(initial_ranks[k] + 1L, maximum[k]))
  }))
  thresholds <- vapply(seq_along(blocks), function(k) {
    get_sv_threshold(fits[[k]]$d, rank = initial_ranks[k])
  }, numeric(1L))
  list(blocks = blocks, initial_ranks = as.integer(initial_ranks),
       block_fits = fits, sv_thresholds = thresholds, seed = seed,
       preprocessing = "already_preprocessed_no_transform")
}

.ablation_geometry <- function(cache, joint_rank, representation = c("raw", "orthonormal"),
                               aggregation = c("robust", "classical"), seed = 2L) {
  representation <- match.arg(representation)
  aggregation <- match.arg(aggregation)
  capacity <- min(cache$initial_ranks)
  if (length(joint_rank) != 1L || !is.finite(joint_rank) ||
      joint_rank < 0 || joint_rank != floor(joint_rank) || joint_rank > capacity) {
    stop("Fixed target Joint rank must be between zero and the stack capacity.")
  }
  scores <- lapply(seq_along(cache$blocks), function(k) {
    u <- cache$block_fits[[k]]$u[, seq_len(cache$initial_ranks[k]), drop = FALSE]
    if (representation == "orthonormal") .ablation_basis(u) else u
  })
  achieved <- vapply(scores, function(q) ncol(.ablation_basis(q)), integer(1L))
  if (any(achieved != cache$initial_ranks)) {
    stop("BLOCKED: retained block scores are numerically rank deficient.")
  }
  stacked <- do.call(cbind, scores)
  fit <- if (aggregation == "robust") {
    .with_validation_rng(seed, get_svd_robustH(stacked, rank = capacity))
  } else {
    svd(stacked, nu = capacity, nv = 0L)
  }
  raw_selected <- fit$u[, seq_len(joint_rank), drop = FALSE]
  before <- if (representation == "orthonormal") {
    .ablation_basis(raw_selected)
  } else raw_selected
  dropped <- .identifiability_filter(
    cache$blocks, before, cache$sv_thresholds, "l2", quiet = TRUE
  )
  after <- before[, setdiff(seq_len(ncol(before)), dropped), drop = FALSE]
  list(representation = representation, aggregation = aggregation, seed = seed,
       block_scores = scores, stacked_scores = stacked, amplitudes = fit$d,
       requested_joint_rank = as.integer(joint_rank),
       raw_selected_scores = raw_selected, pre_filter_scores = before,
       pre_filter_rank = ncol(before), identif_dropped = dropped,
       joint_scores = after, post_filter_rank = ncol(after),
       final_representation_rank_drop = joint_rank - ncol(before),
       statistic = if (aggregation == "classical") "classical_squared_singular_values"
                   else "robust_squared_amplitudes",
       projector_interpretation = representation == "orthonormal" &&
         aggregation == "classical")
}

.ablation_select_individual <- function(cache, geometry, seed = 3L) {
  # This preselected fit is shared by the I pair. The original raw-score
  # residualization is preserved, including its nonprojector behavior.
  .with_validation_rng(seed, lapply(seq_along(cache$blocks), function(k) {
    get_individual_decomposition_robustH(
      cache$blocks[[k]], geometry$joint_scores, cache$sv_thresholds[k], full = TRUE
    )
  }))
}

.ablation_finish <- function(cache, geometry,
                             individual = c("original", "constrained"),
                             seed = 3L, selected = NULL) {
  individual <- match.arg(individual)
  if (is.null(selected)) selected <- .ablation_select_individual(cache, geometry, seed)
  if (length(selected) != length(cache$blocks)) stop("Individual cache mismatch.")
  q <- .ablation_basis(geometry$joint_scores)
  result <- lapply(seq_along(cache$blocks), function(k) {
    X <- cache$blocks[[k]]
    original <- selected[[k]]
    ind <- original
    if (individual == "constrained") {
      projected <- original$full - q %*% crossprod(q, original$full)
      s <- svd(projected, nu = min(dim(projected)), nv = min(dim(projected)))
      # Scale to the preconstraint matrix as well: an exactly removed fit must
      # not acquire a spurious rank by normalizing roundoff to its own tiny norm.
      original_scale <- max(svd(original$full, nu = 0L, nv = 0L)$d, 0)
      tolerance <- max(dim(projected)) * .Machine$double.eps *
        max(original_scale, s$d, 0)
      rank <- min(original$rank, sum(s$d > tolerance))
      ind <- list(u = s$u[, seq_len(rank), drop = FALSE],
                  d = s$d[seq_len(rank)], v = s$v[, seq_len(rank), drop = FALSE],
                  rank = as.integer(rank))
      ind$full <- svd_reconstruction(ind)
      ind$constraint_rank_tolerance <- tolerance
    }
    joint <- get_joint_decomposition_robustH(X, geometry$joint_scores, full = TRUE)
    residual <- X - joint$full - ind$full
    list(joint = joint, individual = ind, residual = residual,
         selected_individual_rank = original$rank,
         individual_rank_drop = original$rank - ind$rank,
         individual_true_span_leakage = norm(crossprod(q, ind$full), "F") /
           max(norm(ind$full, "F"), .Machine$double.eps),
         reconstruction_relative = norm(X - joint$full - ind$full - residual, "F") /
           max(norm(X, "F"), .Machine$double.eps))
  })
  names(result) <- names(cache$blocks)
  list(geometry = geometry, individual = individual, selected = selected,
       blocks = result, seed = seed, status = "SMOKE_ONLY_NOT_CALIBRATED")
}

.ablation_require_threshold <- function(thresholds) {
  finite <- thresholds[is.finite(thresholds)]
  if (!length(finite)) stop("BLOCKED: no effective finite experimental threshold.")
  max(finite)
}
