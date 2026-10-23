.abort_invalid_simulation <- function(message, reason, field = NULL,
                                      .envir = parent.frame()) {
  cli::cli_abort(
    message,
    class = "rajiveplus_invalid_simulation",
    reason = reason,
    field = field,
    .envir = .envir
  )
}

.orthonormal_columns <- function(x, rank) {
  if (rank == 0L) {
    return(matrix(numeric(), nrow(x), 0L))
  }
  qr.Q(qr(x), complete = FALSE)[, seq_len(rank), drop = FALSE]
}

.centered_random_basis <- function(n, rank) {
  if (rank == 0L) {
    return(matrix(numeric(), n, 0L))
  }
  z <- matrix(stats::rnorm(n * rank), n, rank)
  z <- sweep(z, 2L, colMeans(z), "-")
  .orthonormal_columns(z, rank)
}

.projector <- function(x) {
  if (ncol(x) == 0L) {
    return(matrix(0, nrow(x), nrow(x)))
  }
  q <- .orthonormal_columns(x, ncol(x))
  tcrossprod(q)
}

.subspace_intersection <- function(spaces, tolerance = 1e-10) {
  if (!length(spaces)) {
    return(matrix(numeric(), 0L, 0L))
  }
  current <- .orthonormal_columns(spaces[[1L]], ncol(spaces[[1L]]))
  if (length(spaces) == 1L) {
    return(current)
  }
  for (space in spaces[-1L]) {
    other <- .orthonormal_columns(space, ncol(space))
    if (!ncol(current) || !ncol(other)) {
      return(matrix(numeric(), nrow(current), 0L))
    }
    alignment <- svd(crossprod(current, other), nu = ncol(current), nv = 0L)
    keep <- which(alignment$d >= 1 - tolerance)
    if (!length(keep)) {
      return(matrix(numeric(), nrow(current), 0L))
    }
    current <- current %*% alignment$u[, keep, drop = FALSE]
  }
  current
}

.subspace_intersection_rank <- function(spaces, tolerance = 1e-10) {
  ncol(.subspace_intersection(spaces, tolerance))
}

.coerce_strengths <- function(value, ranks, name) {
  if (is.list(value)) {
    if (length(value) != length(ranks)) {
      .abort_invalid_simulation(
        sprintf("`%s` must have one entry per block.", name),
        "length_mismatch", name
      )
    }
    out <- value
  } else if (length(value) == 1L) {
    out <- lapply(ranks, function(rank) rep(value, rank))
  } else {
    .abort_invalid_simulation(
      sprintf("`%s` must be scalar or a list with one entry per block.", name),
      "invalid_strengths", name
    )
  }
  valid <- vapply(seq_along(out), function(k) {
    length(out[[k]]) == ranks[[k]] && all(is.finite(out[[k]])) &&
      all(out[[k]] > 0)
  }, logical(1L))
  if (!all(valid)) {
    .abort_invalid_simulation(
      sprintf("`%s` entries must be positive and match the requested ranks.", name),
      "invalid_strengths", name
    )
  }
  lapply(out, as.numeric)
}

.with_validation_rng <- function(seed, expr, rng_version = "4.5.1") {
  expr <- substitute(expr)
  seed_exists <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (seed_exists) {
    old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  }
  old_kind <- RNGkind()
  on.exit({
    do.call(RNGkind, as.list(old_kind))
    if (seed_exists) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)
  RNGversion(rng_version)
  RNGkind("L'Ecuyer-CMRG", "Inversion", "Rejection")
  set.seed(as.integer(seed))
  eval(expr, envir = parent.frame())
}

.simulate_identifiable_data <- function(
    K, n, pks, rank_joint, rank_individual,
    joint_strength = 2, individual_strength = 1,
    subset_overlap = list(), snr = Inf, seed = 1L) {
  counts <- c(K, n, pks, rank_joint, rank_individual, seed)
  if (!is.numeric(counts) || anyNA(counts) || any(!is.finite(counts)) ||
      any(counts != floor(counts))) {
    .abort_invalid_simulation(
      "Simulation dimensions and seed must be integer valued.",
      "not_integer", "dimensions"
    )
  }
  K <- as.integer(K)
  n <- as.integer(n)
  pks <- as.integer(pks)
  rank_joint <- as.integer(rank_joint)
  rank_individual <- as.integer(rank_individual)
  if (K < 2L || length(pks) != K || length(rank_individual) != K ||
      rank_joint < 0L || any(rank_individual < 0L) ||
      any(rank_joint + rank_individual > n - 1L) ||
      any(pks < rank_joint + rank_individual)) {
    .abort_invalid_simulation(
      "Ranks must fit the centered sample space and each feature space.",
      "impossible_dimensions", "ranks"
    )
  }
  if (length(joint_strength) == 1L) {
    joint_strength <- rep(joint_strength, rank_joint)
  }
  if (length(joint_strength) != rank_joint || any(!is.finite(joint_strength)) ||
      any(joint_strength <= 0)) {
    .abort_invalid_simulation(
      "`joint_strength` must be positive and match `rank_joint`.",
      "invalid_strengths", "joint_strength"
    )
  }
  individual_strength <- .coerce_strengths(
    individual_strength, rank_individual, "individual_strength"
  )
  if (length(snr) == 1L) snr <- rep(snr, K)
  if (length(snr) != K || anyNA(snr) || any(snr <= 0)) {
    .abort_invalid_simulation(
      "`snr` must contain one positive value per block.",
      "invalid_snr", "snr"
    )
  }

  subset_ranks <- integer(K)
  normalized_subsets <- lapply(seq_along(subset_overlap), function(index) {
    item <- subset_overlap[[index]]
    if (!is.list(item) || !all(c("blocks", "rank") %in% names(item)) ||
        length(item$rank) != 1L || item$rank != floor(item$rank) ||
        item$rank < 1L) {
      .abort_invalid_simulation(
        "Each subset overlap needs integer `blocks` and positive integer `rank`.",
        "invalid_subset_overlap", "subset_overlap"
      )
    }
    blocks <- sort(unique(as.integer(item$blocks)))
    if (length(blocks) < 2L || length(blocks) >= K ||
        any(blocks < 1L | blocks > K)) {
      .abort_invalid_simulation(
        "Subset overlap must involve at least two but not all blocks.",
        "all_block_individual_intersection", "subset_overlap"
      )
    }
    rank <- as.integer(item$rank)
    subset_ranks[blocks] <<- subset_ranks[blocks] + rank
    list(id = sprintf("subset%02d", index), blocks = blocks, rank = rank)
  })
  if (any(subset_ranks > rank_individual)) {
    .abort_invalid_simulation(
      "Requested subset overlap exceeds an Individual rank.",
      "subset_rank_exceeds_individual", "subset_overlap"
    )
  }
  unique_ranks <- rank_individual - subset_ranks
  total_score_rank <- rank_joint + sum(vapply(
    normalized_subsets, `[[`, integer(1L), "rank"
  )) + sum(unique_ranks)
  if (total_score_rank > n - 1L) {
    .abort_invalid_simulation(
      "This exact-overlap construction needs more centered directions than available.",
      "insufficient_centered_space", "n"
    )
  }

  .with_validation_rng(seed, {
    score_pool <- .centered_random_basis(n, total_score_rank)
    cursor <- 0L
    take <- function(rank) {
      if (!rank) return(matrix(numeric(), n, 0L))
      idx <- cursor + seq_len(rank)
      cursor <<- cursor + rank
      score_pool[, idx, drop = FALSE]
    }
    joint_scores <- take(rank_joint)
    subset_scores <- lapply(normalized_subsets, function(item) take(item$rank))
    individual_scores <- lapply(seq_len(K), function(k) {
      pieces <- lapply(which(vapply(normalized_subsets, function(item) {
        k %in% item$blocks
      }, logical(1L))), function(index) subset_scores[[index]])
      pieces[[length(pieces) + 1L]] <- take(unique_ranks[[k]])
      do.call(cbind, pieces)
    })

    joint <- individual <- clean <- noisy <- noise <- vector("list", K)
    joint_loadings <- individual_loadings <- vector("list", K)
    for (k in seq_len(K)) {
      loadings <- .orthonormal_columns(
        matrix(stats::rnorm(pks[[k]] * (rank_joint + rank_individual[[k]])),
               pks[[k]], rank_joint + rank_individual[[k]]),
        rank_joint + rank_individual[[k]]
      )
      joint_loadings[[k]] <- loadings[, seq_len(rank_joint), drop = FALSE]
      ind_idx <- rank_joint + seq_len(rank_individual[[k]])
      individual_loadings[[k]] <- loadings[, ind_idx, drop = FALSE]
      joint[[k]] <- joint_scores %*% diag(joint_strength,
                                          rank_joint, rank_joint) %*%
        t(joint_loadings[[k]])
      individual[[k]] <- individual_scores[[k]] %*%
        diag(individual_strength[[k]], rank_individual[[k]],
             rank_individual[[k]]) %*% t(individual_loadings[[k]])
      clean[[k]] <- joint[[k]] + individual[[k]]
      raw_noise <- matrix(stats::rnorm(n * pks[[k]]), n, pks[[k]])
      raw_noise <- sweep(raw_noise, 2L, colMeans(raw_noise), "-")
      if (is.infinite(snr[[k]])) {
        noise[[k]] <- matrix(0, n, pks[[k]])
      } else {
        noise[[k]] <- raw_noise *
          (norm(clean[[k]], "F") / (snr[[k]] * norm(raw_noise, "F")))
      }
      noisy[[k]] <- clean[[k]] + noise[[k]]
      rownames(noisy[[k]]) <- rownames(clean[[k]]) <-
        rownames(joint[[k]]) <- rownames(individual[[k]]) <-
        rownames(noise[[k]]) <- paste0("sample", seq_len(n))
      colnames(noisy[[k]]) <- colnames(clean[[k]]) <-
        colnames(joint[[k]]) <- colnames(individual[[k]]) <-
        colnames(noise[[k]]) <- paste0("feature", seq_len(pks[[k]]))
    }
    block_names <- paste0("block", seq_len(K))
    for (object_name in c("joint", "individual", "clean", "noisy", "noise",
                          "joint_loadings", "individual_loadings",
                          "individual_scores")) {
      object <- get(object_name)
      names(object) <- block_names
      assign(object_name, object)
    }
    structure(list(
      clean = clean,
      noisy = noisy,
      noise = noise,
      truth = list(
        joint = joint,
        individual = individual,
        joint_scores = joint_scores,
        individual_scores = individual_scores,
        joint_loadings = joint_loadings,
        individual_loadings = individual_loadings,
        joint_projector = .projector(joint_scores),
        individual_projectors = lapply(individual_scores, .projector),
        rank_joint = rank_joint,
        rank_individual = rank_individual,
        subset_overlap = normalized_subsets,
        snr = snr
      ),
      metadata = list(
        generator = "rajiveplus_identifiable_v1",
        rng_kind = c("L'Ecuyer-CMRG", "Inversion", "Rejection"),
        rng_version = "4.5.1",
        seed = seed
      )
    ), class = "rajiveplus_validation_simulation")
  })
}

.validate_identifiable_simulation <- function(simulation, tolerance = 1e-10) {
  truth <- simulation$truth
  joint_scores <- truth$joint_scores
  if (max(abs(colSums(joint_scores)), 0) > tolerance ||
      max(abs(crossprod(joint_scores) - diag(ncol(joint_scores))), 0) > tolerance) {
    .abort_invalid_simulation(
      "Joint scores are not centered and orthonormal.",
      "invalid_joint_scores", "joint_scores"
    )
  }
  for (k in seq_along(simulation$clean)) {
    individual_scores <- truth$individual_scores[[k]]
    errors <- c(
      max(abs(colSums(individual_scores)), 0),
      max(abs(crossprod(joint_scores, individual_scores)), 0),
      norm(simulation$clean[[k]] - truth$joint[[k]] - truth$individual[[k]], "F"),
      norm(simulation$noisy[[k]] - simulation$clean[[k]] - simulation$noise[[k]], "F"),
      norm(.projector(individual_scores) - truth$individual_projectors[[k]], "F")
    )
    if (any(errors > tolerance)) {
      .abort_invalid_simulation(
        "A generated block violates centered, orthogonal, reconstruction, or projector invariants.",
        "invariant_failure", sprintf("block%d", k)
      )
    }
  }
  if (.subspace_intersection_rank(truth$individual_scores, tolerance) != 0L) {
    .abort_invalid_simulation(
      "Individual score spaces have a nonzero all-block intersection.",
      "all_block_individual_intersection", "individual_scores"
    )
  }
  invisible(TRUE)
}

.legacy_simulation_fixture_status <- function() "misspecification_fixture"

.validation_seed_manifest <- function(
    scenarios, exploratory_replicates, final_replicates, master_seed,
    rng_version = "4.5.1") {
  if (!is.character(scenarios) || !length(scenarios) || anyNA(scenarios) ||
      any(!nzchar(scenarios)) || anyDuplicated(scenarios)) {
    stop("`scenarios` must be unique nonempty IDs.", call. = FALSE)
  }
  counts <- c(exploratory_replicates, final_replicates, master_seed)
  if (!is.numeric(counts) || anyNA(counts) || any(counts != floor(counts)) ||
      any(counts < 0)) {
    stop("Replicate counts and master seed must be nonnegative integers.", call. = FALSE)
  }
  rows <- list()
  cursor <- 0L
  for (seed_set in c("exploratory", "final")) {
    n_rep <- if (seed_set == "exploratory") exploratory_replicates else final_replicates
    for (scenario in scenarios) {
      for (replicate in seq_len(n_rep)) {
        cursor <- cursor + 1L
        rows[[cursor]] <- data.frame(
          scenario_id = scenario,
          replicate_id = sprintf("%s-%s-%03d", scenario, seed_set, replicate),
          seed_set = seed_set,
          data_seed = as.integer(master_seed + cursor),
          method_seed = as.integer(master_seed + 1000000L + cursor),
          rng_kind = "L'Ecuyer-CMRG/Inversion/Rejection",
          rng_version = rng_version,
          stringsAsFactors = FALSE
        )
      }
    }
  }
  do.call(rbind, rows)
}

.new_validation_replicate <- function(
    scenario_id, replicate_id, seed_set, data_seed, method_seed,
    method_profile_id, method_profile_hash, status, metrics) {
  valid_status <- c("PASS", "FAIL", "ERROR", "INCONCLUSIVE", "BLOCKED")
  scalar_text <- function(x) {
    is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
  }
  if (!all(vapply(list(scenario_id, replicate_id, seed_set,
                       method_profile_id, method_profile_hash),
                  scalar_text, logical(1L))) ||
      !status %in% valid_status || !is.list(metrics)) {
    cli::cli_abort(
      "Invalid validation replicate record.",
      class = "rajiveplus_invalid_validation_record"
    )
  }
  structure(list(
    schema_version = 1L,
    scenario_id = scenario_id,
    replicate_id = replicate_id,
    seed_set = seed_set,
    data_seed = as.integer(data_seed),
    method_seed = as.integer(method_seed),
    method_profile_id = method_profile_id,
    method_profile_hash = method_profile_hash,
    status = status,
    metrics = metrics
  ), class = c("rajiveplus_validation_replicate", "list"))
}
