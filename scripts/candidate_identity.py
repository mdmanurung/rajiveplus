#!/usr/bin/env python3
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys


ROOTS = ("R", "src", "tests", "man", "vignettes", "inst", "scripts",
         "validation", "docs/adr", "doc", "docs/articles",
         "docs/reference", "docs/news")
ROOT_FILES = ("DESCRIPTION", "NAMESPACE", "README.Rmd", "README.md",
              "LICENSE", ".Rbuildignore", ".gitignore", "_pkgdown.yml",
              "docs/404.html", "docs/LICENSE-text.html", "docs/authors.html",
              "docs/index.html", "docs/katex-auto.js", "docs/lightswitch.js",
              "docs/link.svg", "docs/llms.txt", "docs/pkgdown.js",
              "docs/pkgdown.yml", "docs/search.json", "docs/sitemap.xml")
GENERATED_BINARY_SUFFIXES = (".o", ".so", ".dll", ".dylib")


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def git(*args):
    return subprocess.check_output(["git"] + list(args), cwd=".")


def main():
    output = Path(sys.argv[1] if len(sys.argv) > 1 else
                  "docs/_codexdocs/execution/2026-09-19/candidate_identity.json")
    files = []
    for root in ROOTS:
        path = Path(root)
        if path.exists():
            files.extend(
                p for p in path.rglob("*")
                if p.is_file() and p.suffix not in GENERATED_BINARY_SUFFIXES
            )
    files.extend(Path(name) for name in ROOT_FILES if Path(name).is_file())
    files = sorted(set(files), key=lambda p: str(p))
    file_hashes = {str(path): sha256(path.read_bytes()) for path in files}
    source_payload = "".join("%s  %s\n" % (digest, name)
                             for name, digest in sorted(file_hashes.items()))
    patch = git("diff", "--binary", "HEAD")
    index = git("diff", "--cached", "--binary", "HEAD")
    result = {
        "schema_version": 1,
        "head": git("rev-parse", "HEAD").decode().strip(),
        "source_sha256": sha256(source_payload.encode()),
        "dirty_patch_sha256": sha256(patch),
        "index_patch_sha256": sha256(index),
        "files": file_hashes,
        "job_contract": {
            "source": "read-only staged checkout matching source_sha256",
            "library": "job-local library only",
            "temporary_directory": "job-local temporary directory only",
            "receipt_parent": "this candidate identity hash"
        },
        "invalidation": [
            "Any source, generated documentation, DESCRIPTION, NAMESPACE, README, method-profile, or validation-manifest change invalidates downstream receipts.",
            "A receipt whose parent source_sha256 differs from this record is stale."
        ]
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(result["source_sha256"])


if __name__ == "__main__":
    main()
