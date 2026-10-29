#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

PATHS=(Sources Tests Package.swift)

if [[ "${1:-}" == "--fix" ]]; then
    swift format format --in-place --recursive --parallel "${PATHS[@]}"
    swiftlint lint --fix --quiet
fi

swift format lint --strict --recursive --parallel "${PATHS[@]}"
swiftlint lint --strict --quiet
