# Documented behaviour must match implemented behaviour.
#
# `rajive_report()` documented a `jackstraw_result` argument that added a
# significance section, but the body never referenced it, and it advertised a
# "stability" section that emitted a fixed instruction string. Documentation that
# describes behaviour the code does not implement is worse than absent
# documentation, so both are pinned here.

report_fixture <- function() {
  set.seed(5150L)
  sim <- simulate_blocks(n = 40L, pks = c(30L, 20L),
                         joint_rank = 2L, individual_ranks = c(4L, 3L),
                         seed = 5150L)
  fit <- Rajive(sim$blocks, c(4L, 3L),
                joint_rank = 2L, n_wedin_samples = 50L,
                n_rand_dir_samples = 50L, num_cores = 1L, seed = 5150L)
  js <- jackstraw_rajive(fit, blocks = sim$blocks, n_null = 20L)
  list(blocks = sim$blocks, fit = fit, jackstraw = js)
}

read_report <- function(fx, ...) {
  out <- tempfile(fileext = ".md")
  rajive_report(fx$fit, blocks = fx$blocks, output_file = out, ...)
  on.exit(unlink(out), add = TRUE)
  paste(readLines(out, warn = FALSE), collapse = "\n")
}

test_that("supplying jackstraw_result adds a significance section", {
  fx <- report_fixture()

  without <- read_report(fx, sections = "significance")
  expect_false(grepl("## Significant Features", without, fixed = TRUE))

  with_js <- read_report(fx, sections = "significance",
                         jackstraw_result = fx$jackstraw)
  expect_true(grepl("## Significant Features", with_js, fixed = TRUE))
})

test_that("the default section list includes significance", {
  fx <- report_fixture()
  text <- read_report(fx, jackstraw_result = fx$jackstraw)
  expect_true(grepl("## Significant Features", text, fixed = TRUE))
})

test_that("every advertised section is actually reachable", {
  # A section listed in the default that silently produces nothing is a stub.
  fx <- report_fixture()
  metadata <- data.frame(group = rep(c("a", "b"), length.out = nrow(fx$blocks[[1]])))
  sections <- c("overview", "variance", "features", "associations",
                "significance", "stability")
  text <- read_report(fx, jackstraw_result = fx$jackstraw,
                      metadata = metadata, sections = sections)

  headings <- c(
    overview = "## Overview",
    variance = "## Variance",
    features = "## Top Features",
    associations = "## Associations",
    significance = "## Significant Features",
    stability = "## Stability"
  )

  for (s in sections) {
    expect_true(grepl(headings[[s]], text, fixed = TRUE),
                label = paste0("missing heading for section: ", s))
  }
})
