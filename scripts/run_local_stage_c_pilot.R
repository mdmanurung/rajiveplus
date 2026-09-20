#!/usr/bin/env Rscript

devtools::load_all(".", quiet = TRUE)

manifest <- .validation_seed_manifest(
  c("clean-primary", "contamination-primary"),
  exploratory_replicates = 3L,
  final_replicates = 0L,
  master_seed = 20260919L
)

rows <- lapply(seq_len(nrow(manifest)), function(index) {
  seeds <- manifest[index, ]
  started <- proc.time()[["elapsed"]]
  result <- tryCatch({
    simulation <- .simulate_identifiable_data(
      K = 3L, n = 60L, pks = c(30L, 25L, 20L), rank_joint = 2L,
      rank_individual = c(3L, 2L, 2L), joint_strength = c(4, 2),
      individual_strength = 1.5, snr = 3,
      seed = seeds$data_seed
    )
    blocks <- simulation$noisy
    if (seeds$scenario_id == "contamination-primary") {
      blocks <- .with_validation_rng(seeds$data_seed + 500000L, {
        lapply(blocks, function(block) {
          count <- max(1L, floor(length(block) * 0.02))
          cells <- sample.int(length(block), count)
          block[cells] <- block[cells] + 8 * stats::sd(block)
          block
        })
      })
    }

    initial_ranks <- c(5L, 4L, 4L)
    block_bases <- lapply(seq_along(blocks), function(k) {
      decomposition <- svd(blocks[[k]])
      .extract_block_basis(decomposition, initial_ranks[[k]])$basis
    })
    aggregate <- .aggregate_geometric_bases(block_bases)
    candidate_scores <- aggregate$basis[, 1:2, drop = FALSE]
    truth_projector <- simulation$truth$joint_projector
    candidate_error <- norm(
      .projector(candidate_scores) - truth_projector, "F"
    ) / sqrt(4)

    baseline <- .with_validation_rng(seeds$method_seed, {
      Rajive(
        blocks, initial_ranks, joint_rank = 2L,
        n_wedin_samples = NA, n_rand_dir_samples = NA,
        n_perm_samples = NA, num_cores = 1L
      )
    })
    baseline_error <- norm(
      .projector(baseline$joint_scores) - truth_projector, "F"
    ) / sqrt(4)
    data.frame(
      scenario_id = seeds$scenario_id,
      replicate_id = seeds$replicate_id,
      data_seed = seeds$data_seed,
      method_seed = seeds$method_seed,
      status = "PASS",
      baseline_projector_error = baseline_error,
      candidate_projector_error = candidate_error,
      paired_degradation = candidate_error - baseline_error,
      candidate_exact_rank = NA,
      elapsed_seconds = proc.time()[["elapsed"]] - started,
      error = "",
      stringsAsFactors = FALSE
    )
  }, error = function(error) {
    data.frame(
      scenario_id = seeds$scenario_id,
      replicate_id = seeds$replicate_id,
      data_seed = seeds$data_seed,
      method_seed = seeds$method_seed,
      status = "ERROR",
      baseline_projector_error = NA,
      candidate_projector_error = NA,
      paired_degradation = NA,
      candidate_exact_rank = NA,
      elapsed_seconds = proc.time()[["elapsed"]] - started,
      error = conditionMessage(error),
      stringsAsFactors = FALSE
    )
  })
  result
})

output <- do.call(rbind, rows)
write.table(
  output,
  "docs/_codexdocs/execution/2026-09-19/stage_c_local_pilot.tsv",
  sep = "\t", quote = TRUE, row.names = FALSE, na = "NA"
)
