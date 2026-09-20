.method_profile_manifest <- function() {
  list(
    `RJP-BASE` = list(
      version = 1L,
      status = "frozen_local_baseline",
      config = list(
        block_factorization = "sequential_robust_svd_cpp",
        basis_extraction_tolerance = "none_raw_robust_factors",
        aggregation_statistic = "robust_stacked_factor_squared_amplitudes",
        wedin_target = "robust_block_signal_perturbation",
        wedin_sampler = "projected_gaussian_qr_frame",
        wedin_denominator = "robust_block_amplitude_at_requested_rank",
        random_permutation_statistic = "leading_stacked_score_squared_amplitude",
        threshold_rule = "max_available_wedin_random_permutation",
        identifiability_norm = "l2",
        individual_constraint = "project_input_to_joint_complement",
        individual_refactorization = "unconstrained_robust_refit",
        robust_scale_policy = "iterationwise_mad",
        fallback_behavior = "weighted_fit_may_fallback_to_classical_svd"
      )
    ),
    `RJP-COMPAT` = list(
      version = 1L,
      status = "benchmark_only",
      config = list(
        block_factorization = "upstream_sequential_robust_svd_unpinned",
        basis_extraction_tolerance = "none_raw_robust_factors",
        aggregation_statistic = "upstream_robust_stacked_factor",
        wedin_target = "upstream_unverified",
        wedin_sampler = "upstream_column_resampling_with_replacement",
        wedin_denominator = "upstream_robust_amplitude_unverified",
        random_permutation_statistic = "upstream_unverified",
        threshold_rule = "upstream_unverified",
        identifiability_norm = "l1",
        individual_constraint = "upstream_projection_then_refit",
        individual_refactorization = "upstream_unconstrained_robust_refit",
        robust_scale_policy = "frozen_initial_mad",
        fallback_behavior = "not_executable_until_upstream_commit_is_pinned"
      )
    ),
    `RJP-GEOM-CANDIDATE` = list(
      version = 1L,
      status = "internal_candidate",
      config = list(
        block_factorization = "sequential_robust_svd_cpp",
        basis_extraction_tolerance = "dimension_scaled_machine_epsilon",
        aggregation_statistic = "eigendecomposition_sum_block_projectors",
        wedin_target = "candidate_requires_matched_reference",
        wedin_sampler = "candidate_not_promoted",
        wedin_denominator = "candidate_not_promoted",
        random_permutation_statistic = "projector_sum_leading_eigenvalue",
        threshold_rule = "candidate_not_promoted",
        identifiability_norm = "l2",
        individual_constraint = "exact_joint_complement_reprojection",
        individual_refactorization = "algebraic_svd_only",
        robust_scale_policy = "iterationwise_mad",
        fallback_behavior = "reject_candidate_on_numerical_failure"
      )
    ),
    `RJP-NATIVE-BASE` = list(
      version = 1L,
      status = "experimental_native_baseline",
      config = list(
        block_factorization = "weighted_robust_svd_with_completion",
        basis_extraction_tolerance = "none_raw_weighted_factors",
        aggregation_statistic = "robust_stacked_completed_signal_factors",
        wedin_target = "not_used_for_fixed_native_rank",
        wedin_sampler = "not_used_for_fixed_native_rank",
        wedin_denominator = "not_used_for_fixed_native_rank",
        random_permutation_statistic = "native_rank_diagnostics_when_requested",
        threshold_rule = "fixed_or_native_cross_validation",
        identifiability_norm = "l2",
        individual_constraint = "masked_residual_fit",
        individual_refactorization = "weighted_robust_fit",
        robust_scale_policy = "iterationwise_observed_mad",
        fallback_behavior = "weighted_fit_may_fallback_to_classical_svd"
      )
    )
  )
}

.method_profile_hash <- function(profile) {
  path <- tempfile("rajiveplus-method-profile-", fileext = ".txt")
  on.exit(unlink(path), add = TRUE)
  writeLines(capture.output(dput(profile)), path, useBytes = TRUE)
  paste0("md5:", unname(tools::md5sum(path)))
}

.resolve_method_profile <- function(id = "RJP-BASE",
                                    identifiability_norm = "l2") {
  manifest <- .method_profile_manifest()
  if (!is.character(id) || length(id) != 1L || is.na(id) ||
      !id %in% names(manifest)) {
    stop("Unknown internal method profile.", call. = FALSE)
  }
  profile <- manifest[[id]]
  profile$config$identifiability_norm <- identifiability_norm
  list(
    id = id,
    version = profile$version,
    status = profile$status,
    config_hash = .method_profile_hash(profile$config),
    config = profile$config
  )
}

.svd_profile_manifest <- function() {
  list(
    upstream_rajive = list(
      status = "BLOCKED",
      implementation = "https://github.com/ericaponzi/RaJIVE",
      source_pin = NA_character_,
      reason = "Referenced local clone absent and network prohibited"
    ),
    current_r_weighted = list(
      status = "EXECUTABLE",
      implementation = ".RobRSVD_all_weighted_R",
      scale_policy = "iterationwise_mad_in_inner_cpp_robust_fit",
      convergence = "weighted_completion_objective"
    ),
    optimized_cpp_complete = list(
      status = "EXECUTABLE",
      implementation = "RobRSVD_all_cpp",
      scale_policy = "iterationwise_mad",
      convergence = "inner_max_absolute_reconstruction_change"
    )
  )
}
