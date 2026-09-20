.abort_invalid_input <- function(message, argument, reason, block = NULL,
                                 .envir = parent.frame()) {
  cli::cli_abort(
    message,
    class = "rajiveplus_invalid_input",
    argument = argument,
    reason = reason,
    block = block,
    .envir = .envir
  )
}

.validate_data_blocks <- function(blocks, allow_missing = FALSE) {
  if (!is.list(blocks) || length(blocks) < 2L) {
    .abort_invalid_input(
      "`blocks` must contain at least two Data Blocks.",
      "blocks", "too_few_blocks"
    )
  }

  block_names <- names(blocks)
  if (is.null(block_names)) {
    block_names <- paste0("block", seq_along(blocks))
  } else if (length(block_names) != length(blocks) || anyNA(block_names) ||
             any(!nzchar(block_names)) || anyDuplicated(block_names)) {
    .abort_invalid_input(
      "Data Block names must be nonempty and unique, or omitted entirely.",
      "blocks", "invalid_block_names"
    )
  }
  names(blocks) <- block_names

  for (block in seq_along(blocks)) {
    x <- blocks[[block]]
    if (!is.matrix(x)) {
      .abort_invalid_input(
        "Every Data Block must be a matrix.",
        "blocks", "non_matrix_block", as.integer(block)
      )
    }
    if (!is.numeric(x)) {
      .abort_invalid_input(
        "Every Data Block must be numeric.",
        "blocks", "non_numeric_block", as.integer(block)
      )
    }
    if (any(dim(x) == 0L)) {
      .abort_invalid_input(
        "Every Data Block must contain at least one sample and one feature.",
        "blocks", "empty_block", as.integer(block)
      )
    }
    invalid_values <- if (allow_missing) {
      any(is.nan(x) | is.infinite(x))
    } else {
      any(!is.finite(x))
    }
    if (invalid_values) {
      .abort_invalid_input(
        "Data Block values must be finite; native mode permits `NA` only where the Observed Mask is false.",
        "blocks", "invalid_values", as.integer(block)
      )
    }
  }

  sample_counts <- vapply(blocks, nrow, integer(1L))
  if (length(unique(sample_counts)) != 1L) {
    .abort_invalid_input(
      "All Data Blocks must have the same number of samples.",
      "blocks", "sample_count_mismatch"
    )
  }

  sample_names <- lapply(blocks, rownames)
  has_sample_names <- !vapply(sample_names, is.null, logical(1L))
  if (any(has_sample_names) && !all(has_sample_names)) {
    .abort_invalid_input(
      "Sample row names must be present for every Data Block or absent from every Data Block.",
      "blocks", "mixed_sample_names"
    )
  }
  if (all(has_sample_names)) {
    invalid_names <- vapply(sample_names, function(x) {
      anyNA(x) || any(!nzchar(x)) || anyDuplicated(x)
    }, logical(1L))
    if (any(invalid_names)) {
      .abort_invalid_input(
        "Sample row names must be nonmissing, nonempty, and unique.",
        "blocks", "invalid_sample_names", as.integer(which(invalid_names)[1L])
      )
    }
    mismatched <- vapply(sample_names[-1L], function(x) {
      !identical(x, sample_names[[1L]])
    }, logical(1L))
    if (any(mismatched)) {
      .abort_invalid_input(
        "Sample row names must be identical and in the same order across Data Blocks.",
        "blocks", "sample_order_mismatch",
        as.integer(which(mismatched)[1L] + 1L)
      )
    }
  }

  for (block in seq_along(blocks)) {
    feature_names <- colnames(blocks[[block]])
    if (is.null(feature_names)) {
      colnames(blocks[[block]]) <- paste0("feature", seq_len(ncol(blocks[[block]])))
    } else if (anyNA(feature_names) || any(!nzchar(feature_names)) ||
               anyDuplicated(feature_names)) {
      .abort_invalid_input(
        "Feature names must be nonmissing, nonempty, and unique when supplied.",
        "blocks", "invalid_feature_names", as.integer(block)
      )
    }
  }

  blocks
}

.as_count <- function(value, argument, allow_na = FALSE, minimum = 0L,
                      maximum = .Machine$integer.max) {
  if (allow_na && length(value) == 1L && is.atomic(value) && is.na(value)) {
    return(NA_integer_)
  }
  if (!is.numeric(value) || length(value) != 1L || is.na(value) ||
      !is.finite(value) || value != floor(value)) {
    .abort_invalid_input(
      "`{argument}` must be an integer-valued scalar.",
      argument, "not_integer"
    )
  }
  if (value < minimum || value > maximum) {
    .abort_invalid_input(
      "`{argument}` is outside its supported bounds.",
      argument, "out_of_bounds"
    )
  }
  as.integer(value)
}

.validate_fit_controls <- function(blocks, initial_signal_ranks, full,
                                   n_wedin_samples, n_rand_dir_samples,
                                   joint_rank, n_perm_samples, num_cores,
                                   seed, allow_native_rank = FALSE) {
  if (!is.logical(full) || length(full) != 1L || is.na(full)) {
    .abort_invalid_input(
      "`full` must be `TRUE` or `FALSE`.", "full", "not_logical"
    )
  }
  if (!is.numeric(initial_signal_ranks) ||
      length(initial_signal_ranks) != length(blocks) ||
      anyNA(initial_signal_ranks) || any(!is.finite(initial_signal_ranks)) ||
      any(initial_signal_ranks != floor(initial_signal_ranks))) {
    reason <- if (length(initial_signal_ranks) != length(blocks)) {
      "length_mismatch"
    } else {
      "not_integer"
    }
    .abort_invalid_input(
      "`initial_signal_ranks` must contain one integer-valued rank per Data Block.",
      "initial_signal_ranks", reason
    )
  }
  initial_signal_ranks <- as.integer(initial_signal_ranks)
  max_ranks <- vapply(blocks, function(x) min(dim(x)), integer(1L))
  if (any(initial_signal_ranks < 1L | initial_signal_ranks > max_ranks)) {
    .abort_invalid_input(
      "Each initial signal rank must be between 1 and the effective Data Block rank bound.",
      "initial_signal_ranks", "out_of_bounds"
    )
  }

  n_wedin_samples <- .as_count(
    n_wedin_samples, "n_wedin_samples", allow_na = TRUE, minimum = 1L
  )
  n_rand_dir_samples <- .as_count(
    n_rand_dir_samples, "n_rand_dir_samples", allow_na = TRUE, minimum = 1L
  )
  n_perm_samples <- .as_count(
    n_perm_samples, "n_perm_samples", allow_na = TRUE, minimum = 1L
  )
  num_cores <- .as_count(num_cores, "num_cores", minimum = 1L)
  seed <- .as_count(seed, "seed", allow_na = TRUE, minimum = 0L)

  if (allow_native_rank && is.character(joint_rank)) {
    if (length(joint_rank) != 1L || !identical(joint_rank, "native_cv")) {
      .abort_invalid_input(
        "Character `joint_rank` must be exactly `native_cv` in native mode.",
        "joint_rank", "unsupported_value"
      )
    }
  } else {
    joint_rank <- .as_count(
      joint_rank, "joint_rank", allow_na = TRUE, minimum = 0L,
      maximum = min(initial_signal_ranks)
    )
  }

  list(
    initial_signal_ranks = initial_signal_ranks,
    full = full,
    n_wedin_samples = n_wedin_samples,
    n_rand_dir_samples = n_rand_dir_samples,
    joint_rank = joint_rank,
    n_perm_samples = n_perm_samples,
    num_cores = num_cores,
    seed = seed
  )
}

.prepare_complete_blocks <- function(blocks) {
  original_blocks <- blocks
  feature_map <- vector("list", length(blocks))
  names(feature_map) <- names(blocks)

  fitted_blocks <- lapply(seq_along(blocks), function(block) {
    x <- blocks[[block]]
    feature_sd <- apply(x, 2L, stats::sd)
    retained <- is.finite(feature_sd) &
      feature_sd >= .Machine$double.eps^0.5
    feature_map[[block]] <<- data.frame(
      original_index = seq_len(ncol(x)),
      feature = colnames(x),
      retained = retained,
      fitted_index = ifelse(retained, cumsum(retained), NA_integer_),
      stringsAsFactors = FALSE
    )
    if (!any(retained)) {
      .abort_invalid_input(
        "A Data Block has no nondegenerate features after policy filtering.",
        "blocks", "no_effective_features", as.integer(block)
      )
    }
    if (any(!retained)) {
      cli::cli_warn(
        c("Degenerate feature(s) in Data Block {.val {names(blocks)[[block]]}} were excluded from fitting.",
          "i" = "{.val {sum(!retained)}} feature(s) retain explicit output mapping and Residual values."),
        class = "rajiveplus_degenerate_block"
      )
    }
    x[, retained, drop = FALSE]
  })
  names(fitted_blocks) <- names(blocks)

  list(
    blocks = fitted_blocks,
    original_blocks = original_blocks,
    feature_map = feature_map
  )
}

.restore_component_features <- function(block_decomps, original_blocks,
                                        feature_map) {
  n_blocks <- length(original_blocks)
  for (block in seq_len(n_blocks)) {
    original <- original_blocks[[block]]
    retained <- feature_map[[block]]$retained
    for (component in c("individual", "joint")) {
      index <- .block_decomp_index(block, component, n_blocks)
      record <- block_decomps[[index]]
      expanded_v <- matrix(0, nrow = ncol(original),
                           ncol = ncol(record$v))
      if (!is.null(colnames(original))) {
        rownames(expanded_v) <- colnames(original)
      }
      if (!is.null(colnames(record$v))) {
        colnames(expanded_v) <- colnames(record$v)
      }
      expanded_v[retained, ] <- record$v
      record$v <- expanded_v
      if (!is.null(rownames(original))) {
        rownames(record$u) <- rownames(original)
      }
      if (is.matrix(record$full)) {
        expanded_full <- matrix(0, nrow = nrow(original),
                                ncol = ncol(original))
        if (!is.null(dimnames(original))) {
          dimnames(expanded_full) <- dimnames(original)
        }
        expanded_full[, retained] <- record$full
        record$full <- expanded_full
      }
      block_decomps[[index]] <- record
    }

    residual_index <- .block_decomp_index(block, "residual", n_blocks)
    residual <- block_decomps[[residual_index]]
    if (is.matrix(residual)) {
      expanded_residual <- original
      expanded_residual[, retained] <- residual
      block_decomps[[residual_index]] <- expanded_residual
    }
  }
  block_decomps
}

.identity_feature_map <- function(blocks) {
  out <- lapply(blocks, function(x) {
    feature <- colnames(x)
    if (is.null(feature)) feature <- paste0("feature", seq_len(ncol(x)))
    data.frame(
      original_index = seq_len(ncol(x)),
      feature = feature,
      retained = rep(TRUE, ncol(x)),
      fitted_index = seq_len(ncol(x)),
      stringsAsFactors = FALSE
    )
  })
  names(out) <- names(blocks)
  out
}
