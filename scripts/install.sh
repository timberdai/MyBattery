#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
exec ./scripts/dev-reload.sh
