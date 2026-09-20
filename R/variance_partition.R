#' Feature-level joint, individual, and residual variance partition
#'
#' Computes a per-feature sum-of-squares decomposition for each block from a
#' fitted \code{\link{Rajive}} object and the original data blocks used for
#' fitting.
#'
#' @param ajive_output An object returned by \code{\link{Rajive}}.
#' @param blocks List of original block matrices, with samples in rows and
#'   features in columns.
#' @param eps Numeric tolerance used to identify zero component totals.
#'
#' @return A data frame with one row per feature and columns:
#'   \code{feature}, \code{block}, \code{joint_ss}, \code{individual_ss},
#'   \code{residual_ss}, \code{component_total_ss}, \code{data_total_ss},
#'   \code{joint_prop}, \code{individual_prop}, \code{residual_prop}, and
#'   \code{reconstruction_error}. The legacy \code{reconstruction_error}
#'   remains the absolute difference between data energy and the sum of the
#'   three component energies. New columns report all pairwise cross terms,
#'   relative matrix reconstruction error, and relative energy closure error.
#'
#' @export
joint_variance_partition <- function(ajive_output, blocks, eps = 1e-12) {
  if (!inherits(ajive_output, "rajive")) {
    cli::cli_abort("`ajive_output` must be an object of class {.val rajive}.")
  }
  if (!is.numeric(eps) || length(eps) != 1L || !is.finite(eps) || eps < 0) {
    cli::cli_abort("`eps` must be a non-negative finite numeric scalar.")
  }

  if (!is.list(blocks) || length(blocks) < 1L ||
      any(!vapply(blocks, is.matrix, logical(1L)))) {
    cli::cli_abort("`blocks` must be a nonempty list of matrices.")
  }
  data <- blocks
  names(data) <- .default_block_names(data)
  joint <- .extract_block_matrices(ajive_output, NULL, "joint")
  indiv <- .extract_block_matrices(ajive_output, NULL, "individual")
  if (length(data) != length(joint)) {
    cli::cli_abort("`blocks` must align with the fitted Data Blocks.")
  }
  resid <- lapply(seq_along(data), function(k) data[[k]] - joint[[k]] - indiv[[k]])

  block_names <- .default_block_names(data)
  out <- lapply(seq_along(data), function(k) {
    X <- data[[k]]
    J <- joint[[k]]
    I <- indiv[[k]]
    E <- resid[[k]]

    if (!identical(dim(X), dim(J)) || !identical(dim(X), dim(I)) ||
        !identical(dim(X), dim(E))) {
      cli::cli_abort("Extracted component matrices must match the dimensions of `blocks`.")
    }

    observed <- is.finite(X)
    if (any(is.infinite(X) | is.nan(X))) {
      cli::cli_abort("`blocks` may contain finite values or `NA` only.")
    }
    X_observed <- X
    X_observed[!observed] <- 0
    J_observed <- J
    I_observed <- I
    E_observed <- E
    J_observed[!observed] <- 0
    I_observed[!observed] <- 0
    E_observed[!observed] <- 0

    joint_ss <- colSums(J_observed^2)
    indiv_ss <- colSums(I_observed^2)
    resid_ss <- colSums(E_observed^2)
    component_total_ss <- joint_ss + indiv_ss + resid_ss
    data_total_ss <- colSums(X_observed^2)
    joint_individual_cross <- 2 * colSums(J_observed * I_observed)
    joint_residual_cross <- 2 * colSums(J_observed * E_observed)
    individual_residual_cross <- 2 * colSums(I_observed * E_observed)
    energy_reconstruction_ss <- component_total_ss +
      joint_individual_cross + joint_residual_cross +
      individual_residual_cross
    matrix_error_ss <- colSums(
      (X_observed - J_observed - I_observed - E_observed)^2
    )
    matrix_reconstruction_error <- sqrt(matrix_error_ss) /
      pmax(sqrt(data_total_ss), eps)
    energy_closure_error <- abs(data_total_ss - energy_reconstruction_ss) /
      pmax(data_total_ss, eps)

    denom <- ifelse(component_total_ss > eps, component_total_ss, NA_real_)
    joint_prop <- joint_ss / denom
    indiv_prop <- indiv_ss / denom
    resid_prop <- resid_ss / denom

    zero <- is.na(denom)
    joint_prop[zero] <- 0
    indiv_prop[zero] <- 0
    resid_prop[zero] <- 0

    feature <- colnames(X)
    if (is.null(feature)) {
      feature <- paste0("feature", seq_len(ncol(X)))
    }

    data.frame(
      feature = feature,
      block = block_names[[k]],
      joint_ss = joint_ss,
      individual_ss = indiv_ss,
      residual_ss = resid_ss,
      component_total_ss = component_total_ss,
      data_total_ss = data_total_ss,
      joint_individual_cross = joint_individual_cross,
      joint_residual_cross = joint_residual_cross,
      individual_residual_cross = individual_residual_cross,
      energy_reconstruction_ss = energy_reconstruction_ss,
      joint_prop = joint_prop,
      individual_prop = indiv_prop,
      residual_prop = resid_prop,
      reconstruction_error = abs(data_total_ss - component_total_ss),
      matrix_reconstruction_error = matrix_reconstruction_error,
      energy_closure_error = energy_closure_error,
      row.names = NULL,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, out)
}
