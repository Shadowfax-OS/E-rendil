#!/bin/bash
# Runs the test suite with the Swift Testing framework search path that
# CLT-only setups require. Bare `swift test` here builds but runs ZERO tests
# and exits 0. Pass-through args are forwarded (e.g. Scripts/test.sh --filter Foo).
set -euo pipefail
cd "$(dirname "$0")/.."
exec swift test \
  -Xswiftc -F -Xswiftc /Library/Developer/CommandLineTools/Library/Developer/Frameworks \
  "$@"
