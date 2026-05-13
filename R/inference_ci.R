.ci_probs <- function(level) {
  alpha <- 1 - level
  c(alpha / 2, 1 - alpha / 2)
}

.ci_percentile <- function(draws, level) {
  draws <- draws[is.finite(draws)]
  if (length(draws) == 0L) return(c(lower = NA_real_, upper = NA_real_))
  q <- stats::quantile(draws, probs = .ci_probs(level), na.rm = TRUE,
                       names = FALSE, type = 6)
  c(lower = q[[1L]], upper = q[[2L]])
}

.ci_basic <- function(estimate, draws, level) {
  pct <- .ci_percentile(draws, level)
  c(lower = 2 * estimate - pct[["upper"]],
    upper = 2 * estimate - pct[["lower"]])
}

.safe_bca_quantile <- function(estimate, boot, jack, level) {
  boot <- boot[is.finite(boot)]
  jack <- jack[is.finite(jack)]
  if (length(boot) == 0L) return(c(lower = NA_real_, upper = NA_real_))
  if (length(jack) < 2L || stats::var(jack) == 0) {
    return(.ci_percentile(boot, level))
  }

  B <- length(boot)
  prop_less <- mean(boot < estimate)
  prop_less <- min(max(prop_less, 1 / (2 * B)), 1 - 1 / (2 * B))
  z0 <- stats::qnorm(prop_less)

  jack_bar <- mean(jack)
  dif <- jack_bar - jack
  den <- 6 * (sum(dif^2)^(3 / 2))
  accel <- if (den > .Machine$double.eps) sum(dif^3) / den else 0

  alpha <- .ci_probs(level)
  z_alpha <- stats::qnorm(alpha)
  denom <- 1 - accel * (z0 + z_alpha)
  adj <- stats::pnorm(z0 + (z0 + z_alpha) / denom)
  adj[!is.finite(adj)] <- alpha[!is.finite(adj)]
  adj <- pmin(pmax(adj, 0), 1)

  q <- stats::quantile(boot, probs = adj, na.rm = TRUE,
                       names = FALSE, type = 6)
  c(lower = q[[1L]], upper = q[[2L]])
}

.ci_interval <- function(estimate, boot, jack = NULL, level, method) {
  if (method == "percentile") return(.ci_percentile(boot, level))
  if (method == "basic") return(.ci_basic(estimate, boot, level))
  .safe_bca_quantile(estimate, boot, jack, level)
}

.feature_names_for_block <- function(block, loadings) {
  if (!is.null(colnames(block)) && length(colnames(block)) == nrow(loadings)) {
    return(colnames(block))
  }
  rn <- rownames(loadings)
  if (!is.null(rn)) return(rn)
  paste0("feature", seq_len(nrow(loadings)))
}

.sample_names_for_scores <- function(blocks, scores) {
  rn <- rownames(blocks[[1L]])
  if (!is.null(rn) && length(rn) == nrow(scores)) return(rn)
  rn <- rownames(scores)
  if (!is.null(rn)) return(rn)
  paste0("sample", seq_len(nrow(scores)))
}

.jackknife_indices <- function(n, cluster = NULL) {
  if (is.null(cluster)) {
    return(lapply(seq_len(n), function(i) setdiff(seq_len(n), i)))
  }
  if (length(cluster) != n) {
    cli::cli_abort("`cluster` must have one value per sample.")
  }
  cl <- factor(cluster)
  lapply(levels(cl), function(level) which(cl != level))
}

.rajive_jackknife <- function(ajive_output, blocks, initial_signal_ranks,
                              target, cluster = NULL, ...) {
  n_ref <- nrow(blocks[[1L]])
  idx_list <- .jackknife_indices(n_ref, cluster)
  K <- length(blocks)
  n_comp <- ncol(ajive_output$joint_scores)
  dots <- .refit_dots_with_identifiability_norm(list(...), ajive_output)

  if (target == "joint_rank") {
    out <- rep(NA_real_, length(idx_list))
  } else if (target == "var_explained") {
    out <- array(NA_real_, dim = c(K, n_comp, length(idx_list)))
  } else if (target == "loadings") {
    out <- lapply(seq_len(K), function(k) {
      array(NA_real_, dim = c(ncol(blocks[[k]]), n_comp, length(idx_list)))
    })
    names(out) <- .default_block_names(blocks)
    ref_loadings <- lapply(seq_len(K), function(k) {
      ajive_output$block_decomps[[3L * (k - 1L) + 2L]]$v
    })
  } else {
    cli::cli_abort("BCa jackknife is not defined for target {.val {target}}.")
  }

  for (i in seq_along(idx_list)) {
    idx <- idx_list[[i]]
    b_list <- lapply(blocks, function(x) x[idx, , drop = FALSE])
    fit_i <- tryCatch(
      do.call(Rajive, c(list(b_list, initial_signal_ranks), dots)),
      error = function(e) NULL
    )
    if (is.null(fit_i)) next

    if (target == "joint_rank") {
      out[[i]] <- fit_i$joint_rank
    } else if (target == "var_explained") {
      out[, , i] <- .component_var_explained(fit_i, b_list, n_comp)
    } else if (target == "loadings") {
      for (k in seq_len(K)) {
        L_i <- fit_i$block_decomps[[3L * (k - 1L) + 2L]]$v
        if (is.null(L_i) || ncol(L_i) == 0L) next
        n_use <- min(ncol(L_i), n_comp)
        L_sub <- L_i[, seq_len(n_use), drop = FALSE]
        Q <- .procrustes_align(ref_loadings[[k]][, seq_len(n_use), drop = FALSE],
                               L_sub)
        out[[k]][, seq_len(n_use), i] <- L_sub %*% Q
      }
    }
  }
  out
}

.ci_result_frame <- function(target, block, component, feature, sample,
                             estimate, lower, upper, level, method,
                             n_replicates) {
  data.frame(
    target = target,
    block = block,
    component = component,
    feature = feature,
    sample = sample,
    estimate = estimate,
    lower = lower,
    upper = upper,
    level = level,
    method = method,
    n_replicates = n_replicates,
    stringsAsFactors = FALSE
  )
}

#' Bootstrap confidence intervals for RaJIVE quantities
#'
#' Computes bootstrap confidence intervals for joint loadings, joint scores,
#' block/component variance explained, or joint rank.  The original data
#' \code{blocks} are required because \code{\link{Rajive}} objects do not store
#' the input matrices.
#'
#' @param ajive_output An object returned by \code{\link{Rajive}}.
#' @param blocks List of original block matrices, with samples in rows.
#' @param initial_signal_ranks Integer vector passed to \code{\link{Rajive}}
#'   when refitting bootstrap and jackknife samples.
#' @param target Quantity for which to compute intervals.
#' @param method Interval method. \code{"bca"} uses delete-one observation
#'   jackknife acceleration, or delete-one cluster acceleration when
#'   \code{cluster} is supplied.
#' @param level Confidence level.
#' @param B Number of bootstrap refits.
#' @param cluster Optional cluster identifier per sample.
#' @param strata Optional stratum identifier per sample for clustered
#'   bootstrap resampling.
#' @param num_cores Reserved for future parallel bootstrap execution.
#' @param replicates Optional output from the internal bootstrap engine.
#' @param ... Additional arguments forwarded to \code{\link{Rajive}} during
#'   bootstrap and jackknife refits.
#'
#' @return A tidy data frame with interval estimates.
#' @export
rajive_ci <- function(ajive_output,
                      blocks,
                      initial_signal_ranks,
                      target = c("loadings", "scores", "var_explained",
                                 "joint_rank"),
                      method = c("percentile", "bca", "basic"),
                      level = 0.95,
                      B = 500L,
                      cluster = NULL,
                      strata = NULL,
                      num_cores = 1L,
                      replicates = NULL,
                      ...) {
  target <- match.arg(target)
  method <- match.arg(method)

  if (!inherits(ajive_output, "rajive")) {
    cli::cli_abort("`ajive_output` must be an object of class {.val rajive}.")
  }
  .validate_feature_space(blocks)
  .validate_matched_samples(blocks)
  if (!is.numeric(level) || length(level) != 1L || level <= 0 || level >= 1) {
    cli::cli_abort("`level` must be a number in (0, 1).")
  }
  B <- as.integer(B)
  if (B < 1L) cli::cli_abort("`B` must be a positive integer.")
  if (method == "bca" && target == "scores") {
    cli::cli_abort("BCa intervals are not defined for sample-specific scores because delete-one jackknife refits omit the target sample.")
  }

  keep <- switch(target,
                 loadings = "loadings",
                 scores = "scores",
                 var_explained = "var_explained",
                 joint_rank = "joint_rank")
  if (is.null(replicates)) {
    replicates <- .rajive_bootstrap(
      ajive_output = ajive_output,
      blocks = blocks,
      initial_signal_ranks = initial_signal_ranks,
      B = B,
      cluster = cluster,
      strata = strata,
      num_cores = num_cores,
      keep = keep,
      ...
    )
  }

  jack <- NULL
  if (method == "bca") {
    jack <- .rajive_jackknife(
      ajive_output = ajive_output,
      blocks = blocks,
      initial_signal_ranks = initial_signal_ranks,
      target = target,
      cluster = cluster,
      ...
    )
  }

  n_comp <- ncol(ajive_output$joint_scores)
  block_names <- .default_block_names(blocks)
  rows <- list()

  if (target == "joint_rank") {
    draws <- as.numeric(replicates$joint_rank)
    ci <- .ci_interval(ajive_output$joint_rank, draws, jack, level, method)
    return(.ci_result_frame(
      target = target, block = NA_character_, component = NA_integer_,
      feature = NA_character_, sample = NA_character_,
      estimate = ajive_output$joint_rank,
      lower = round(ci[["lower"]]), upper = round(ci[["upper"]]),
      level = level, method = method,
      n_replicates = sum(is.finite(draws))
    ))
  }

  if (target == "var_explained") {
    estimate <- .component_var_explained(ajive_output, blocks, n_comp)
    for (k in seq_along(blocks)) {
      for (j in seq_len(n_comp)) {
        draws <- replicates$var_explained[k, j, ]
        ci <- .ci_interval(estimate[k, j], draws,
                           if (method == "bca") jack[k, j, ] else NULL,
                           level, method)
        rows[[length(rows) + 1L]] <- .ci_result_frame(
          target, block_names[[k]], j, NA_character_, NA_character_,
          estimate[k, j], ci[["lower"]], ci[["upper"]], level, method,
          sum(is.finite(draws))
        )
      }
    }
    return(do.call(rbind, rows))
  }

  if (target == "loadings") {
    for (k in seq_along(blocks)) {
      load <- ajive_output$block_decomps[[3L * (k - 1L) + 2L]]$v
      features <- .feature_names_for_block(blocks[[k]], load)
      for (j in seq_len(n_comp)) {
        for (i in seq_len(nrow(load))) {
          draws <- replicates$loadings[[k]][i, j, ]
          ci <- .ci_interval(load[i, j], draws,
                             if (method == "bca") jack[[k]][i, j, ] else NULL,
                             level, method)
          rows[[length(rows) + 1L]] <- .ci_result_frame(
            target, block_names[[k]], j, features[[i]], NA_character_,
            load[i, j], ci[["lower"]], ci[["upper"]], level, method,
            sum(is.finite(draws))
          )
        }
      }
    }
    return(do.call(rbind, rows))
  }

  scores <- ajive_output$joint_scores
  samples <- .sample_names_for_scores(blocks, scores)
  for (j in seq_len(n_comp)) {
    for (i in seq_len(nrow(scores))) {
      draws <- replicates$scores[i, j, ]
      ci <- .ci_interval(scores[i, j], draws, NULL, level, method)
      rows[[length(rows) + 1L]] <- .ci_result_frame(
        target, NA_character_, j, NA_character_, samples[[i]],
        scores[i, j], ci[["lower"]], ci[["upper"]], level, method,
        sum(is.finite(draws))
      )
    }
  }
  do.call(rbind, rows)
}
