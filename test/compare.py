"""compare.py <source.wav> <captured.wav> <rec_start_epoch> <feed_start_epoch>
Finds the source inside the capture by cross-correlation and prints level, spectrum and match numbers."""
import sys, wave
import numpy as np

def load(p):
    with wave.open(p) as w:
        assert w.getsampwidth() == 2 and w.getnchannels() == 1, p
        return w.getframerate(), np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(np.float64)

def db(x): return 20 * np.log10(max(np.sqrt(np.mean(x ** 2)), 1e-9) / 32768)

rs, src = load(sys.argv[1]); rc, cap = load(sys.argv[2])
assert rs == rc == 48000, (rs, rc)
n = 1 << int(np.ceil(np.log2(len(src) + len(cap))))
xc = np.fft.irfft(np.fft.rfft(cap, n) * np.conj(np.fft.rfft(src, n)), n)
lag = int(np.argmax(xc[: len(cap)]))
seg = cap[lag: lag + len(src)]
s = src[: len(seg)]
corr = float(np.dot(seg, s) / np.sqrt(np.dot(seg, seg) * np.dot(s, s)))
err = seg - s
peak = lambda x: np.fft.rfftfreq(len(x), 1 / 48000)[np.argmax(np.abs(np.fft.rfft(x * np.hanning(len(x)))))]
outside = np.concatenate([cap[:lag], cap[lag + len(src):]])
print(f"source  : {len(src)/48000:.3f}s rms {db(src):.2f} dBFS peak-freq {peak(src):.1f} Hz")
print(f"captured: offset {lag/48000*1000:.1f} ms into recording, rms {db(seg):.2f} dBFS peak-freq {peak(seg):.1f} Hz")
print(f"match   : normalized correlation {corr:.6f}, residual {db(err):.1f} dBFS, max |diff| {np.max(np.abs(err)):.0f} LSB")
print(f"outside : rms {db(outside):.1f} dBFS (should be silence)")
latency = lag / 48000 - (float(sys.argv[4]) - float(sys.argv[3]))
print(f"latency : ~{latency*1000:.0f} ms from feed start to audio in AudioRecord (rough, includes adb/logcat timing)")
