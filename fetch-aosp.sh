#!/bin/bash
# Fetches the AOSP 15 headers (and the stock stub HAL source) that the Dockerfile compiles against. ~6 MB.
set -euo pipefail
cd "$(dirname "$0")" && rm -rf aosp && mkdir aosp && cd aosp
clone() { git clone -q --depth 1 --branch android15-release --filter=blob:none --sparse "https://android.googlesource.com/platform/$1" "$2"; (cd "$2" && git sparse-checkout set "${@:3}"); }
clone hardware/libhardware libhardware include_all modules/audio
clone system/media media audio/include
clone system/core core libcutils/include libsystem/include
clone system/logging logging liblog/include
