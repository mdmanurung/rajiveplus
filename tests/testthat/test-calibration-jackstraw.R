# Slow dataset-level calibration for fixed-score jackstraw and pooled PIPs.
#
# Each simulated dataset contains known dense joint-signal features and appended
# independent null features. The decomposition rank is fixed to the true rank,
# so this gate evaluates feature inference conditional on a correctly specified
# decomposition rather than conflating it with rank-selection performance.

.jackstraw_calibration_cache <- new.env(parent = emptyenv())

.run_jackstraw_pip_calibration <- function() {
  if (exists("rows", envir = .jackstraw_calibration_cache, inherits = FALSE)) {
    return(get("rows", envir = .jackstraw_calibration_cache, inherits = FALSE))
  }
  seeds <- .validation_seed_manifest(
    "joint_signal_with_appended_nulls",
    exploratory_replicates = 0L, final_replicates = 100L,
    master_seed = 20261300L
  )
  rows <- calibration_lapply(seq_len(nrow(seeds)), function(index) {
    item <- seeds[index, ]
    started <- proc.time()[["elapsed"]]
    tryCatch(.with_validation_rng(item$data_seed, {
      n <- 48L
      signal_features <- c(12L, 10L)
      null_features <- 24L
      simulation <- ajive.data.sim(
        K = 2L, rankJ = 1L, rankA = c(2L, 1L), n = n,
        pks = signal_features, dist.type = 1
      )
      blocks <- lapply(simulation$sim_data, function(block) {
        cbind(
          block,
          matrix(stats::rnorm(n * null_features), n, null_features)
        )
      })
      fit <- Rajive(
        blocks, c(3L, 2L), joint_rank = 1L,
        n_wedin_samples = NA, n_rand_dir_samples = NA,
        n_perm_samples = NA, num_cores = 1L
      )
      inference <- .with_validation_rng(item$method_seed, jackstraw_rajive(
        fit, blocks, n_null = 15L, correction = "BH",
        pip = TRUE, pip_group = "pooled"
      ))
      feature_rows <- do.call(rbind, lapply(seq_along(inference), function(k) {
        result <- inference[[k]][[1L]]
        data.frame(
          block = k,
          feature = seq_along(result$p_values),
          p_value = result$p_values,
          p_adjusted = result$p_adj,
          pip = result$pip,
          signal = seq_along(result$p_values) <= signal_features[[k]],
          stringsAsFactors = FALSE
        )
      }))
      discoveries <- feature_rows$p_adjusted <= 0.05
      n_signal <- sum(feature_rows$signal)
      n_null <- sum(!feature_rows$signal)
      auc <- as.numeric(stats::wilcox.test(
        feature_rows$pip[feature_rows$signal],
        feature_rows$pip[!feature_rows$signal],
        alternative = "greater", exact = FALSE
      )$statistic) / (n_signal * n_null)
      data.frame(
        scenario_id = item$scenario_id,
        replicate_id = item$replicate_id,
        data_seed = item$data_seed,
        method_seed = item$method_seed,
        status = "PASS",
        joint_rank = fit$joint_rank,
        null_raw_fpr = mean(
          feature_rows$p_value[!feature_rows$signal] <= 0.05
        ),
        false_discovery_proportion = if (any(discoveries)) {
          mean(!feature_rows$signal[discoveries])
        } else 0,
        bh_power = mean(discoveries[feature_rows$signal]),
        null_pip_90_rate = mean(
          feature_rows$pip[!feature_rows$signal] >= 0.90
        ),
        pip_power_50 = mean(
          feature_rows$pip[feature_rows$signal] >= 0.50
        ),
        pip_auc = auc,
        pip_pi0_fallback_count = attr(inference, "pip_pi0_fallback_count"),
        pip_nonfinite_lfdr_count = attr(
          inference, "pip_nonfinite_lfdr_count"
        ),
        runtime_seconds = proc.time()[["elapsed"]] - started,
        error = NA_character_,
        stringsAsFactors = FALSE
      )
    }), error = function(error) {
      data.frame(
        scenario_id = item$scenario_id,
        replicate_id = item$replicate_id,
        data_seed = item$data_seed,
        method_seed = item$method_seed,
        status = "ERROR",
        joint_rank = NA_integer_,
        null_raw_fpr = NA_real_,
        false_discovery_proportion = NA_real_,
        bh_power = NA_real_,
        null_pip_90_rate = NA_real_,
        pip_power_50 = NA_real_,
        pip_auc = NA_real_,
        pip_pi0_fallback_count = NA_integer_,
        pip_nonfinite_lfdr_count = NA_integer_,
        runtime_seconds = proc.time()[["elapsed"]] - started,
        error = conditionMessage(error),
        stringsAsFactors = FALSE
      )
    })
  })
  rows <- do.call(rbind, rows)
  write_calibration_evidence(rows, "jackstraw-pip.tsv")
  assign("rows", rows, envir = .jackstraw_calibration_cache)
  rows
}

test_that("jackstraw controls dataset-level null discovery and FDR", {
  skip_if_not_slow()
  rows <- .run_jackstraw_pip_calibration()
  expect_true(all(rows$status == "PASS"), info = paste(rows$error, collapse = "; "))
  expect_true(all(rows$joint_rank == 1L))
  expect_lte(mean(rows$null_raw_fpr), 0.10)
  expect_lte(mean(rows$false_discovery_proportion), 0.10)
})

test_that("jackstraw retains dataset-level power for declared signal", {
  skip_if_not_slow()
  rows <- .run_jackstraw_pip_calibration()
  expect_gte(mean(rows$bh_power), 0.40)
})

test_that("pooled PIPs separate signal and control high null probabilities", {
  skip_if_not_slow()
  skip_if_not_installed("qvalue")
  rows <- .run_jackstraw_pip_calibration()
  expect_lte(mean(rows$null_pip_90_rate), 0.05)
  expect_gte(mean(rows$pip_power_50), 0.50)
  expect_gte(stats::median(rows$pip_auc), 0.75)
  expect_lte(mean(rows$pip_pi0_fallback_count > 0L), 0.20)
  expect_identical(sum(rows$pip_nonfinite_lfdr_count), 0L)
})
