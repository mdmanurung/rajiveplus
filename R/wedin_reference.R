.wedin_reference_from_draws <- function(X, signal_basis, right_vectors,
                                        draws) {
  signal_basis <- qr.Q(qr(signal_basis), complete = FALSE)[,
    seq_len(ncol(signal_basis)), drop = FALSE
  ]
  if (!length(draws) || ncol(signal_basis) == nrow(signal_basis)) {
    return(rep(0, dim(draws)[[3L]]))
  }
  vapply(seq_len(dim(draws)[[3L]]), function(index) {
    raw <- draws[, , index, drop = FALSE][, , 1L]
    projected <- raw - signal_basis %*% crossprod(signal_basis, raw)
    frame <- qr.Q(qr(projected), complete = FALSE)[,
      seq_len(ncol(raw)), drop = FALSE
    ]
    projected_data <- if (right_vectors) X %*% frame else crossprod(frame, X)
    values <- svd(projected_data, nu = 0L, nv = 0L)$d
    if (length(values)) values[[1L]] else 0
  }, numeric(1L))
}

.wedin_target_contract <- function(X, signal_basis, right_vectors) {
  ambient_dimension <- nrow(signal_basis)
  signal_rank <- ncol(signal_basis)
  complement_rank <- ambient_dimension - signal_rank
  list(
    schema_version = 1L,
    target = if (right_vectors) "operator_norm_X_times_complement_frame" else
      "operator_norm_transpose_complement_frame_times_X",
    denominator = "signal_singular_value_at_requested_rank",
    matrix_dimensions = dim(X),
    ambient_dimension = ambient_dimension,
    signal_rank = signal_rank,
    complement_rank = complement_rank,
    sampled_frame_rank = min(signal_rank, complement_rank),
    saturated_behavior = "zero_perturbation_with_boundary_attribute"
  )
}

.wedin_bound_resampling_candidate <- function(
    X, signal_basis, right_vectors, num_samples = 1000L) {
  signal_basis <- qr.Q(qr(signal_basis), complete = FALSE)[,
    seq_len(ncol(signal_basis)), drop = FALSE
  ]
  rank <- ncol(signal_basis)
  complement_rank <- nrow(signal_basis) - rank
  if (rank == 0L) return(rep(0, num_samples))
  if (complement_rank == 0L) {
    out <- rep(0, num_samples)
    attr(out, "boundary") <- "saturated_signal_space"
    return(out)
  }
  draw_rank <- min(rank, complement_rank)
  draws <- array(
    stats::rnorm(nrow(signal_basis) * draw_rank * num_samples),
    c(nrow(signal_basis), draw_rank, num_samples)
  )
  as.numeric(wedin_bound_resampling_cpp_draws(
    X, signal_basis, right_vectors, draws
  ))
}
