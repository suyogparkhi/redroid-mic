#!/bin/bash
# Usage: feed-wav.sh <audio-file>   Plays the file into the redroid-mic microphone.
# Converts any sox-readable file to 48 kHz mono s16le and writes it to the mic FIFO.
# Returns once all but the last ~0.7 s (the 64 KiB pipe buffer) has been consumed.
# The FIFO is drained only while an app records; with no recorder this blocks.
# MIC_DIR is the host folder mounted at /mic in the container (default: ./mic next to this script).
# Set ADB_SERIAL (for example 127.0.0.1:5555) to feed through adb instead of the host FIFO.
set -euo pipefail
[ -r "${1:-}" ] || { echo "usage: $0 <audio-file>" >&2; exit 2; }
if [ -n "${ADB_SERIAL:-}" ]; then
  sox "$1" -t raw -r 48000 -c 1 -b 16 -e signed-integer -L - | adb -s "${ADB_SERIAL}" exec-in sh -c 'cat > /mic/mic.fifo'
else
  sox "$1" -t raw -r 48000 -c 1 -b 16 -e signed-integer -L - > "${MIC_DIR:-$(cd "$(dirname "$0")" && pwd)/mic}/mic.fifo"
fi
