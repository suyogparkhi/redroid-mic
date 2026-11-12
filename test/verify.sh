#!/bin/bash
# End-to-end check: record with micrec (AudioRecord) while feed-wav.sh plays a file into the mic,
# then compare the capture with the source. Usage: verify.sh <wav> <name> [src] [comm] [rate]
#   src: MediaRecorder.AudioSource (1 = MIC, 7 = VOICE_COMMUNICATION); comm=true sets MODE_IN_COMMUNICATION. rate: app sample rate (compare.py needs 48000).
set -euo pipefail
cd "$(dirname "$0")"
WAV="$1"; NAME="$2"; SRC="${3:-1}"; COMM="${4:-false}"; RATE="${5:-48000}"
A="adb -s ${SERIAL:-127.0.0.1:5555}"
DUR=$(soxi -D "$WAV"); SECS=$(python3 -c "import math;print(math.ceil($DUR)+3)")
$A logcat -c </dev/null
$A shell am force-stop com.example.micrec </dev/null
$A shell am start -n com.example.micrec/.MainActivity --ei src "$SRC" --ei secs "$SECS" --ez comm "$COMM" --ei rate "$RATE" </dev/null >/dev/null
until $A logcat -d -s MICREC </dev/null | grep -q recording; do sleep 0.1; done
sleep 1
FEED_T=$(date +%s.%N)
../feed-wav.sh "$WAV"
until $A logcat -d -s MICREC </dev/null | grep -q "done bytes"; do sleep 0.2; done
REC_LINE=$($A logcat -v epoch -d -s MICREC </dev/null | grep recording)
$A logcat -d -s MICREC </dev/null | grep -E "recording|done"
$A pull /sdcard/Android/data/com.example.micrec/files/rec.wav "captured_${NAME}.wav" </dev/null >/dev/null
python3 compare.py "$WAV" "captured_${NAME}.wav" "$(echo "$REC_LINE" | awk '{print $1}')" "$FEED_T"
