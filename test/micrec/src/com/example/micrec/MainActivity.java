package com.example.micrec;

import android.Manifest;
import android.app.Activity;
import android.content.pm.PackageManager;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioRecord;
import android.os.Bundle;
import android.util.Log;
import java.io.File;
import java.io.RandomAccessFile;

/**
 * Minimal AudioRecord test app. Extras: src (int, MediaRecorder.AudioSource, default 1 = MIC),
 * secs (int, default 5), rate (int, default 48000), comm (bool: MODE_IN_COMMUNICATION like WebRTC).
 * Writes <external files dir>/rec.wav (mono s16) and logs "MICREC" lines.
 */
public class MainActivity extends Activity {
    static final String TAG = "MICREC";

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            start();
        } else {
            Log.i(TAG, "permission: requesting");
            requestPermissions(new String[]{Manifest.permission.RECORD_AUDIO}, 1);
        }
    }

    @Override public void onRequestPermissionsResult(int code, String[] p, int[] r) {
        boolean ok = r.length > 0 && r[0] == PackageManager.PERMISSION_GRANTED;
        Log.i(TAG, "permission: " + (ok ? "granted" : "denied"));
        if (ok) start();
    }

    void start() {
        final int src = getIntent().getIntExtra("src", 1);
        final int secs = getIntent().getIntExtra("secs", 5);
        final int rate = getIntent().getIntExtra("rate", 48000);
        if (getIntent().getBooleanExtra("comm", false))
            ((AudioManager) getSystemService(AUDIO_SERVICE)).setMode(AudioManager.MODE_IN_COMMUNICATION);
        new Thread(() -> record(src, secs, rate)).start();
    }

    void record(int src, int secs, int rate) {
        try {
            int min = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT);
            AudioRecord ar = new AudioRecord(src, rate, AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT, Math.max(min, rate / 5));
            byte[] pcm = new byte[rate * 2 * secs];
            ar.startRecording();
            Log.i(TAG, "recording src=" + src + " rate=" + rate + " secs=" + secs + " state=" + ar.getRecordingState());
            int off = 0;
            while (off < pcm.length) {
                int n = ar.read(pcm, off, Math.min(4096, pcm.length - off));
                if (n < 0) { Log.e(TAG, "read error " + n); break; }
                off += n;
            }
            ar.stop();
            ar.release();
            long sum = 0;
            for (int i = 0; i + 1 < off; i += 2) { int s = (short) ((pcm[i] & 0xff) | (pcm[i + 1] << 8)); sum += (long) s * s; }
            File f = new File(getExternalFilesDir(null), "rec.wav");
            writeWav(f, pcm, off, rate);
            Log.i(TAG, "done bytes=" + off + " rms=" + Math.round(Math.sqrt(sum / Math.max(1.0, off / 2.0))) + " file=" + f);
        } catch (Exception e) {
            Log.e(TAG, "failed", e);
        }
    }

    static void writeWav(File f, byte[] pcm, int len, int rate) throws Exception {
        try (RandomAccessFile w = new RandomAccessFile(f, "rw")) {
            w.setLength(0);
            w.writeBytes("RIFF"); w.writeInt(Integer.reverseBytes(36 + len)); w.writeBytes("WAVEfmt ");
            w.writeInt(Integer.reverseBytes(16)); w.writeShort(Short.reverseBytes((short) 1)); w.writeShort(Short.reverseBytes((short) 1));
            w.writeInt(Integer.reverseBytes(rate)); w.writeInt(Integer.reverseBytes(rate * 2));
            w.writeShort(Short.reverseBytes((short) 2)); w.writeShort(Short.reverseBytes((short) 16));
            w.writeBytes("data"); w.writeInt(Integer.reverseBytes(len)); w.write(pcm, 0, len);
        }
    }
}
