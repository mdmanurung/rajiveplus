# Internal matrix extractors shared by inference helpers.

.default_block_names <- function(blocks, K = NULL) {
  if (!is.null(blocks) && !is.null(names(blocks)) && all(nzchar(names(blocks)))) {
    return(names(blocks))
  }
  if (is.null(K)) K <- length(blocks)
  paste0("block", seq_len(K))
}

.block_decomp_index <- function(block, component, n_blocks) {
  if (!is.integer(n_blocks) || length(n_blocks) != 1L || is.na(n_blocks) ||
      n_blocks < 1L) {
    stop("`n_blocks` must be a positive integer scalar.", call. = FALSE)
  }
  if (!is.integer(block) || length(block) != 1L || is.na(block) ||
      block < 1L || block > n_blocks) {
    stop("`block` must be a 1-based integer within `n_blocks`.", call. = FALSE)
  }
  if (!is.character(component) || length(component) != 1L ||
      is.na(component) ||
      !component %in% c("joint", "individual", "residual")) {
    stop(
      "`component` must be exactly one of: joint, individual, residual.",
      call. = FALSE
    )
  }

  offset <- switch(component, individual = 1L, joint = 2L, residual = 3L)
  3L * (block - 1L) + offset
}

.get_block_decomp <- function(fit, block, component) {
  if (!is.list(fit) || !is.list(fit[["block_decomps"]])) {
    stop("`fit` must contain a list-like `block_decomps` field.", call. = FALSE)
  }
  block_decomps <- fit[["block_decomps"]]
  if (length(block_decomps) < 3L || length(block_decomps) %% 3L != 0L) {
    stop(
      "`fit$block_decomps` must contain three entries per Data Block.",
      call. = FALSE
    )
  }

  n_blocks <- as.integer(length(block_decomps) / 3L)
  index <- .block_decomp_index(block, component, n_blocks)
  block_decomps[[index]]
}

.abort_component_matrix_unavailable <- function(block, component, reason) {
  cli::cli_abort(
    "The {.val {component}} component matrix is unavailable for Data Block {block} ({reason}).",
    class = "rajiveplus_component_matrix_unavailable",
    block = block,
    component = component,
    reason = reason
  )
}

.get_component_matrix <- function(fit, block, component) {
  decomp <- .get_block_decomp(fit, block, component)

  if (identical(component, "residual")) {
    if (is.matrix(decomp)) {
      return(decomp)
    }
    if (length(decomp) == 1L && is.atomic(decomp) && is.na(decomp)) {
      .abort_component_matrix_unavailable(
        block, component, "residual_not_stored"
      )
    }
    .abort_component_matrix_unavailable(
      block, component, "unsupported_component_matrix"
    )
  }

  if (!is.list(decomp)) {
    .abort_component_matrix_unavailable(
      block, component, "invalid_component_record"
    )
  }
  if (is.matrix(decomp[["full"]])) {
    return(decomp[["full"]])
  }

  u <- decomp[["u"]]
  d <- decomp[["d"]]
  v <- decomp[["v"]]
  valid_record <- is.matrix(u) && is.numeric(u) &&
    is.numeric(d) && is.atomic(d) &&
    is.matrix(v) && is.numeric(v) &&
    length(d) == ncol(u) && length(d) == ncol(v) &&
    all(is.finite(u)) && all(is.finite(d)) && all(is.finite(v))
  if (!valid_record) {
    .abort_component_matrix_unavailable(
      block, component, "invalid_component_record"
    )
  }

  if (length(d) == 0L) {
    out <- matrix(0, nrow = nrow(u), ncol = nrow(v))
    if (!is.null(rownames(u)) || !is.null(rownames(v))) {
      dimnames(out) <- list(rownames(u), rownames(v))
    }
    return(out)
  }

  out <- sweep(u, 2L, d, `*`) %*% t(v)
  if (!is.null(rownames(u)) || !is.null(rownames(v))) {
    dimnames(out) <- list(rownames(u), rownames(v))
  }
  out
}

.validate_feature_space <- function(mats) {
  if (!is.list(mats) || length(mats) == 0L) {
    cli::cli_abort("`blocks` must be a non-empty list of numeric matrices.")
  }
  bad_matrix <- !vapply(mats, is.matrix, logical(1L))
  if (any(bad_matrix)) {
    cli::cli_abort("Every block must be a matrix.")
  }
  bad_numeric <- !vapply(mats, is.numeric, logical(1L))
  if (any(bad_numeric)) {
    cli::cli_abort("Every block must be numeric.")
  }
  bad_dim <- vapply(mats, function(x) any(dim(x) == 0L), logical(1L))
  if (any(bad_dim)) {
    cli::cli_abort("Every block must have at least one sample and one feature.")
  }
  bad_finite <- !vapply(mats, function(x) all(is.finite(x)), logical(1L))
  if (any(bad_finite)) {
    cli::cli_abort("Every block must contain only finite values.")
  }
  invisible(mats)
}

.validate_matched_samples <- function(mats) {
  n <- vapply(mats, nrow, integer(1L))
  if (length(unique(n)) != 1L) {
    cli::cli_abort("All blocks must have the same number of samples.")
  }

  rn <- lapply(mats, rownames)
  has_rn <- vapply(rn, function(x) !is.null(x), logical(1L))
  if (all(has_rn)) {
    ref <- rn[[1L]]
    bad <- vapply(rn[-1L], function(x) !identical(ref, x), logical(1L))
    if (any(bad)) {
      cli::cli_abort("All blocks must have identical sample row names.")
    }
  }
  invisible(mats)
}

.dim_label <- function(x) {
  paste(dim(x), collapse = " x ")
}

.validate_component_dims <- function(mats, blocks, component, block_names) {
  if (is.null(blocks)) {
    return(invisible(mats))
  }

  bad <- which(!mapply(function(x, y) identical(dim(x), dim(y)), mats, blocks))
  if (length(bad) > 0L) {
    k <- bad[[1L]]
    block_label <- block_names[[k]]
    block_dim <- .dim_label(blocks[[k]])
    component_dim <- .dim_label(mats[[k]])
    cli::cli_abort(c(
      "Extracted {.val {component}} matrix dimensions do not match `blocks`.",
      "i" = "Block {.val {block_label}}: `blocks` has dimensions {block_dim}, but the fitted component has dimensions {component_dim}.",
      "i" = "This usually means the fitted object was created from different or stale input blocks."
    ))
  }

  invisible(mats)
}

.extract_one_component <- function(ajive_output, k, component) {
  .get_component_matrix(ajive_output, as.integer(k), component)
}

.extract_block_matrices <- function(ajive_output,
                                    blocks = NULL,
                                    component = c("data", "joint",
                                                  "individual", "residual")) {
  component <- match.arg(component)

  if (!is.null(blocks)) {
    .validate_feature_space(blocks)
    .validate_matched_samples(blocks)
  }

  if (component == "data") {
    if (is.null(blocks)) {
      cli::cli_abort("`blocks` must be supplied when `component = 'data'`.")
    }
    names(blocks) <- .default_block_names(blocks)
    return(blocks)
  }

  if (is.null(ajive_output$block_decomps)) {
    cli::cli_abort("`ajive_output` must contain `block_decomps`.")
  }

  K <- length(ajive_output$block_decomps) / 3L
  if (K != as.integer(K) || K < 1L) {
    cli::cli_abort("`ajive_output$block_decomps` must contain 3 entries per block.")
  }
  K <- as.integer(K)
  if (!is.null(blocks) && length(blocks) != K) {
    cli::cli_abort("`blocks` must contain the same number of blocks as `ajive_output`.")
  }
  block_names <- .default_block_names(blocks, K)

  if (component %in% c("joint", "individual")) {
    out <- lapply(seq_len(K), function(k) .extract_one_component(ajive_output, k, component))
    names(out) <- block_names
    .validate_component_dims(out, blocks, component, block_names)
    return(out)
  }

  if (is.null(blocks)) {
    cli::cli_abort("`blocks` must be supplied when `component = 'residual'`.")
  }
  joint <- .extract_block_matrices(ajive_output, blocks, "joint")
  indiv <- .extract_block_matrices(ajive_output, blocks, "individual")
  out <- lapply(seq_len(K), function(k) blocks[[k]] - joint[[k]] - indiv[[k]])
  names(out) <- block_names
  out
}

#' Feature Mapping for RaJIVE Data Blocks
#'
#' Returns the mapping between original input features and the feature columns
#' used during fitting. Degenerate features remain in the map with
#' \code{retained = FALSE} and are restored to component output dimensions.
#'
#' @param ajive_output An object returned by \code{\link{Rajive}}.
#'
#' @return A named list with one data frame per Data Block. Each data frame
#'   contains \code{original_index}, \code{feature}, \code{retained}, and
#'   \code{fitted_index}.
#'
#' @export
get_feature_map <- function(ajive_output) {
  if (!inherits(ajive_output, "rajive") ||
      !is.list(ajive_output[["feature_map"]])) {
    cli::cli_abort(
      "`ajive_output` does not contain a feature mapping.",
      class = "rajiveplus_feature_map_unavailable"
    )
  }
  ajive_output[["feature_map"]]
}

.joint_coordinate_contract <- function(ajive_output) {
  if (!inherits(ajive_output, "rajive") ||
      !is.matrix(ajive_output[["joint_scores"]])) {
    cli::cli_abort(
      "`ajive_output` does not contain a complete Joint coordinate system.",
      class = "rajiveplus_joint_coordinates_unavailable"
    )
  }
  score_basis <- ajive_output[["joint_scores"]]
  n_blocks <- as.integer(length(ajive_output[["block_decomps"]]) / 3L)
  coefficients <- lapply(seq_len(n_blocks), function(block) {
    crossprod(
      score_basis,
      .get_component_matrix(ajive_output, block, "joint")
    )
  })
  names(coefficients) <- names(ajive_output[["feature_map"]])
  list(
    schema_version = 1L,
    estimand = "joint_sample_subspace_and_block_coefficients",
    score_basis = score_basis,
    block_coefficients = coefficients,
    tied_spectrum_policy = "subspace"
  )
}

#' Common Joint Coordinates
#'
#' Returns the canonical sample-space Joint basis and the coefficient matrix
#' for each Data Block. For block `k`, the Joint matrix is exactly
#' `score_basis %*% block_coefficients[[k]]`. This representation is stable to
#' sign, permutation, and within-subspace rotations when interpreted through
#' its reconstructed matrix or projector. Tied spectra therefore have a
#' subspace estimand rather than individually identified columns.
#'
#' @param ajive_output An object returned by [Rajive()].
#'
#' @return A list containing the schema version, estimand, canonical
#'   `score_basis`, per-block `block_coefficients`, and tied-spectrum policy.
#' @export
get_joint_coordinates <- function(ajive_output) {
  .joint_coordinate_contract(ajive_output)
}
