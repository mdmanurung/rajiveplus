# Real-fit regressions for V1/V2. Inputs are independently certified synthetic
# truth, not an application result or a calibration study.
variance_contract_fixture <- function(seed = 7161L, full = TRUE,
                                      joint_rank = 2L) {
  sim <- rajiveplus:::.simulate_identifiable_data(
    K = 3L, n = 36L, pks = c(24L, 20L, 16L),
    rank_joint = 2L, rank_individual = c(2L, 2L, 2L),
    joint_strength = c(6, 4), individual_strength = 2,
    snr = 3, seed = seed
  )
  rajiveplus:::.validate_identifiable_simulation(sim)
  blocks <- sim$noisy
  fit <- suppressMessages(Rajive(
    blocks, c(4L, 4L, 4L), joint_rank = joint_rank,
    full = full, n_wedin_samples = NA, n_rand_dir_samples = NA,
    num_cores = 1L, seed = seed
  ))
  list(blocks = blocks, fit = fit)
}

matrix_energy_reference <- function(fit, blocks) {
  out <- lapply(seq_along(blocks), function(k) {
    X <- blocks[[k]]
    J <- rajiveplus:::.get_component_matrix(fit, as.integer(k), "joint")
    I <- rajiveplus:::.get_component_matrix(fit, as.integer(k), "individual")
    E <- X - J - I
    observed <- is.finite(X)
    total <- sum(X[observed]^2)
    if (total == 0) return(c(Joint = 0, Individual = 0, Residual = 0))
    c(Joint = sum(J[observed]^2), Individual = sum(I[observed]^2),
      Residual = sum(E[observed]^2)) / total
  })
  values <- do.call(cbind, out)
  setNames(lapply(seq_len(nrow(values)), function(i) {
    as.numeric(values[i, ])
  }), rownames(values))
}

test_that("reported energies equal reconstructed actual-fit component energies", {
  fx <- variance_contract_fixture()
  before <- serialize(fx$fit, NULL)
  set.seed(874L)
  rng <- .Random.seed
  actual <- showVarExplained_robust(fx$fit, fx$blocks)
  expected <- matrix_energy_reference(fx$fit, fx$blocks)
  expect_named(actual, c("Joint", "Individual", "Residual"))
  for (name in names(actual)) {
    expect_equal(unname(actual[[name]]), unname(expected[[name]]),
                 tolerance = 1e-10)
  }
  expect_identical(serialize(fx$fit, NULL), before)
  expect_identical(.Random.seed, rng)

  feature <- joint_variance_partition(fx$fit, fx$blocks)
  for (k in seq_along(fx$blocks)) {
    rows <- feature[feature$block == names(fx$blocks)[[k]], ]
    denominator <- sum(rows$data_total_ss)
    expect_equal(actual$Joint[[k]], sum(rows$joint_ss) / denominator)
    expect_equal(actual$Individual[[k]], sum(rows$individual_ss) / denominator)
    expect_equal(actual$Residual[[k]], sum(rows$residual_ss) / denominator)
  }
  expect_lte(max(feature$matrix_reconstruction_error), 1e-10)
  expect_lte(max(feature$energy_closure_error), 1e-10)
  # This fixture must detect why "1 - Joint - Individual" is not an energy.
  expect_gt(max(abs(actual$Joint + actual$Individual + actual$Residual - 1)),
            1e-8)
})

test_that("actual-fit variance works without stored full matrices and at zero rank", {
  for (rank in c(0L, 2L)) {
    fx <- variance_contract_fixture(full = FALSE, joint_rank = rank)
    actual <- showVarExplained_robust(fx$fit, fx$blocks)
    expected <- matrix_energy_reference(fx$fit, fx$blocks)
    for (name in names(actual)) {
      expect_equal(unname(actual[[name]]), unname(expected[[name]]),
                   tolerance = 1e-10)
    }
  }
})

test_that("reported energies use exactly the observed entries", {
  fx <- variance_contract_fixture()
  fx$blocks[[1]][1L, 1L] <- NA_real_
  actual <- showVarExplained_robust(fx$fit, fx$blocks)
  expected <- matrix_energy_reference(fx$fit, fx$blocks)
  for (name in names(actual)) {
    expect_true(all(is.finite(actual[[name]])))
    expect_equal(unname(actual[[name]]), unname(expected[[name]]),
                 tolerance = 1e-10)
  }
})

test_that("nonfinite data are rejected rather than counted as missing", {
  fx <- variance_contract_fixture()
  for (invalid in c(Inf, NaN)) {
    blocks <- fx$blocks
    blocks[[1]][1L, 1L] <- invalid
    expect_error(showVarExplained_robust(fx$fit, blocks), "finite values or")
  }
})

test_that("zero data energy has an explicit finite convention", {
  # A wholly degenerate block cannot be fitted; use a supplemental valid
  # zero-rank record to exercise the reporting boundary only.
  fx <- variance_contract_fixture()
  for (k in seq_along(fx$blocks)) {
    X <- fx$blocks[[k]] * 0
    fx$blocks[[k]] <- X
    for (role in c(1L, 2L)) {
      fx$fit$block_decomps[[3L * (k - 1L) + role]] <- list(
        u = matrix(0, nrow(X), 0L), d = numeric(),
        v = matrix(0, ncol(X), 0L), full = X
      )
    }
    fx$fit$block_decomps[[3L * k]] <- X
  }
  got <- showVarExplained_robust(fx$fit, fx$blocks)
  expect_identical(got, list(Joint = rep(0, 3), Individual = rep(0, 3),
                            Residual = rep(0, 3)))
})
