#!/usr/bin/env python3
import json
import re
import sys


def parse_counts(text):
    status_lines = re.findall(r"(?im)^Status:\s*(.*?)\s*$", text)
    if status_lines and status_lines[-1].upper() == "OK":
        return (0, 0, 0)

    summaries = re.findall(
        r"(?im)^Status:\s*(?:(\d+) ERROR(?:S)?)?[,]?\s*"
        r"(?:(\d+) WARNING(?:S)?)?[,]?\s*(?:(\d+) NOTE(?:S)?)?\s*$",
        text,
    )
    if summaries:
        return tuple(int(value or 0) for value in summaries[-1])

    summaries = re.findall(
        r"(?im)(\d+) errors?[^\n|]*\|\s*"
        r"(\d+) warnings?[^\n|]*\|\s*(\d+) notes?",
        text,
    )
    if summaries:
        return tuple(int(value) for value in summaries[-1])
    raise ValueError("R CMD check status summary is missing")


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: check_rcmd_fingerprint.py MANIFEST CHECK_LOG")
    with open(sys.argv[1], encoding="utf-8") as handle:
        manifest = json.load(handle)
    with open(sys.argv[2], encoding="utf-8", errors="replace") as handle:
        observed = parse_counts(handle.read())
    expected = tuple(manifest["expected_counts"][key]
                     for key in ("errors", "warnings", "notes"))
    if observed != expected:
        raise SystemExit(
            "R CMD check fingerprint mismatch: observed errors/warnings/notes "
            f"{observed}; expected {expected}"
        )
    print("R CMD check fingerprint PASS: errors/warnings/notes %s" %
          (observed,))


if __name__ == "__main__":
    main()
