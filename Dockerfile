# redroid-mic:15 = stock Redroid 15 with a mic that reads PCM from /mic/mic.fifo.
# Build: ./build.sh (creates the mode-777 mic/ dir, fetches AOSP headers, runs docker build)
FROM ubuntu:24.04@sha256:2198e4c65076e9cb0b3d695219df667c0e3b0072da64ca3c2648aca17dcecaf5 AS build
RUN apt-get update && apt-get install -y --no-install-recommends clang lld curl ca-certificates unzip \
 && rm -rf /var/lib/apt/lists/*
# Only the NDK sysroot and compiler-rt builtins are used; the NDK's own clang is x86_64-only.
ARG NDK=android-ndk-r27c
RUN curl -fsSLo /ndk.zip https://dl.google.com/android/repository/${NDK}-linux.zip \
 && unzip -q /ndk.zip "${NDK}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/*" \
      "${NDK}/toolchains/llvm/prebuilt/linux-x86_64/lib/clang/*/lib/linux/libclang_rt.builtins-aarch64-android.a" -d / \
 && rm /ndk.zip && mv /${NDK}/toolchains/llvm/prebuilt/linux-x86_64 /ndk && rm -rf /${NDK}
COPY aosp /aosp
COPY hal /hal
RUN clang --target=aarch64-linux-android30 --sysroot=/ndk/sysroot -fuse-ld=lld \
      -shared -fPIC -O2 -DNDEBUG -Wall -Werror -Wno-unused-parameter \
      -I/aosp/libhardware/include_all -I/aosp/media/audio/include \
      -I/aosp/core/libcutils/include -I/aosp/core/libsystem/include -I/aosp/logging/liblog/include \
      -nodefaultlibs -Wl,-soname,audio.primary.default.so \
      -o /audio.primary.default.so /hal/audio_hw.c \
      -llog -lc -ldl /ndk/lib/clang/*/lib/linux/libclang_rt.builtins-aarch64-android.a

FROM redroid/redroid:15.0.0_64only-latest@sha256:b51bde9cef80f7bd7581148192f2b2f4d41f23c6344cfe88eceeb8ddd67490ee
COPY --from=build /audio.primary.default.so /vendor/lib64/hw/audio.primary.default.so
COPY primary_audio_policy_configuration.xml /vendor/etc/primary_audio_policy_configuration.xml
# mic/ is mode 777 in the build context; the legacy builder keeps file modes.
COPY mic /mic
