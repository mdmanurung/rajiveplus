# Independent of the generator's QR construction: ranks and spaces below are
# recomputed from the realized component matrices using SVD.
.certify_simulated_truth <- function(simulation, geometry_tolerance = 1e-10) {
  fail <- function(message, reason, field = "truth") {
    .abort_invalid_simulation(message, reason, field)
  }
  if (!is.numeric(geometry_tolerance) || length(geometry_tolerance) != 1L ||
      !is.finite(geometry_tolerance) || geometry_tolerance <= 0) {
    fail("Geometry tolerance must be a positive finite scalar.", "invalid_tolerance")
  }
  if (!is.list(simulation) || !is.list(simulation$truth)) {
    fail("A simulation and its declared truth are required.", "missing_truth")
  }
  truth <- simulation$truth
  blocks <- if (!is.null(simulation$blocks)) simulation$blocks else simulation$noisy
  residual <- if (!is.null(truth$residual)) truth$residual else simulation$noise
  joint <- truth$joint
  individual <- truth$individual
  rj <- if (!is.null(truth$joint_rank)) truth$joint_rank else truth$rank_joint
  ri <- if (!is.null(truth$individual_ranks)) truth$individual_ranks else
    truth$rank_individual
  K <- length(blocks)
  if (!is.list(blocks) || K < 1L ||
      any(!vapply(blocks, is.matrix, logical(1L)))) {
    fail("Blocks must be a nonempty list of matrices.", "invalid_blocks")
  }
  n <- nrow(blocks[[1L]])
  if (n < 1L || any(vapply(blocks, nrow, integer(1L)) != n)) {
    fail("Blocks must have the same positive sample dimension.", "dimension_mismatch")
  }
  ranks <- c(rj, ri)
  if (!is.numeric(ranks) || length(rj) != 1L || length(ri) != K ||
      any(!is.finite(ranks)) || any(ranks < 0 | ranks != floor(ranks))) {
    fail("Requested ranks must be nonnegative integers matching the blocks.",
         "invalid_ranks")
  }
  rj <- as.integer(rj)
  ri <- as.integer(ri)
  components <- list(joint = joint, individual = individual, residual = residual)
  for (role in names(components)) {
    values <- components[[role]]
    if (!is.list(values) || length(values) != K ||
        any(!vapply(values, is.matrix, logical(1L)))) {
      fail("Component lists must align with the blocks.", "dimension_mismatch", role)
    }
    if (!is.null(names(blocks)) && !is.null(names(values)) &&
        !identical(names(values), names(blocks))) {
      fail("Named components must use the same block order.", "block_order_mismatch", role)
    }
  }
  for (field in c("individual_bases", "individual_scores")) {
    value <- truth[[field]]
    if (!is.null(value) && (!is.list(value) || length(value) != K)) {
      fail("Stored Individual metadata must align with the blocks.",
           "invalid_score_metadata", field)
    }
  }
  matrix_basis <- function(x) {
    if (!ncol(x)) {
      return(list(q = matrix(numeric(), nrow(x), 0L),
                  rank = 0L, rank_tolerance = 0))
    }
    decomp <- svd(x, nu = min(dim(x)), nv = 0L)
    scale <- max(decomp$d, 0)
    tolerance <- max(dim(x)) * .Machine$double.eps * scale
    rank <- as.integer(sum(decomp$d > tolerance))
    list(q = decomp$u[, seq_len(rank), drop = FALSE],
         rank = rank, rank_tolerance = tolerance)
  }
  span_error <- function(a, b) {
    # Equivalent projector distance from two-sided residuals, without an n^2
    # projector or cancellation in rank_a + rank_b - 2*||A'B||^2.
    ab <- a - b %*% crossprod(b, a)
    ba <- b - a %*% crossprod(a, b)
    sqrt(sum(ab^2) + sum(ba^2)) / max(1, sqrt(ncol(a) + ncol(b)))
  }
  check_metadata <- function(value, expected, name, orthonormal = FALSE) {
    if (is.null(value)) return(0)
    if (!is.matrix(value) || !is.numeric(value) ||
        any(!is.finite(value)) || nrow(value) != n ||
        ncol(value) != ncol(expected)) {
      fail("Stored score/basis metadata have invalid dimensions or values.",
           "invalid_score_metadata", name)
    }
    actual <- matrix_basis(value)
    error <- span_error(actual$q, expected)
    if (actual$rank != ncol(expected) || error > geometry_tolerance) {
      fail("Stored score/basis metadata disagree with realized matrix spaces.",
           "score_span_mismatch", name)
    }
    if (orthonormal &&
        max(abs(crossprod(value) - diag(ncol(value))), 0) > geometry_tolerance) {
      fail("Stored basis metadata are not orthonormal.", "basis_gram_failure", name)
    }
    error
  }
  # The intersection is contained in the smallest realized SVD-derived space
  # Q0. Its dimension is nullity(stack_k((I - P_k) Q0)); this avoids n^2
  # projectors. Neither stored QR columns nor the generator's helper is used.
  intersection <- function(bases) {
    dimensions <- vapply(bases, ncol, integer(1L))
    if (!min(dimensions)) {
      return(list(rank = 0L, tolerance = geometry_tolerance,
                  singular_values = numeric()))
    }
    anchor <- bases[[which.min(dimensions)]]
    constraints <- do.call(rbind, lapply(bases, function(q) {
      anchor - q %*% crossprod(q, anchor)
    }))
    singular <- svd(constraints, nu = 0L, nv = 0L)$d
    tolerance <- geometry_tolerance * max(1, max(singular, 0))
    list(rank = as.integer(sum(singular <= tolerance)),
         tolerance = tolerance, singular_values = singular)
  }
  jb <- ib <- sb <- vector("list", K)
  rows <- lapply(seq_len(K), function(k) {
    X <- blocks[[k]]
    J <- joint[[k]]
    I <- individual[[k]]
    E <- residual[[k]]
    matrices <- list(X, J, I, E)
    if (ncol(X) < 1L || any(!vapply(matrices, function(x) {
      is.numeric(x) && identical(dim(x), dim(X)) && all(is.finite(x))
    }, logical(1L)))) {
      fail("Component matrices must be finite and match their block dimensions.",
           "invalid_component_matrix", paste0("block", k))
    }
    j <- matrix_basis(J)
    i <- matrix_basis(I)
    s <- matrix_basis(J + I)
    if (j$rank != rj || i$rank != ri[[k]] || s$rank != rj + ri[[k]]) {
      fail("Realized component/noiseless ranks do not match the requested truth.",
           "achieved_rank_mismatch", paste0("block", k))
    }
    jb[[k]] <<- j$q
    ib[[k]] <<- i$q
    sb[[k]] <<- s$q
    cross <- max(abs(crossprod(j$q, i$q)), 0)
    closure <- norm(X - J - I - E, "F") /
      max(norm(X, "F"), norm(J, "F") + norm(I, "F") + norm(E, "F"),
          .Machine$double.eps)
    if (cross > geometry_tolerance || closure > geometry_tolerance) {
      fail("Realized truth violates orthogonality or reconstruction.",
           "matrix_invariant_failure", paste0("block", k))
    }
    jmeta <- max(
      check_metadata(truth$joint_basis, j$q, "joint_basis", TRUE),
      check_metadata(truth$joint_scores, j$q, "joint_scores")
    )
    ibasis <- if (is.null(truth$individual_bases)) NULL else truth$individual_bases[[k]]
    iscores <- if (is.null(truth$individual_scores)) NULL else truth$individual_scores[[k]]
    imeta <- max(check_metadata(ibasis, i$q, "individual_bases", TRUE),
                 check_metadata(iscores, i$q, "individual_scores"))
    data.frame(
      block = if (is.null(names(blocks))) paste0("block", k) else names(blocks)[[k]],
      features = ncol(X), joint_rank = j$rank, individual_rank = i$rank,
      signal_rank = s$rank, joint_rank_tolerance = j$rank_tolerance,
      individual_rank_tolerance = i$rank_tolerance,
      signal_rank_tolerance = s$rank_tolerance,
      joint_individual_cross_max = cross, reconstruction_relative = closure,
      joint_metadata_span_error = jmeta, individual_metadata_span_error = imeta,
      stringsAsFactors = FALSE
    )
  })
  if (any(vapply(jb, function(q) span_error(q, jb[[1L]]),
                 numeric(1L)) > geometry_tolerance)) {
    fail("Realized Joint spaces are not shared across every block.",
         "joint_span_mismatch")
  }
  ii <- intersection(ib)
  si <- intersection(sb)
  if (ii$rank != 0L || si$rank != rj) {
    fail("Truth contains an additional all-block shared Individual direction.",
         "all_block_individual_intersection")
  }
  list(
    schema_version = 1L, status = "PASS", sample_count = n, block_count = K,
    declared_joint_rank = rj, declared_individual_ranks = ri,
    geometry_tolerance = geometry_tolerance,
    rank_tolerance_policy = "max(matrix dimensions) * machine epsilon * largest singular value",
    intersection_method = "SVD nullity of complement constraints applied to smallest realized space",
    individual_intersection_rank = ii$rank, signal_intersection_rank = si$rank,
    individual_intersection = ii, signal_intersection = si,
    blocks = do.call(rbind, rows)
  )
}
