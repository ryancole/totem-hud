# Builds assets/tote.ogg, the expiry sound, from a voice recording of the
# word "tote". The raw word is trimmed and cleaned, then made into a game
# alert: pitched down and thickened with a sub-octave and a chorused
# layer, lightly bit-crushed, led in by a short two-note chime, and sent
# through a synthetic room reverb. Peak-normalized at the end.
#
# Needs ffmpeg on PATH (the Gyan "full" build: rubberband, acrusher,
# chorus, afir). The chime and the reverb's impulse response are
# synthesized here, so the recording is the only input.
#
# Usage: python etc/tote.py "C:\path\to\Recording.m4a"
#
# The trim points are fixed for the one recording this was cut from
# (speech at 0.81-1.20 s over a -62 dB floor); re-check them with an
# envelope plot if the source changes.
import math
import os
import random
import struct
import subprocess
import sys
import tempfile
import wave

RATE = 44100
TRIM_START, TRIM_END = 0.790, 1.200

# Voice layers (rubberband pitch ratios; 0.84 is about -3 semitones)
PITCH = 0.84
SUB_PITCH = PITCH / 2   # an octave under the main layer
SUB_GAIN = 0.45
CHORUS_GAIN = 0.7
CRUSH_BITS = 9          # acrusher bit depth; lower is grittier
CRUSH_MIX = 0.35        # how much of the crushed signal is blended in

# Lead-in chime: two sine notes, each a short decaying burst
CHIME_NOTES = [(1046.5, 0.00), (1568.0, 0.09)]  # (Hz, start s): C6 then G6
CHIME_LENGTH = 0.22     # each note's length
CHIME_DECAY = 18.0      # per-second exponential decay of each note
CHIME_GAIN = 0.55
VOICE_DELAY_MS = 110    # voice starts this far after the chime

# Reverb: decaying, darkening noise convolved in with afir
REVERB_SECONDS = 0.9
REVERB_DECAY = 5.0      # 1/e time constant in tails per second; higher = shorter
REVERB_DARKEN = 0.3     # one-pole lowpass coefficient on the tail (0 = none)
DRY, WET = 7, 4         # afir mix gains, 0-10

TARGET_PEAK_DB = -1.0

ASSETS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
OUT = os.path.join(ASSETS, "tote.ogg")


def run(args):
    return subprocess.run(args, capture_output=True, text=True)


def ffmpeg(*args):
    r = run(["ffmpeg", "-v", "error", "-y", *args])
    if r.returncode:
        sys.exit(r.stderr)


def write_wav(path, samples):
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(frames)


def write_impulse(path):
    """Decaying white noise, lowpassed so the tail darkens like a room."""
    random.seed(7)  # same tail every build
    n = int(RATE * REVERB_SECONDS)
    out = []
    y = 0.0
    for i in range(n):
        env = math.exp(-REVERB_DECAY * i / RATE)
        x = random.uniform(-1, 1) * env
        y = y + REVERB_DARKEN * (x - y)  # one-pole lowpass
        out.append(y)
    write_wav(path, out)


def write_chime(path):
    """Two short sine bursts with a fast exponential decay, plus a touch of
    second harmonic so they ring rather than beep."""
    end = max(start for _, start in CHIME_NOTES) + CHIME_LENGTH
    n = int(RATE * end)
    out = [0.0] * n
    for freq, start in CHIME_NOTES:
        s0 = int(RATE * start)
        for i in range(int(RATE * CHIME_LENGTH)):
            t = i / RATE
            env = math.exp(-CHIME_DECAY * t) * min(1.0, t / 0.004)  # 4 ms attack
            out[s0 + i] += env * (math.sin(2 * math.pi * freq * t)
                                  + 0.25 * math.sin(2 * math.pi * 2 * freq * t))
    peak = max(abs(s) for s in out)
    write_wav(path, [s / peak * CHIME_GAIN for s in out])


def peak_db(path):
    r = run(["ffmpeg", "-i", path, "-af", "volumedetect", "-f", "null", "-"])
    for line in r.stderr.splitlines():
        if "max_volume" in line:
            return float(line.split("max_volume:")[1].split("dB")[0])
    raise RuntimeError("no peak reported:\n" + r.stderr)


def main(src):
    tmp = tempfile.mkdtemp()
    ir = os.path.join(tmp, "ir.wav")
    chime = os.path.join(tmp, "chime.wav")
    dry = os.path.join(tmp, "dry.wav")
    voice = os.path.join(tmp, "voice.wav")
    mixed = os.path.join(tmp, "mixed.wav")
    wet = os.path.join(tmp, "wet.wav")
    write_impulse(ir)
    write_chime(chime)

    # 1. The word alone: trim, drop rumble, soft edges, then a compressor
    #    so the consonants and vowel sit closer together
    ffmpeg("-i", src, "-ac", "1", "-ar", str(RATE), "-af", ",".join([
        f"atrim=start={TRIM_START}:end={TRIM_END}",
        "asetpts=PTS-STARTPTS",
        "highpass=f=80",
        "afade=t=in:st=0:d=0.015",
        f"afade=t=out:st={TRIM_END - TRIM_START - 0.08}:d=0.08",
        "acompressor=threshold=-20dB:ratio=4:attack=4:release=90:makeup=3",
    ]), dry)

    # 2. Three layers of the word: pitched down, an octave under that,
    #    and a chorused copy for width; summed, then lightly crushed
    ffmpeg("-i", dry, "-filter_complex", ";".join([
        "[0]asplit=3[a][b][c]",
        f"[a]rubberband=pitch={PITCH}[main]",
        f"[b]rubberband=pitch={SUB_PITCH},lowpass=f=900,volume={SUB_GAIN}[sub]",
        f"[c]rubberband=pitch={PITCH},chorus=0.6:0.9:45|60:0.4|0.32:0.25|0.4:2|1.3,volume={CHORUS_GAIN}[ch]",
        "[main][sub][ch]amix=inputs=3:normalize=0,"
        f"acrusher=bits={CRUSH_BITS}:mode=log:aa=1:mix={CRUSH_MIX}[v]",
    ]), "-map", "[v]", voice)

    # 3. Chime first, the voice a beat behind it, and silence after for
    #    the reverb tail
    ffmpeg("-i", chime, "-i", voice, "-filter_complex",
           f"[1]adelay={VOICE_DELAY_MS}:all=1[d];[0][d]amix=inputs=2:normalize=0,apad=pad_dur={REVERB_SECONDS}[m]",
           "-map", "[m]", mixed)

    # 4. Reverb: convolve with the impulse response, mixing dry and wet
    ffmpeg("-i", mixed, "-i", ir, "-filter_complex", f"[0][1]afir=dry={DRY}:wet={WET}", wet)

    # 5. Normalize the peak, drop the dead air after the tail, and encode
    gain = TARGET_PEAK_DB - peak_db(wet)
    ffmpeg("-i", wet, "-af", ",".join([
        f"volume={gain:.2f}dB",
        "silenceremove=stop_periods=1:stop_threshold=-55dB:stop_duration=0.05",
    ]), "-c:a", "libvorbis", "-q:a", "6", OUT)
    print(f"wrote {OUT}: gain {gain:+.1f} dB, peak now {peak_db(OUT):.1f} dB")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: python etc/tote.py <recording>")
    main(sys.argv[1])
