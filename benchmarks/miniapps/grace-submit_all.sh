#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sbatch "$SCRIPT_DIR/cloverleaf/run_cloverleaf-bm32-short_n-core.slurm"
sbatch "$SCRIPT_DIR/tealeaf/run_tealeaf-bm_5e_2_n-core.slurm"
sbatch "$SCRIPT_DIR/minibude/run_minibude-bm1_n-core.slurm"
sbatch "$SCRIPT_DIR/neutral/run_neutral-stream_n-core.slurm"
sbatch "$SCRIPT_DIR/nas/run_nas_scaling.sh"
sbatch "$SCRIPT_DIR/nas/run_nas.sh"
