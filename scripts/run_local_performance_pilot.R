#!/usr/bin/env Rscript

devtools::load_all(".", quiet = TRUE)
set.seed(20261020L)

scenarios <- list(
  small_complete = list(n = 50L, p = 40L, missing = FALSE),
  small_weighted = list(n = 50L, p = 40L, missing = TRUE),
  moderate_complete = list(n = 200L, p = 80L, missing = FALSE),
  moderate_weighted = list(n = 200L, p = 80L, missing = TRUE)
)

rows <- lapply(names(scenarios), function(id) {
  scenario <- scenarios[[id]]
  x <- matrix(rnorm(scenario$n * scenario$p), scenario$n, scenario$p)
  weights <- NULL
  if (scenario$missing) {
    weights <- matrix(runif(length(x)) > 0.2, nrow(x), ncol(x))
    x[!weights] <- NA_real_
  }
  elapsed <- system.time({
    fit <- RobRSVD.all(
      x, nrank = 3L, weights = weights,
      max_iter = 3L, irls_max_iter = 50L,
      warn_nonconvergence = FALSE
    )
  })[["elapsed"]]
  data.frame(
    scenario_id = id,
    n = scenario$n,
    p = scenario$p,
    missing = scenario$missing,
    elapsed_seconds = elapsed,
    input_megabytes = scenario$n * scenario$p * 8 / 1024^2,
    converged = if (is.null(fit$converged)) NA else fit$converged,
    fallback_used = isTRUE(fit$fallback_used),
    stringsAsFactors = FALSE
  )
})

write.table(
  do.call(rbind, rows),
  "docs/_codexdocs/execution/2026-09-19/stage_d_performance_pilot.tsv",
  sep = "\t", quote = TRUE, row.names = FALSE, na = "NA"
)
