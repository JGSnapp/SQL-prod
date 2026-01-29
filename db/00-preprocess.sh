#!/usr/bin/env bash
set -euo pipefail

INPUT=${INPUT:-/data/candidates.csv}
CLEAN=${CLEAN:-/data/candidates_clean.csv}
BAD=${BAD:-/data/candidates_bad.csv}
LOG=${LOG:-/data/candidates_bad_rows.txt}
DELIM=${DELIM:-';'}

if [[ ! -f "$INPUT" ]]; then
  echo "preprocess: input file not found: $INPUT" >&2
  exit 1
fi

PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  echo "preprocess: python not found in container; cannot preprocess CSV" >&2
  exit 1
fi

export INPUT CLEAN BAD LOG DELIM

${PYTHON_BIN} - <<'PY'
import csv
import os
import sys

input_path = os.environ["INPUT"]
clean_path = os.environ["CLEAN"]
bad_path = os.environ["BAD"]
log_path = os.environ["LOG"]
delim = os.environ["DELIM"]

expected_cols = None
bad_count = 0

with open(input_path, newline="", encoding="utf-8") as f_in, \
     open(clean_path, "w", newline="", encoding="utf-8") as f_clean, \
     open(bad_path, "w", newline="", encoding="utf-8") as f_bad, \
     open(log_path, "w", encoding="utf-8") as f_log:

    reader = csv.reader(f_in, delimiter=delim, strict=False)
    clean_writer = csv.writer(f_clean, delimiter=delim)
    bad_writer = csv.writer(f_bad, delimiter=delim)

    f_log.write("row_number\treason\tfound\texpected\n")

    for row_num, row in enumerate(reader, start=1):
        if expected_cols is None:
            expected_cols = len(row)
            clean_writer.writerow(row)
            bad_writer.writerow(row)
            continue

        if len(row) == expected_cols:
            clean_writer.writerow(row)
        else:
            bad_count += 1
            reason = "too_few_columns" if len(row) < expected_cols else "too_many_columns"
            f_log.write(f"{row_num}\t{reason}\t{len(row)}\t{expected_cols}\n")
            bad_writer.writerow(row)

print(
    f"preprocess: done. bad_rows={bad_count}, clean={clean_path}, bad={bad_path}, log={log_path}",
    file=sys.stderr,
)
PY
