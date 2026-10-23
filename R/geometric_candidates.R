.extract_block_basis <- function(decomposition, requested_rank,
                                 tolerance = NULL) {
  if (!is.list(decomposition) || is.null(decomposition$u) ||
      is.null(decomposition$d)) {
    stop("`decomposition` must contain `u` and `d`.", call. = FALSE)
  }
  requested_rank <- as.integer(requested_rank)
  if (length(requested_rank) != 1L || is.na(requested_rank) ||
      requested_rank < 0L || requested_rank > ncol(decomposition$u) ||
      requested_rank > length(decomposition$d)) {
    stop("`requested_rank` is outside the decomposition bounds.", call. = FALSE)
  }
  amplitudes <- decomposition$d[seq_len(requested_rank)]
  if (is.null(tolerance)) {
    scale <- if (length(decomposition$d)) max(decomposition$d) else 0
    tolerance <- max(dim(decomposition$u)) * .Machine$double.eps * scale
  }
  if (!is.numeric(tolerance) || length(tolerance) != 1L || is.na(tolerance) ||
      !is.finite(tolerance) || tolerance < 0) {
    stop("`tolerance` must be one finite nonnegative number.", call. = FALSE)
  }
  keep <- which(amplitudes > tolerance)
  basis <- decomposition$u[, keep, drop = FALSE]
  if (length(keep)) {
    basis <- qr.Q(qr(basis), complete = FALSE)[, seq_along(keep), drop = FALSE]
  }
  list(
    basis = basis,
    requested_rank = requested_rank,
    effective_rank = as.integer(length(keep)),
    tolerance = tolerance,
    retained_directions = as.integer(keep),
    dropped_directions = as.integer(setdiff(seq_len(requested_rank), keep))
  )
}

.aggregate_geometric_bases <- function(bases, tolerance = NULL) {
  if (!is.list(bases) || length(bases) < 2L ||
      any(!vapply(bases, is.matrix, logical(1L)))) {
    stop("`bases` must contain at least two matrices.", call. = FALSE)
  }
  rows <- vapply(bases, nrow, integer(1L))
  if (length(unique(rows)) != 1L) {
    stop("All bases must have the same row count.", call. = FALSE)
  }
  orthonormal <- lapply(bases, function(basis) {
    if (!ncol(basis)) return(matrix(numeric(), nrow(basis), 0L))
    qr.Q(qr(basis), complete = FALSE)[, seq_len(ncol(basis)), drop = FALSE]
  })
  projector_sum <- Reduce(`+`, lapply(orthonormal, .projector))
  eig <- eigen(projector_sum, symmetric = TRUE)
  if (is.null(tolerance)) {
    tolerance <- max(1, max(abs(eig$values))) * rows[[1L]] *
      .Machine$double.eps
  }
  keep <- which(eig$values > tolerance)
  basis <- eig$vectors[, keep, drop = FALSE]
  projector <- .projector(basis)
  list(
    basis = basis,
    eigenvalues = eig$values,
    effective_rank = as.integer(length(keep)),
    tolerance = tolerance,
    projector_sum = projector_sum,
    basis_gram_max_error = if (ncol(basis)) {
      max(abs(crossprod(basis) - diag(ncol(basis))))
    } else 0,
    projector_symmetry_relative_error =
      norm(projector - t(projector), "F") / max(norm(projector, "F"), .Machine$double.eps),
    projector_idempotence_relative_error =
      norm(projector %*% projector - projector, "F") /
      max(norm(projector, "F"), .Machine$double.eps)
  )
}

.identifiability_rejections <- function(blocks, joint_scores, thresholds,
                                        norm = c("l2", "l1")) {
  norm <- .match_identifiability_norm(norm)
  if (length(thresholds) != length(blocks)) {
    stop("`thresholds` must have one value per block.", call. = FALSE)
  }
  rejected <- integer()
  for (k in seq_along(blocks)) {
    for (j in seq_len(ncol(joint_scores))) {
      score <- crossprod(blocks[[k]], joint_scores[, j])
      value <- .identifiability_projection_norm(score, norm)
      if (!is.finite(value) || value < thresholds[[k]]) {
        rejected <- c(rejected, j)
      }
    }
  }
  sort(unique(as.integer(rejected)))
}

.get_individual_decomposition_exact <- function(
    X, joint_scores, sv_threshold, full = TRUE) {
  X_orthog <- if (is.null(joint_scores) || ncol(joint_scores) == 0L) X else
    X - joint_scores %*% crossprod(joint_scores, X)
  robust <- get_svd_robustH(X_orthog)
  requested_rank <- sum(robust$d > sv_threshold)
  robust <- truncate_svd(robust, requested_rank)
  fitted <- svd_reconstruction(robust)
  if (!is.null(joint_scores) && ncol(joint_scores) > 0L) {
    fitted <- fitted - joint_scores %*% crossprod(joint_scores, fitted)
  }
  exact <- svd(fitted, nu = min(dim(fitted)), nv = min(dim(fitted)))
  tolerance <- max(dim(fitted)) * .Machine$double.eps *
    if (length(exact$d)) max(exact$d) else 0
  rank <- min(requested_rank, sum(exact$d > tolerance))
  list(
    u = exact$u[, seq_len(rank), drop = FALSE],
    d = exact$d[seq_len(rank)],
    v = exact$v[, seq_len(rank), drop = FALSE],
    full = if (isTRUE(full)) fitted else NA,
    rank = as.integer(rank),
    requested_rank = as.integer(requested_rank),
    refactorization_tolerance = tolerance
  )
}
