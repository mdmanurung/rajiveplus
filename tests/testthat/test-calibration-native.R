# Slow, dataset-level calibration for native missing-data fitting.
#
# The primary estimand is the joint-score subspace under declared MCAR,
# MAR-like, and structured whole-row missingness. The paired comparison uses
# identical simulated datasets for the legacy five-iteration outer cap, the
# promoted 30-iteration default, and mean imputation. Bootstrap coverage is
# evaluated separately under MCAR because generic MNAR coverage is not claimed.

.native_calibration_cache <- new.env(parent = emptyenv())

.native_mask <- function(blocks, truth, scenario, seed) {
  .with_validation_rng(seed, {
    mask <- lapply(blocks, function(x) matrix(TRUE, nrow(x), ncol(x)))
    if (scenario == "mcar") {
      mask <- lapply(mask, function(m) {
        m[sample.int(length(m), floor(0.2 * length(m)))] <- FALSE
        m
      })
    } else if (scenario == "mar_like") {
      high <- truth$joint_scores[, 1L] > stats::median(truth$joint_scores[, 1L])
      for (k in seq_along(mask)) {
        high_cells <- which(row(mask[[k]]) %in% which(high))
        low_cells <- which(row(mask[[k]]) %in% which(!high))
        mask[[k]][sample(high_cells, floor(0.30 * length(high_cells)))] <- FALSE
        mask[[k]][sample(low_cells, floor(0.10 * length(low_cells)))] <- FALSE
      }
    } else if (scenario == "structured_rows") {
      mask[[2L]][seq(2L, nrow(mask[[2L]]), by = 5L), ] <- FALSE
    } else {
      stop("unknown native calibration scenario", call. = FALSE)
    }
    mask
  })
}

.native_projector_error <- function(fit, truth_projector) {
  norm(.projector(fit$joint_scores) - truth_projector, "F") / sqrt(2)
}

.native_mean_impute <- function(blocks, mask) {
  Map(function(x, observed) {
    for (feature in seq_len(ncol(x))) {
      value <- mean(x[observed[, feature], feature])
      x[!observed[, feature], feature] <- value
    }
    x
  }, blocks, mask)
}

.run_native_recovery_calibration <- function() {
  if (exists("recovery", envir = .native_calibration_cache, inherits = FALSE)) {
    return(get("recovery", envir = .native_calibration_cache, inherits = FALSE))
  }
  seeds <- .validation_seed_manifest(
    c("mcar", "mar_like", "structured_rows"),
    exploratory_replicates = 0L, final_replicates = 20L,
    master_seed = 20261100L
  )
  rows <- calibration_lapply(seq_len(nrow(seeds)), function(index) {
    item <- seeds[index, ]
    started <- proc.time()[["elapsed"]]
    tryCatch({
      simulation <- .simulate_identifiable_data(
        2L, 30L, c(12L, 10L), 1L, c(1L, 1L),
        joint_strength = 4, individual_strength = 1.5, snr = 3,
        seed = item$data_seed
      )
      mask <- .native_mask(
        simulation$noisy, simulation$truth, item$scenario_id,
        item$method_seed
      )
      observed <- Map(function(x, m) {
        x[!m] <- NA_real_
        x
      }, simulation$noisy, mask)
      fit_once <- function(control) {
        .with_validation_rng(item$method_seed + 100L, Rajive(
          observed, c(2L, 2L), missing = "native", mask = mask,
          joint_rank = 1L, identifiability_norm = "l2",
          missing_control = control
        ))
      }
      legacy <- fit_once(rajive_missing_control(
        outer_max_iter = 5L, warn_nonconvergence = FALSE
      ))
      promoted <- fit_once(rajive_missing_control(warn_nonconvergence = FALSE))
      imputed <- .native_mean_impute(simulation$noisy, mask)
      simple <- .with_validation_rng(item$method_seed + 200L, Rajive(
        imputed, c(2L, 2L), joint_rank = 1L,
        n_wedin_samples = NA, n_rand_dir_samples = NA,
        n_perm_samples = NA, num_cores = 1L
      ))
      data.frame(
        scenario_id = item$scenario_id,
        replicate_id = item$replicate_id,
        data_seed = item$data_seed,
        method_seed = item$method_seed,
        status = "PASS",
        legacy_converged = isTRUE(legacy$missing$convergence$converged),
        promoted_converged = isTRUE(promoted$missing$convergence$converged),
        legacy_n_iter = legacy$missing$convergence$n_iter,
        promoted_n_iter = promoted$missing$convergence$n_iter,
        legacy_projector_error = .native_projector_error(
          legacy, simulation$truth$joint_projector
        ),
        promoted_projector_error = .native_projector_error(
          promoted, simulation$truth$joint_projector
        ),
        mean_imputation_projector_error = .native_projector_error(
          simple, simulation$truth$joint_projector
        ),
        runtime_seconds = proc.time()[["elapsed"]] - started,
        error = NA_character_,
        stringsAsFactors = FALSE
      )
    }, error = function(error) {
      data.frame(
        scenario_id = item$scenario_id,
        replicate_id = item$replicate_id,
        data_seed = item$data_seed,
        method_seed = item$method_seed,
        status = "ERROR",
        legacy_converged = NA,
        promoted_converged = NA,
        legacy_n_iter = NA_integer_,
        promoted_n_iter = NA_integer_,
        legacy_projector_error = NA_real_,
        promoted_projector_error = NA_real_,
        mean_imputation_projector_error = NA_real_,
        runtime_seconds = proc.time()[["elapsed"]] - started,
        error = conditionMessage(error),
        stringsAsFactors = FALSE
      )
    })
  })
  rows <- do.call(rbind, rows)
  write_calibration_evidence(rows, "native-recovery.tsv")
  assign("recovery", rows, envir = .native_calibration_cache)
  rows
}

.run_native_coverage_calibration <- function() {
  if (exists("coverage", envir = .native_calibration_cache, inherits = FALSE)) {
    return(get("coverage", envir = .native_calibration_cache, inherits = FALSE))
  }
  seeds <- .validation_seed_manifest(
    "mcar", exploratory_replicates = 0L, final_replicates = 30L,
    master_seed = 20261200L
  )
  rows <- calibration_lapply(seq_len(nrow(seeds)), function(index) {
    item <- seeds[index, ]
    started <- proc.time()[["elapsed"]]
    tryCatch({
      simulation <- .simulate_identifiable_data(
        2L, 30L, c(12L, 10L), 1L, c(1L, 1L),
        joint_strength = 4, individual_strength = 1.5, snr = 3,
        seed = item$data_seed
      )
      mask <- .native_mask(
        simulation$noisy, simulation$truth, "mcar", item$method_seed
      )
      observed <- Map(function(x, m) {
        x[!m] <- NA_real_
        x
      }, simulation$noisy, mask)
      fit <- Rajive(
        observed, c(2L, 2L), missing = "native", mask = mask,
        joint_rank = 1L, uncertainty = "bootstrap", seed = item$method_seed,
        identifiability_norm = "l2",
        missing_control = rajive_missing_control(
          n_refits = 20L, warn_nonconvergence = FALSE
        )
      )
      uncertainty <- get_missing_uncertainty(fit)
      truth <- simulation$truth$joint_scores[, 1L]
      estimate <- fit$joint_scores[, 1L]
      if (sum(truth * estimate) < 0) truth <- -truth
      standard_error <- uncertainty$score_summary$sd
      covered <- abs(truth - estimate) <= 1.96 * standard_error
      data.frame(
        scenario_id = "mcar",
        replicate_id = item$replicate_id,
        data_seed = item$data_seed,
        method_seed = item$method_seed,
        status = "PASS",
        coverage = mean(covered),
        mean_interval_width = mean(2 * 1.96 * standard_error),
        projector_error = .native_projector_error(
          fit, simulation$truth$joint_projector
        ),
        converged = isTRUE(fit$missing$convergence$converged),
        runtime_seconds = proc.time()[["elapsed"]] - started,
        error = NA_character_,
        stringsAsFactors = FALSE
      )
    }, error = function(error) {
      data.frame(
        scenario_id = "mcar",
        replicate_id = item$replicate_id,
        data_seed = item$data_seed,
        method_seed = item$method_seed,
        status = "ERROR",
        coverage = NA_real_,
        mean_interval_width = NA_real_,
        projector_error = NA_real_,
        converged = NA,
        runtime_seconds = proc.time()[["elapsed"]] - started,
        error = conditionMessage(error),
        stringsAsFactors = FALSE
      )
    })
  })
  rows <- do.call(rbind, rows)
  write_calibration_evidence(rows, "native-coverage.tsv")
  assign("coverage", rows, envir = .native_calibration_cache)
  rows
}

test_that("native promoted outer loop converges across declared scenarios", {
  skip_if_not_slow()
  rows <- .run_native_recovery_calibration()
  expect_true(all(rows$status == "PASS"), info = paste(rows$error, collapse = "; "))
  expect_gte(mean(rows$promoted_converged), 0.90)
  scenario_rates <- tapply(rows$promoted_converged, rows$scenario_id, mean)
  expect_true(all(scenario_rates >= 0.80), info = paste(scenario_rates, collapse = ", "))
})

test_that("native recovery is noninferior to legacy and mean imputation", {
  skip_if_not_slow()
  rows <- .run_native_recovery_calibration()
  expect_true(all(rows$status == "PASS"), info = paste(rows$error, collapse = "; "))
  expect_lte(
    mean(rows$promoted_projector_error - rows$legacy_projector_error), 0.02
  )
  expect_lte(
    mean(rows$promoted_projector_error - rows$mean_imputation_projector_error),
    0.02
  )
})

test_that("native bootstrap score intervals attain declared MCAR coverage", {
  skip_if_not_slow()
  rows <- .run_native_coverage_calibration()
  expect_true(all(rows$status == "PASS"), info = paste(rows$error, collapse = "; "))
  expect_gte(mean(rows$coverage), 0.85)
  expect_true(all(is.finite(rows$mean_interval_width)))
  expect_true(all(rows$mean_interval_width > 0))
})
