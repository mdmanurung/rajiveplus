.abort_invalid_result <- function(message, .envir = parent.frame()) {
  cli::cli_abort(
    message,
    class = "rajiveplus_invalid_result",
    .envir = .envir
  )
}

.validate_component_record <- function(record, role, block) {
  if (!is.list(record)) {
    .abort_invalid_result(
      "The {role} record for Data Block {block} must be a list."
    )
  }

  u <- record[["u"]]
  d <- record[["d"]]
  v <- record[["v"]]
  valid_factors <- is.matrix(u) && is.numeric(u) &&
    is.numeric(d) && is.atomic(d) &&
    is.matrix(v) && is.numeric(v) &&
    length(d) == ncol(u) && length(d) == ncol(v) &&
    all(is.finite(u)) && all(is.finite(d)) && all(is.finite(v))
  if (!valid_factors) {
    .abort_invalid_result(
      "The {role} record for Data Block {block} must contain compatible numeric `u`, `d`, and `v` fields."
    )
  }

  if (!is.null(record[["rank"]])) {
    rank <- record[["rank"]]
    if (!is.numeric(rank) || length(rank) != 1L || is.na(rank) ||
        !is.finite(rank) || rank != as.integer(rank) ||
        as.integer(rank) != length(d)) {
      .abort_invalid_result(
        "The {role} rank for Data Block {block} must equal the stored factor rank."
      )
    }
  }

  full <- record[["full"]]
  if (!is.null(full) &&
      !(is.matrix(full) && is.numeric(full) && all(is.finite(full))) &&
      !(length(full) == 1L && is.atomic(full) && is.na(full))) {
    .abort_invalid_result(
      "The {role} `full` field for Data Block {block} must be a numeric matrix or `NA`."
    )
  }
  if (is.matrix(full) && !identical(dim(full), c(nrow(u), nrow(v)))) {
    .abort_invalid_result(
      "The {role} `full` matrix dimensions do not match its factors for Data Block {block}."
    )
  }

  c(samples = nrow(u), features = nrow(v))
}

.new_rajive <- function(block_decomps, joint_scores, joint_rank,
                        joint_rank_sel, feature_map = NULL,
                        method_profile = NULL) {
  if (!is.list(block_decomps) || length(block_decomps) < 6L ||
      length(block_decomps) %% 3L != 0L) {
    .abort_invalid_result(
      "`block_decomps` must contain three component entries for at least two Data Blocks."
    )
  }
  n_blocks <- as.integer(length(block_decomps) / 3L)

  block_dims <- lapply(seq_len(n_blocks), function(block) {
    individual <- block_decomps[[.block_decomp_index(
      block, "individual", n_blocks
    )]]
    joint <- block_decomps[[.block_decomp_index(block, "joint", n_blocks)]]
    residual <- block_decomps[[.block_decomp_index(
      block, "residual", n_blocks
    )]]
    individual_dims <- .validate_component_record(
      individual, "Individual", block
    )
    joint_dims <- .validate_component_record(joint, "Joint", block)
    if (!identical(individual_dims, joint_dims)) {
      .abort_invalid_result(
        "Joint and Individual component dimensions differ for Data Block {block}."
      )
    }
    valid_residual <- is.matrix(residual) && is.numeric(residual) &&
      all(is.finite(residual)) && identical(dim(residual), unname(joint_dims))
    absent_residual <- length(residual) == 1L && is.atomic(residual) &&
      is.na(residual)
    if (!valid_residual && !absent_residual) {
      .abort_invalid_result(
        "The Residual component for Data Block {block} must be a compatible numeric matrix or `NA`."
      )
    }
    joint_dims
  })

  sample_counts <- vapply(block_dims, `[[`, integer(1L), "samples")
  if (length(unique(sample_counts)) != 1L) {
    .abort_invalid_result("All Data Blocks must have the same sample count.")
  }
  if (!is.matrix(joint_scores) || !is.numeric(joint_scores) ||
      any(!is.finite(joint_scores))) {
    .abort_invalid_result("`joint_scores` must be a finite numeric matrix.")
  }
  if (!is.integer(joint_rank) || length(joint_rank) != 1L ||
      is.na(joint_rank) || joint_rank < 0L) {
    .abort_invalid_result("`joint_rank` must be a non-negative integer scalar.")
  }
  if (nrow(joint_scores) != sample_counts[[1L]] ||
      ncol(joint_scores) != joint_rank) {
    .abort_invalid_result(
      "`joint_scores` dimensions must match the sample count and `joint_rank`."
    )
  }
  if (!is.list(joint_rank_sel)) {
    .abort_invalid_result("`joint_rank_sel` must be a list.")
  }

  if (!is.null(feature_map)) {
    valid_feature_map <- is.list(feature_map) &&
      length(feature_map) == n_blocks &&
      all(vapply(feature_map, is.data.frame, logical(1L)))
    if (!valid_feature_map) {
      .abort_invalid_result(
        "`feature_map` must contain one data frame per Data Block."
      )
    }
  }
  if (!is.null(method_profile) &&
      (!is.list(method_profile) ||
       !all(c("id", "version", "status", "config_hash", "config") %in%
              names(method_profile)))) {
    .abort_invalid_result("`method_profile` does not match the internal schema.")
  }

  out <- list(
    block_decomps = block_decomps,
    joint_scores = joint_scores,
    joint_rank = joint_rank,
    joint_rank_sel = joint_rank_sel
  )
  if (!is.null(feature_map)) out$feature_map <- feature_map
  if (!is.null(method_profile)) out$method_profile <- method_profile
  structure(out, class = "rajive")
}

.new_rajive_rank_only <- function(joint_scores, joint_rank, joint_rank_sel,
                                  method_profile = NULL) {
  if (!is.matrix(joint_scores) || !is.numeric(joint_scores) ||
      any(!is.finite(joint_scores))) {
    .abort_invalid_result("`joint_scores` must be a finite numeric matrix.")
  }
  if (!is.integer(joint_rank) || length(joint_rank) != 1L ||
      is.na(joint_rank) || joint_rank < 0L || ncol(joint_scores) != joint_rank) {
    .abort_invalid_result(
      "`joint_rank` must be a non-negative integer matching `joint_scores`."
    )
  }
  if (!is.list(joint_rank_sel)) {
    .abort_invalid_result("`joint_rank_sel` must be a list.")
  }
  if (!is.null(method_profile) &&
      (!is.list(method_profile) ||
       !all(c("id", "version", "status", "config_hash", "config") %in%
              names(method_profile)))) {
    .abort_invalid_result("`method_profile` does not match the internal schema.")
  }

  out <- list(
    joint_scores = joint_scores,
    joint_rank = joint_rank,
    joint_rank_sel = joint_rank_sel
  )
  if (!is.null(method_profile)) out$method_profile <- method_profile
  structure(out, class = "rajive_rank_only")
}

.new_rajive_incomplete <- function(fit, missing) {
  if (!inherits(fit, "rajive")) {
    .abort_invalid_result("`fit` must be a complete validated `rajive` object.")
  }
  required <- c(
    "mask", "observed", "patterns", "original_blocks", "block_names",
    "initial_signal_ranks", "preprocess", "control", "convergence"
  )
  if (!is.list(missing) || !all(required %in% names(missing))) {
    .abort_invalid_result(
      "Native missing-data metadata is missing required top-level fields."
    )
  }

  n_blocks <- as.integer(length(fit$block_decomps) / 3L)
  aligned <- c("mask", "observed", "original_blocks")
  if (any(vapply(missing[aligned], length, integer(1L)) != n_blocks) ||
      length(missing$block_names) != n_blocks) {
    .abort_invalid_result(
      "Native missing-data metadata must align with the fitted Data Blocks."
    )
  }
  if (!is.list(missing$patterns) || !is.list(missing$control) ||
      !is.list(missing$convergence)) {
    .abort_invalid_result(
      "Native missing-data pattern, control, and convergence metadata must be lists."
    )
  }

  fit$missing <- missing
  class(fit) <- c("rajive_incomplete", "rajive")
  fit
}
