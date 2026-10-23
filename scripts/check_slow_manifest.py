#!/usr/bin/env python3
import csv
import glob
import json
import os
import re
import sys
import xml.etree.ElementTree as ET


def normalize_test_name(name):
    return re.sub(r"[^A-Za-z0-9]+", "_", name).strip("_")


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: check_slow_manifest.py MANIFEST JUNIT_XML")
    with open(sys.argv[1], encoding="utf-8") as handle:
        manifest = json.load(handle)
    results_path = os.path.abspath(sys.argv[2])
    if os.path.isdir(results_path):
        xml_paths = sorted(glob.glob(os.path.join(results_path, "*.xml")))
        artifact_root = results_path
    else:
        xml_paths = [results_path]
        artifact_root = os.path.dirname(results_path)
    if not xml_paths:
        raise SystemExit("slow-test completeness failed:\nno JUnit XML files")
    cases = []
    for xml_path in xml_paths:
        cases.extend(ET.parse(xml_path).getroot().iter("testcase"))
    observed = {}
    for case in cases:
        name = normalize_test_name(case.attrib.get("name", ""))
        observed.setdefault(name, []).append(case)
    failures = []
    for required in manifest["required_tests"]:
        name = required["id"]
        matching_cases = observed.get(normalize_test_name(name), [])
        if not matching_cases:
            failures.append("missing test: " + name)
            continue
        if any(case.find("failure") is not None or
               case.find("error") is not None for case in matching_cases):
            failures.append("failed test: " + name)
        if (any(case.find("skipped") is not None for case in matching_cases)
                and not required["allow_skip"]):
            failures.append("unexpected skip: " + name)
    for required in manifest.get("required_artifacts", []):
        relative_path = required["path"]
        path = os.path.join(artifact_root, relative_path)
        if not os.path.isfile(path):
            failures.append("missing artifact: " + relative_path)
            continue
        with open(path, encoding="utf-8", newline="") as handle:
            reader = csv.DictReader(handle, delimiter="\t")
            rows = list(reader)
            columns = set(reader.fieldnames or [])
        expected_rows = required["expected_rows"]
        if len(rows) != expected_rows:
            failures.append(
                "artifact row count %s: expected %d, observed %d"
                % (relative_path, expected_rows, len(rows))
            )
        missing_columns = sorted(
            set(required.get("required_columns", [])) - columns
        )
        if missing_columns:
            failures.append(
                "artifact columns %s: missing %s"
                % (relative_path, ", ".join(missing_columns))
            )
        if "status" in columns:
            bad_status = [row.get("status") for row in rows
                          if row.get("status") != "PASS"]
            if bad_status:
                failures.append(
                    "artifact failures %s: %d non-PASS rows"
                    % (relative_path, len(bad_status))
                )
        if "replicate_id" in columns:
            replicate_ids = [row.get("replicate_id") for row in rows]
            if len(set(replicate_ids)) != len(replicate_ids):
                failures.append("duplicate replicate_id: " + relative_path)
    if failures:
        raise SystemExit("slow-test completeness failed:\n" + "\n".join(failures))
    print(
        "slow-test completeness PASS: %d required tests, %d artifacts, %d JUnit files"
        % (len(manifest["required_tests"]),
           len(manifest.get("required_artifacts", [])), len(xml_paths))
    )


if __name__ == "__main__":
    main()
