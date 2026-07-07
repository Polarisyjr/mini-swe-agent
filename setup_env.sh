#!/bin/bash
# Set up the `sweagent` conda env for mini-swe-agent (the modern SWE-agent
# rewrite; this is the "sweagent" framework in this project).
#
# What it does (all idempotent — safe to re-run):
#   1. ensure miniconda + conda env `sweagent` (python 3.11)
#   2. pip install -e .   (editable install, so you run the checked-out repo
#      code, not a pinned release)
#   3. verify: `mini --help`, `mini-extra --help`, `import minisweagent` all work
#
# Usage (from anywhere):
#   bash frameworks/mini-swe-agent/setup_env.sh             # full setup
#   bash frameworks/mini-swe-agent/setup_env.sh --verify    # skip install, just check
#
# Env overrides:
#   CONDA_HOME   conda install prefix   ($CONDA_BASE override > `conda info --base` > ~/miniconda3)
#   CONDA_ENV    env name               (default: sweagent)
#
# Running against local vLLM (not a setup_env.sh concern, noted here so it
# isn't rediscovered — see docs/models/local_models.md for the general
# recipe):
#   - model_name: "hosted_vllm/<served_model_name>", model_kwargs.api_base
#     pointed at the vLLM endpoint (e.g. http://localhost:8000/v1).
#   - cost tracking errors without a registry entry for the model — either
#     set `model.cost_tracking: "ignore_errors"` in the config / export
#     MSWEA_COST_TRACKING="ignore_errors", or supply a LITELLM_MODEL_REGISTRY_PATH
#     json (see docs/models/local_models.md).
#   - `mini-extra swebench-single ... -y` alone is NOT enough for a
#     non-interactive run: the default `interactive` agent still blocks on
#     stdin for the final "finish?" confirmation and aborts with
#     `exit_status: EOFError` + an empty submission. Add `--exit-immediately`
#     (undocumented in the current docs page) to actually capture the patch.
#   - HF_HOME: `~/.bash_profile` sets HF_HOME=/mnt/azureuser/huggingface,
#     which is not writable by this user and shadows ~/.bashrc's
#     HF_HOME=/mnt/raid0/jirong/hf (where SWE-bench dataset/models actually
#     live). Export HF_HOME=/mnt/raid0/jirong/hf explicitly.
#   - For actually scoring a generated patch (not just producing a
#     trajectory), `pip install swebench` (not a mini-swe-agent dependency)
#     and run its docker-based harness the same way trae-agent's smoke test
#     does.

set -euo pipefail

CONDA_HOME="${CONDA_HOME:-${CONDA_BASE:-$(conda info --base 2>/dev/null)}}"; [ -n "$CONDA_HOME" ] || CONDA_HOME="$HOME/miniconda3"
CONDA_ENV="${CONDA_ENV:-sweagent}"
MSWEA_DIR="$(cd "$(dirname "$0")" && pwd)"     # this script lives in frameworks/mini-swe-agent
VERIFY_ONLY=0
[ "${1:-}" = "--verify" ] && VERIFY_ONLY=1

say()  { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32mok\033[0m %s\n' "$*"; }
die()  { printf '\033[31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

conda_run() { "$CONDA_HOME/bin/conda" run --no-capture-output -n "$CONDA_ENV" "$@"; }

if [ "$VERIFY_ONLY" = "0" ]; then
    say "1. conda env '$CONDA_ENV'"
    [ -x "$CONDA_HOME/bin/conda" ] || die "conda not found at $CONDA_HOME — install miniconda there, or set CONDA_HOME"
    if ! "$CONDA_HOME/bin/conda" env list | grep -qE "^${CONDA_ENV}\s"; then
        "$CONDA_HOME/bin/conda" create -y -n "$CONDA_ENV" python=3.11
    fi
    ok "env ready ($(conda_run python --version 2>&1))"

    say "2. pip install -e ."
    ( cd "$MSWEA_DIR" && conda_run pip install -e . )
    ok "mini-swe-agent installed"
fi

say "verify"
conda_run python -c "import minisweagent" && ok "import minisweagent"
conda_run mini --help >/dev/null && ok "mini --help runs"
conda_run mini-extra --help >/dev/null && ok "mini-extra --help runs"

printf '\n\033[1;32mmini-swe-agent environment ready.\033[0m  See docs/models/local_models.md (and this script'"'"'s header) for how to point it at local vLLM.\n'
