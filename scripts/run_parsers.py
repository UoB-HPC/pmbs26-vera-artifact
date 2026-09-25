#!/usr/bin/env python3
"""Regenerate data/ from results/.

Runs the four benchmark parsers and the applications converter, in order:
  scripts/parse/stream.py     results/stream/    -> data/stream/
  scripts/parse/test_tlb.py   results/test-tlb/  -> data/test-tlb/
  scripts/parse/npb.py        results/npb/       -> data/npb/
  scripts/parse/miniapps.py   results/miniapps/  -> data/miniapps/
  gnuplot/make_apps_csv.py    results/applications/ -> data/applications/

The core-to-core matrices (results/c2c/) need no parsing: the figure scripts
read them directly. Run from anywhere:
    python3 scripts/run_parsers.py
"""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STEPS = [
    "scripts/parse/stream.py",
    "scripts/parse/test_tlb.py",
    "scripts/parse/npb.py",
    "scripts/parse/miniapps.py",
    "gnuplot/make_apps_csv.py",
]

failed = []
for step in STEPS:
    print(f"== {step}")
    r = subprocess.run([sys.executable, str(ROOT / step)], cwd=ROOT)
    if r.returncode:
        failed.append(step)
if failed:
    sys.exit(f"failed: {', '.join(failed)}")
print("data/ regenerated")
