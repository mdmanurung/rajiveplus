#!/usr/bin/env python3
import json
import sys
import xml.etree.ElementTree as ET


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: check_slow_manifest.py MANIFEST JUNIT_XML")
    with open(sys.argv[1], encoding="utf-8") as handle:
        manifest = json.load(handle)
    root = ET.parse(sys.argv[2]).getroot()
    cases = list(root.iter("testcase"))
    observed = {case.attrib.get("name", ""): case for case in cases}
    failures = []
    for required in manifest["required_tests"]:
        name = required["id"]
        case = observed.get(name)
        if case is None:
            failures.append("missing test: " + name)
            continue
        if case.find("failure") is not None or case.find("error") is not None:
            failures.append("failed test: " + name)
        if case.find("skipped") is not None and not required["allow_skip"]:
            failures.append("unexpected skip: " + name)
    if failures:
        raise SystemExit("slow-test completeness failed:\n" + "\n".join(failures))
    print("slow-test completeness PASS: %d required tests" %
          len(manifest["required_tests"]))


if __name__ == "__main__":
    main()
