test_that("simulated-data inference vignette renders", {
  skip_if_not_installed("rmarkdown")
  skip_if_not(rmarkdown::pandoc_available("2.8"),
              "pandoc >= 2.8 is required to render vignettes")

  vignette_path <- test_path("../../vignettes/inference.Rmd")
  if (!file.exists(vignette_path)) {
    vignette_path <- file.path(getwd(), "vignettes", "inference.Rmd")
  }
  skip_if_not(file.exists(vignette_path),
              "source vignette is not available in this check environment")

  out_dir <- tempfile("rajiveplus-vignette-")
  dir.create(out_dir)
  rendered <- rmarkdown::render(
    input = vignette_path,
    output_dir = out_dir,
    intermediates_dir = out_dir,
    quiet = TRUE,
    envir = new.env(parent = globalenv())
  )

  expect_true(file.exists(rendered))
})
