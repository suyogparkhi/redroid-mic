# redroid-mic

Microphone input for [Redroid](https://github.com/remote-android/redroid-doc) (Android in Docker). Play any audio file into the container's mic, and apps that record with `AudioRecord` (including WebRTC voice calls) receive it.

Redroid ships AOSP's stub audio HAL (`audio.primary.default.so`), whose input stream returns silence. This project patches that stub so the input stream reads raw PCM from a FIFO, `/mic/mic.fifo`, and returns silence while the FIFO is empty. The patched `.so` goes into the stock Redroid image as one Docker layer. No AOSP build is needed: the HAL compiles with clang against the NDK sysroot and the AOSP 15 headers.

Related Redroid issues: [#548](https://github.com/remote-android/redroid-doc/issues/548), [#857](https://github.com/remote-android/redroid-doc/issues/857).

## Status

- Tested on `redroid/redroid:15.0.0_64only-latest`, arm64 (AWS Graviton, Ubuntu 24.04 host).
- `AudioRecord` with sources MIC and VOICE_COMMUNICATION receives the fed audio bit-exact (0 differing samples).
- A LiveKit (WebRTC) voice call received fed speech and transcribed it.
- Not tested: other Android versions, x86_64, AAudio or OpenSL ES recorders (they should fall back to the same path).

## Build

On an arm64 Linux host with Docker and git:

```
./build.sh
```

This fetches the AOSP 15 headers (about 6 MB, `fetch-aosp.sh`), compiles `hal/audio_hw.c`, and builds `redroid-mic:15` on top of the pinned Redroid 15 image. The usual Redroid host setup applies (binder module loaded).

## Run

```
mkdir -p mic && chmod 777 mic
docker run -d --privileged --name redroid -v "$PWD/mic:/mic" -p 127.0.0.1:5555:5555 redroid-mic:15 \
  androidboot.redroid_gpu_mode=guest androidboot.use_memfd=true
```

The HAL creates `mic/mic.fifo` on first use.

## Feed audio

Start the recording first (open the app's call or recorder), then:

```
./feed-wav.sh question.wav                       # writes into ./mic/mic.fifo on the host
ADB_SERIAL=127.0.0.1:5555 ./feed-wav.sh q.wav    # or through adb, from any machine
```

Or without sox:

```
ffmpeg -i in.wav -f s16le -ar 48000 -ac 1 - | adb exec-in sh -c 'cat > /mic/mic.fifo'
```

- Format: 48 kHz, mono, signed 16-bit little-endian. `primary_audio_policy_configuration.xml` declares the mic that way; Android resamples for apps that ask for other rates.
- The FIFO drains only while an app records. With no recorder, a feed blocks after the pipe buffer (about 0.7 s) fills; that audio plays when the next recording starts.
- Latency is about 20 ms (one HAL read period).

## Verify

`test/` has a minimal `AudioRecord` app (`micrec`, build with `test/micrec/build.sh`) and `test/verify.sh`, which records while feeding a file and checks the capture against the source by cross-correlation (`compare.py`).

## Files

| Path | What |
|---|---|
| `hal/audio_hw.c` | AOSP `hardware/libhardware/modules/audio/audio_hw.c` (android15-release) with the FIFO input |
| `hal/redroid-mic.patch` | The diff against the stock file |
| `primary_audio_policy_configuration.xml` | Mic declared as 48 kHz mono |
| `Dockerfile` | Two stages: compile the HAL, then copy it onto Redroid 15 |
| `fetch-aosp.sh` | Sparse-clones the AOSP headers the HAL needs |
| `feed-wav.sh` | Feeds any audio file into the FIFO |

## Limits

- One FIFO is shared by all recorders in the container.
- A writer that sends an odd number of bytes shifts samples; `feed-wav.sh` always sends whole samples.

## License

Apache License 2.0, the same as the AOSP file it modifies.
