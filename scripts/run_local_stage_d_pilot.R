#!/usr/bin/env Rscript

devtools::load_all(".", quiet = TRUE)

scenarios <- c("mcar", "mar_like", "structured_block_rows", "left_censoring")
seeds <- .validation_seed_manifest(
  scenarios, exploratory_replicates = 2L, final_replicates = 0L,
  master_seed = 20261000L
)

rows <- lapply(seq_len(nrow(seeds)), function(index) {
  item <- seeds[index, ]
  simulation <- .simulate_identifiable_data(
    2L, 30L, c(12L, 10L), 1L, c(1L, 1L),
    joint_strength = 4, individual_strength = 1.5, snr = 3,
    seed = item$data_seed
  )
  blocks <- simulation$noisy
  mask <- lapply(blocks, function(x) matrix(TRUE, nrow(x), ncol(x)))
  mask <- .with_validation_rng(item$method_seed, {
    if (item$scenario_id == "mcar") {
      mask <- lapply(mask, function(m) {
        m[sample.int(length(m), floor(0.2 * length(m)))] <- FALSE
        m
      })
    } else if (item$scenario_id == "mar_like") {
      high <- simulation$truth$joint_scores[, 1L] > 0
      for (k in seq_along(mask)) {
        candidates <- which(row(mask[[k]]) %in% which(high))
        mask[[k]][sample(candidates, floor(0.3 * length(candidates)))] <- FALSE
      }
    } else if (item$scenario_id == "structured_block_rows") {
      mask[[2L]][seq(2L, 30L, by = 5L), ] <- FALSE
    } else {
      for (k in seq_along(mask)) {
        threshold <- stats::quantile(blocks[[k]], 0.15)
        mask[[k]][blocks[[k]] <= threshold] <- FALSE
      }
    }
    mask
  })
  observed_blocks <- Map(function(x, m) { x[!m] <- NA_real_; x }, blocks, mask)
  native <- tryCatch(
    Rajive(
      observed_blocks, c(2L, 2L), missing = "native", mask = mask,
      joint_rank = 1L, missing_control = rajive_missing_control(
        outer_max_iter = 3L, completion_max_iter = 5L,
        warn_nonconvergence = FALSE
      )
    ),
    error = function(error) error
  )
  mean_imputed <- Map(function(x, m) {
    for (j in seq_len(ncol(x))) {
      value <- mean(x[m[, j], j])
      x[!m[, j], j] <- value
    }
    x
  }, blocks, mask)
  simple <- tryCatch(
    Rajive(mean_imputed, c(2L, 2L), joint_rank = 1L,
           n_wedin_samples = NA, n_rand_dir_samples = NA),
    error = function(error) error
  )
  truth <- simulation$truth$joint_projector
  error_metric <- function(fit) {
    if (inherits(fit, "error")) return(NA_real_)
    norm(.projector(fit$joint_scores) - truth, "F") / sqrt(2)
  }
  complete_rows <- Reduce(`&`, lapply(mask, function(m) rowSums(m) == ncol(m)))
  data.frame(
    scenario_id = item$scenario_id,
    replicate_id = item$replicate_id,
    data_seed = item$data_seed,
    method_seed = item$method_seed,
    native_status = if (inherits(native, "error")) "ERROR" else "PASS",
    native_projector_error = error_metric(native),
    simple_imputation_projector_error = error_metric(simple),
    native_converged = if (inherits(native, "error")) NA else
      isTRUE(native$missing$convergence$converged),
    complete_case_rows = sum(complete_rows),
    missmda_status = if (requireNamespace("missMDA", quietly = TRUE))
      "AVAILABLE_NOT_RUN_IN_BOUNDED_PILOT" else "BLOCKED_DEPENDENCY_UNAVAILABLE",
    stringsAsFactors = FALSE
  )
})

write.table(
  do.call(rbind, rows),
  "docs/_codexdocs/execution/2026-09-19/stage_d_native_pilot.tsv",
  sep = "\t", quote = TRUE, row.names = FALSE, na = "NA"
)
