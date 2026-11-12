#!/bin/bash
# Builds micrec.apk. Needs a JDK and an Android SDK (build-tools 36.x, platforms/android-35).
set -euo pipefail
cd "$(dirname "$0")"
SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"; BT=$(ls -d "$SDK"/build-tools/* | tail -1); JAR="$SDK/platforms/android-35/android.jar"
rm -rf out && mkdir -p out/classes
javac --release 11 -cp "$JAR" -d out/classes src/com/example/micrec/MainActivity.java
"$BT/d8" --release --min-api 26 --lib "$JAR" --output out $(find out/classes -name '*.class')
"$BT/aapt2" link -I "$JAR" --manifest AndroidManifest.xml -o out/base.apk
(cd out && zip -q base.apk classes.dex)
"$BT/zipalign" -f 4 out/base.apk out/aligned.apk
[ -f out/key.jks ] || keytool -genkeypair -keystore out/key.jks -storepass android -keypass android -alias k -keyalg RSA -dname CN=micrec -validity 10000 >/dev/null 2>&1
"$BT/apksigner" sign --ks out/key.jks --ks-pass pass:android --out micrec.apk out/aligned.apk
echo built micrec.apk
