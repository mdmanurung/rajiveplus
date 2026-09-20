test_that("candidate identifiability filtering drops every unsupported direction", {
  joint_scores <- diag(4)[, 1:3, drop = FALSE]
  blocks <- list(
    cbind(c(1, 0, 0, 0), c(0, 0, 0, 1)),
    cbind(c(0, 1, 0, 0), c(0, 0, 0, 1))
  )
  expect_identical(
    rajiveplus:::.identifiability_rejections(
      blocks, joint_scores, c(0.5, 0.5), "l2"
    ),
    c(1L, 2L, 3L)
  )
})

test_that("Individual decomposition is exactly reprojected and refactorized", {
  set.seed(9901L)
  q <- qr.Q(qr(matrix(rnorm(30), 10, 3)))
  x <- matrix(rnorm(80), 10, 8)
  fit <- rajiveplus:::.get_individual_decomposition_exact(
    x, q, sv_threshold = 0, full = TRUE
  )
  expect_lte(norm(crossprod(q, fit$full), "F") /
               max(norm(fit$full, "F"), .Machine$double.eps), 1e-8)
  expect_equal(fit$full, rajiveplus:::svd_reconstruction(fit),
               tolerance = 1e-10)

  compact <- rajiveplus:::.get_individual_decomposition_exact(
    x, q, sv_threshold = 0, full = FALSE
  )
  expect_lte(norm(crossprod(q, rajiveplus:::svd_reconstruction(compact)), "F") /
               max(norm(rajiveplus:::svd_reconstruction(compact), "F"),
                   .Machine$double.eps), 1e-8)
})

test_that("joint coordinate contract reconstructs every block", {
  fx <- make_small_rajive_fixture(seed = 9902L)
  coords <- rajiveplus:::.joint_coordinate_contract(fx$fit)
  public <- get_joint_coordinates(fx$fit)
  expect_identical(public, coords)
  expect_identical(coords$schema_version, 1L)
  for (k in seq_along(fx$blocks)) {
    expect_equal(
      coords$score_basis %*% coords$block_coefficients[[k]],
      rajiveplus:::.get_component_matrix(fx$fit, k, "joint"),
      tolerance = 1e-10
    )
  }
})
