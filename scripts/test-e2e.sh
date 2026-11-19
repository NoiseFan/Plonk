#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

runner="${TMPDIR:-/tmp}/plonk-shot-e2e-${UID:-$(id -u)}"
mkdir -p "$runner"
swiftc -module-cache-path "$runner/ModuleCache" App/Tests/ShotE2E/*.swift -o "$runner/shot-e2e"
case "${1:-}" in
    --list|--permissions|--request-permissions) exec "$runner/shot-e2e" "$1" ;;
esac
if [ "${1:-}" = "--compile-only" ]; then
    exit 0
fi

if [ "${PLONK_E2E_DESKTOP:-}" != 1 ]; then
    echo "Run with PLONK_E2E_DESKTOP=1 in a dedicated, unlocked test session." >&2
    exit 2
fi

./scripts/build.sh
if [ "$#" -eq 0 ]; then
    npm --prefix mcp run build
else
    for case_id do
        case "$case_id" in MCP-*) npm --prefix mcp run build; break ;; esac
    done
fi
PLONK_E2E_REVISION=$(git rev-parse --short HEAD)
export PLONK_E2E_REVISION
exec "$runner/shot-e2e" "$PWD/Plonk.app" "$@"
