#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Building File Organizer App..."
swift build

BIN="$(swift build --show-bin-path)/FileOrganizerApp"
echo "Launching (detached from Terminal): $BIN"
open "$BIN"
