#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-8181}"

# Resolve repo root no matter where this is run from
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

exec opa run --server --addr=0.0.0.0:${PORT} \
  "${ROOT}/policy/policy.rego" \
  "${ROOT}/policy/data.json"
