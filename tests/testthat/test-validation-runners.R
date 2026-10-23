test_that("canonical validation runners fail closed", {
  skip_if_not(file.exists(test_path("../../scripts/run_fast_gate.sh")),
              "repository-only validation infrastructure")
  runners <- test_path("../..", c("scripts/run_fast_gate.sh",
                                   "scripts/run_slow_gate.sh",
                                   "scripts/run_check_gate.sh"))
  for (runner in runners) {
    text <- readLines(runner, warn = FALSE)
    expect_true(any(grepl("set -euo pipefail", text, fixed = TRUE)))
    expect_true(any(grepl("tee", text, fixed = TRUE)))
  }
  expect_true(any(grepl(
    "stop_on_failure = TRUE",
    readLines(test_path("../../scripts/run_fast_gate.sh"), warn = FALSE), fixed = TRUE
  )))
  slow_runner <- readLines(test_path("../../scripts/run_slow_gate.sh"),
                           warn = FALSE)
  expect_true(any(grepl("testthat::test_file", slow_runner, fixed = TRUE)))
  expect_true(any(grepl("validation/slow_tests.json", slow_runner,
                        fixed = TRUE)))
  expect_true(any(grepl("RAJIVE_SLOW_MANIFEST", slow_runner,
                        fixed = TRUE)))
  expect_true(any(grepl("stop_on_warning = TRUE", slow_runner,
                        fixed = TRUE)))
  check_runner <- readLines(test_path("../../scripts/run_check_gate.sh"),
                            warn = FALSE)
  expect_true(any(grepl("error_on = \"never\"", check_runner, fixed = TRUE)))
  expect_true(any(grepl("check_rcmd_fingerprint.py", check_runner,
                        fixed = TRUE)))
})

test_that("R CMD check fingerprint rejects warnings, notes, and missing summaries", {
  skip_if_not(file.exists(test_path("../../validation/check_fingerprint.json")),
              "repository-only validation infrastructure")
  python <- Sys.which("python3")
  skip_if(python == "", "python3 is required for the validation runner")
  manifest <- test_path("../../validation/check_fingerprint.json")
  log <- tempfile(fileext = ".log")
  checker <- test_path("../../scripts/check_rcmd_fingerprint.py")
  run_check <- function(contents) {
    writeLines(contents, log)
    suppressWarnings(system2(python, c(checker, manifest, log),
                             stdout = TRUE, stderr = TRUE))
  }

  pass <- run_check("0 errors | 0 warnings | 0 notes")
  expect_null(attr(pass, "status"))
  expect_match(paste(pass, collapse = "\n"), "fingerprint PASS")

  status_ok <- run_check("Status: OK")
  expect_null(attr(status_ok, "status"))
  expect_match(paste(status_ok, collapse = "\n"), "fingerprint PASS")

  warning <- run_check("Status: 1 WARNING")
  expect_true(attr(warning, "status") != 0L)
  expect_match(paste(warning, collapse = "\n"), "fingerprint mismatch")

  note <- run_check("Status: 2 NOTEs")
  expect_true(attr(note, "status") != 0L)
  expect_match(paste(note, collapse = "\n"), "fingerprint mismatch")

  missing <- run_check("all checks looked fine")
  expect_true(attr(missing, "status") != 0L)
  expect_match(paste(missing, collapse = "\n"), "summary is missing")
})

test_that("slow-test manifest is machine readable and requires non-skipped tests", {
  skip_if_not(file.exists(test_path("../../validation/slow_tests.json")),
              "repository-only validation infrastructure")
  skip_if_not_installed("jsonlite")
  manifest <- jsonlite::read_json(test_path("../../validation/slow_tests.json"),
                                  simplifyVector = TRUE)
  expect_true(nrow(manifest$required_tests) >= 5L)
  expect_false(any(manifest$required_tests$allow_skip))
  expect_true(all(manifest$required_tests$expected_datasets >= 1L))
  expect_equal(nrow(manifest$required_artifacts), 3L)
  expect_true(all(manifest$required_artifacts$expected_rows >= 1L))
})

test_that("slow-test completeness checker validates replicate artifacts", {
  skip_if_not(file.exists(test_path("../../scripts/check_slow_manifest.py")),
              "repository-only validation infrastructure")
  skip_if_not_installed("jsonlite")
  python <- Sys.which("python3")
  skip_if(python == "", "python3 is required for the validation runner")

  gate_dir <- tempfile("slow-artifacts-")
  dir.create(gate_dir)
  manifest <- file.path(gate_dir, "manifest.json")
  xml <- file.path(gate_dir, "results.xml")
  evidence <- file.path(gate_dir, "replicates.tsv")
  writeLines(jsonlite::toJSON(list(
    required_tests = list(list(
      id = "required calibration", expected_datasets = 2L,
      optional_dependencies = list(), allow_skip = FALSE
    )),
    required_artifacts = list(list(
      path = "replicates.tsv", expected_rows = 2L,
      required_columns = list("replicate_id", "status", "metric")
    ))
  ), auto_unbox = TRUE, pretty = TRUE), manifest)
  writeLines(
    "<testsuite><testcase name='required calibration'/></testsuite>", xml
  )
  checker <- test_path("../../scripts/check_slow_manifest.py")
  run_check <- function() suppressWarnings(system2(
    python, c(checker, manifest, xml), stdout = TRUE, stderr = TRUE
  ))

  writeLines(c("replicate_id\tstatus\tmetric", "r1\tPASS\t1"), evidence)
  short <- run_check()
  expect_true(attr(short, "status") != 0L)
  expect_match(paste(short, collapse = "\n"), "row count")

  writeLines(c(
    "replicate_id\tstatus\tmetric",
    "r1\tPASS\t1",
    "r2\tERROR\tNA"
  ), evidence)
  failed <- run_check()
  expect_true(attr(failed, "status") != 0L)
  expect_match(paste(failed, collapse = "\n"), "non-PASS")

  writeLines(c(
    "replicate_id\tstatus\tmetric",
    "r1\tPASS\t1",
    "r2\tPASS\t2"
  ), evidence)
  passed <- run_check()
  expect_null(attr(passed, "status"))
  expect_match(paste(passed, collapse = "\n"), "1 artifacts")
})

test_that("slow-test completeness checker rejects false-green JUnit output", {
  skip_if_not(file.exists(test_path("../../scripts/check_slow_manifest.py")),
              "repository-only validation infrastructure")
  skip_if_not_installed("jsonlite")
  python <- Sys.which("python3")
  skip_if(python == "", "python3 is required for the validation runner")

  manifest <- tempfile(fileext = ".json")
  xml <- tempfile(fileext = ".xml")
  writeLines(jsonlite::toJSON(list(
    required_tests = list(list(
      id = "required calibration",
      expected_datasets = 10L,
      optional_dependencies = list(),
      allow_skip = FALSE
    ))
  ), auto_unbox = TRUE, pretty = TRUE), manifest)

  run_check <- function(contents) {
    writeLines(contents, xml)
    suppressWarnings(system2(
      python,
      c(test_path("../../scripts/check_slow_manifest.py"), manifest, xml),
      stdout = TRUE,
      stderr = TRUE
    ))
  }

  missing <- run_check("<testsuite><testcase name='another test'/></testsuite>")
  expect_true(attr(missing, "status") != 0L)
  expect_match(paste(missing, collapse = "\n"), "missing test")

  skipped <- run_check(paste0(
    "<testsuite><testcase name='required calibration'>",
    "<skipped/></testcase></testsuite>"
  ))
  expect_true(attr(skipped, "status") != 0L)
  expect_match(paste(skipped, collapse = "\n"), "unexpected skip")

  failed <- run_check(paste0(
    "<testsuite><testcase name='required calibration'>",
    "<failure/></testcase></testsuite>"
  ))
  expect_true(attr(failed, "status") != 0L)
  expect_match(paste(failed, collapse = "\n"), "failed test")

  passed <- run_check(
    "<testsuite><testcase name='required_calibration'/></testsuite>"
  )
  expect_null(attr(passed, "status"))
  expect_match(paste(passed, collapse = "\n"), "completeness PASS")
})
