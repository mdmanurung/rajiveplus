# Independently authored deterministic checks; no fitting, RNG, or package loading.
args <- commandArgs(trailingOnly = TRUE)
package_root <- if (length(args)) args[[1L]] else "."
near <- function(x, y, tol = 1e-12) stopifnot(max(abs(x - y)) < tol)
op <- function(x) if (!length(x)) 0 else svd(x, nu = 0, nv = 0)$d[1]
records <- list()
record <- function(id, result) {
  records[[id]] <<- result
  cat(id, ": ", paste(capture.output(dput(result)), collapse = " "), "\n", sep = "")
}

# C1: side-specific Wedin error, showing that replacing max by min is invalid.
# A = e1 e1', X = (e1 + t e2)e1'; sample directions are LEFT singular vectors.
t <- 1/2
A <- matrix(c(1, 0, 0, 0), 2, 2)
X <- matrix(c(1, t, 0, 0), 2, 2)
E <- X - A
uhat <- matrix(c(1, t) / sqrt(1 + t^2), 2, 1)
vhat <- matrix(c(1, 0), 2, 1)
sigma <- sqrt(1 + t^2)
actual <- t / sigma
a <- op(E %*% vhat)
b <- op(t(E) %*% uhat)
near(actual, 1 / sqrt(5))
near(max(a, b) / sigma, actual)
stopifnot(min(a, b) / sigma < actual)
record("C1_side_norms", c(actual_sin = actual, EV = a, EtU = b,
                         max_ratio = max(a, b)/sigma,
                         invalid_min_ratio = min(a, b)/sigma))

# C2: capped squared ratios and zero/nonfinite denominator boundaries.
f <- function(a, b, d) min(max(a, b) / d, 1)^2
near(f(3, 4, 10), .16)
near(f(12, 4, 10), 1)
stopifnot(is.nan(f(0, 0, 0)), identical(f(1, 0, 0), 1),
          identical(f(1, 0, Inf), 0), is.na(f(1, 0, NA_real_)))
stopifnot(f(3, 0, -2) > 1)
record("C2_ratio", c(regular = f(3,4,10), capped = f(12,4,10),
                     zero_positive = f(1,0,0), zero_zero = f(0,0,0),
                     infinite = f(1,0,Inf), negative = f(3,0,-2)))

# C3: quantile of paired K - sum(draws) is not K - sum(block low quantiles).
B <- rbind(c(0,0,1,1), c(1,1,0,0))
paired <- 2 - colSums(B)
paired_threshold <- unname(quantile(paired, .05))
baseline_threshold <- 2 - sum(apply(B, 1, quantile, probs = .05))
upper_block_threshold <- 2 - sum(apply(B, 1, quantile, probs = .95))
near(paired_threshold, 1)
near(baseline_threshold, 2)
near(upper_block_threshold, 0)
near(paired_threshold, 2 - unname(quantile(colSums(B), .95)))
record("C3_quantiles", c(per_draw = paired_threshold,
                         baseline_block_q05 = baseline_threshold,
                         block_q95_also_not_equivalent = upper_block_threshold))

# C4: original mapply/t() is K x S for S>1, not a sum over all draws.
out <- t(mapply(function(k) B[k, ], seq_len(2)))
stopifnot(identical(dim(out), c(2L,4L)))
near(2 - colSums(out), paired)
single <- t(mapply(function(k) B[k,1], seq_len(2)))
stopifnot(identical(dim(single), c(1L,2L)))
record("C4_shapes", list(S4 = dim(out), S1 = dim(single)))

# C5: projector-sum inequality in a hand-computable two-block rank-one case.
# Both true spaces are e1. Estimates rotate by +theta and -theta, sin=.6.
q1 <- matrix(c(.8,.6), 2, 1)
q2 <- matrix(c(.8,-.6), 2, 1)
M <- cbind(q1,q2)
evals <- eigen(tcrossprod(M), symmetric = TRUE)$values
near(evals, c(1.28,.72))
near(2 - 2*.6^2, evals[1])
record("C5_projector_sum", c(evals, lower_bound = 2 - 2*.6^2))

# C6: normalized but nonorthogonal raw factors are not a projector.
U <- cbind(c(1,0,0), c(3/5,4/5,0))
G <- crossprod(U)
near(G, matrix(c(1,.6,.6,1),2,2))
raw <- eigen(tcrossprod(cbind(U,U)), symmetric = TRUE)$values
Q <- qr.Q(qr(U))
orth <- eigen(tcrossprod(cbind(Q,Q)), symmetric = TRUE)$values
near(raw, c(3.2,.8,0))
near(orth, c(2,2,0))
stopifnot(op(tcrossprod(U) %*% tcrossprod(U) - tcrossprod(U)) > 0)
record("C6_raw_factor_mismatch", list(raw_squared_singular_values = raw,
                                      orthonormal_squared_singular_values = orth,
                                      amplitude_labels = c(1,1),
                                      actual_block_singular_values = svd(U)$d))

# C7: original replacement sampling can duplicate and inflate spectral norm.
D <- diag(c(10,3,1))
perp <- diag(3)[,2:3,drop=FALSE]
duplicated <- perp[,c(1,1),drop=FALSE]
near(op(D %*% duplicated), 3*sqrt(2))
near(op(D %*% perp), 3)
record("C7_duplicate_columns", c(orthonormal = op(D %*% perp),
                                duplicated = op(D %*% duplicated)))

# C8: complement feasibility, inactive-candidate size, and QR rank loss.
boundary <- data.frame(ambient = c(4,4,4,4), signal = c(0,1,3,4))
boundary$complement <- boundary$ambient - boundary$signal
boundary$active_draw_rank <- boundary$signal
boundary$active_cpp_feasible <- boundary$signal == 0 |
  (boundary$signal > 0 & boundary$signal <= boundary$complement)
boundary$candidate_draw_rank <- pmin(boundary$signal, boundary$complement)
record("C8_complements", boundary)
# Original complement extraction drops the matrix dimension when c=1.
stopifnot(is.null(dim(diag(3)[,-(1:2)])))
# Candidate/reference need a rank-aware check if projected deterministic draws
# are deficient. QR completion of a zero projected draw can leave complement.
signal <- matrix(c(1,0,0),3,1)
z <- signal - signal %*% crossprod(signal,signal)
frame <- qr.Q(qr(z))
record("C8_rank_deficient_projected_draw", c(projected_rank = qr(z)$rank,
                                            leakage = op(crossprod(signal, frame))))

# C9: disabled-by-default Wedin-only threshold yields -Inf, not a valid cutoff.
threshold <- suppressWarnings(max(NA_real_, NA_real_, NA_real_, na.rm = TRUE))
stopifnot(is.infinite(threshold), threshold < 0, all(c(0,.1,2) > threshold))
record("C9_no_effect_threshold", threshold)

# C10: execute ONLY the baseline ratio helper with a deterministic stub sampler.
# This is a private test environment, not a repository edit or estimator fit.
ast <- parse(file.path(package_root, "R", "Rajive_helpfunctions.R"))
helper <- Filter(function(expr) is.call(expr) && identical(expr[[1]], as.name("<-")) &&
                  identical(expr[[2]], as.name("get_wedin_bound_samples")), as.list(ast))
env <- new.env(parent = baseenv())
env$wedin_bound_resampling <- function(X, signal_basis, right_vectors,
                                       num_samples, num_cores) rep(0, num_samples)
eval(helper[[1]], envir = env)
ans_zero_rank <- env$get_wedin_bound_samples(diag(2),
                      list(u=diag(2),v=diag(2),d=c(2,1)), 0L, 3L, 1L)
near(ans_zero_rank, rep(1,3))
record("C10_internal_rank_zero_ratio", ans_zero_rank)
cat("All deterministic arithmetic/source-fragment checks passed.\n")
