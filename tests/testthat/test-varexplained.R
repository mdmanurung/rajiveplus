# Orthonormal constructed records are a special case, not the energy contract.
# Actual-fit regressions live in test-variance-single-contract.R.
test_that("variance reporting reconstructs named-field records", {
  fx <- make_extractor_fixture(keep_full = FALSE)
  for (index in c(1L, 2L, 4L, 5L)) {
    record <- fx$fit$block_decomps[[index]]
    fx$fit$block_decomps[[index]] <- record[c("u", "v", "rank", "d")]
  }
  got <- showVarExplained_robust(fx$fit, fx$blocks)
  expected_joint <- vapply(seq_along(fx$blocks), function(k) {
    sum(fx$joint[[k]]^2) / sum(fx$blocks[[k]]^2)
  }, numeric(1L))
  expected_individual <- vapply(seq_along(fx$blocks), function(k) {
    sum(fx$individual[[k]]^2) / sum(fx$blocks[[k]]^2)
  }, numeric(1L))
  expect_equal(got$Joint, expected_joint)
  expect_equal(got$Individual, expected_individual)
})

test_that("orthogonal fixture energies sum to one as a special case", {
  fx <- make_extractor_fixture()
  got <- showVarExplained_robust(fx$fit, fx$blocks)
  expected_residual <- vapply(seq_along(fx$blocks), function(k) {
    sum(fx$residual[[k]]^2) / sum(fx$blocks[[k]]^2)
  }, numeric(1L))
  expect_equal(got$Residual, expected_residual)
  expect_equal(got$Joint + got$Individual + got$Residual,
               rep(1, length(fx$blocks)), tolerance = 1e-10)
  expect_named(got, c("Joint", "Individual", "Residual"))
})
