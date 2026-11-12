#!/bin/bash
# Build the redroid-mic:15 image: Redroid 15 (arm64) with a mic that reads PCM from /mic/mic.fifo.
# Needs git and Docker on an arm64 Linux host. The HAL is compiled inside Docker.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p mic && chmod 777 mic   # the image's /mic must be writable by audioserver; git cannot keep mode 777
[ -d aosp ] || bash fetch-aosp.sh
docker build -t redroid-mic:15 .
