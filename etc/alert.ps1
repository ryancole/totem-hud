# Builds the alert sounds, assets/totem-1.ogg to totem-3.ogg: the word
# "totem" spoken by three of Windows' built-in text-to-speech voices,
# encoded as they come. The only edit is trimming the silence the
# engine pads each side with, so the clip starts the instant it plays.
#
# Needs ffmpeg on PATH for the Ogg Vorbis encode. The voices are the
# stock en-US SAPI ones (Settings -> Time & language -> Speech).
#
# Usage: .\etc\alert.ps1 (works from any directory)

$voices = "Microsoft David", "Microsoft Mark", "Microsoft Zira"
$word = "Totem"

$assets = Join-Path (Split-Path $PSScriptRoot) "assets"
$tmp = Join-Path ([IO.Path]::GetTempPath()) "totem-hud-alert"
New-Item -ItemType Directory -Force $tmp | Out-Null

Add-Type -AssemblyName System.Speech
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer

$i = 0
foreach ($voice in $voices) {
    $i++
    $wav = Join-Path $tmp "totem-$i.wav"
    $ogg = Join-Path $assets "totem-$i.ogg"

    $synth.SelectVoice($voice)
    $synth.Rate = 0
    $synth.Volume = 100
    $synth.SetOutputToWaveFile($wav)
    $synth.Speak($word)
    $synth.SetOutputToNull() # closes the file

    # Trim leading silence, then the trailing silence by reversing
    $trim = "silenceremove=start_periods=1:start_threshold=-50dB"
    ffmpeg -v error -y -i $wav -af "$trim,areverse,$trim,areverse" -c:a libvorbis -q:a 6 $ogg
    if ($LASTEXITCODE -ne 0) { exit 1 }

    $length = ffprobe -v error -show_entries format=duration -of csv=p=0 $ogg
    $peak = (ffmpeg -i $ogg -af volumedetect -f null - 2>&1 | Select-String "max_volume").ToString().Split(":")[1].Trim()
    "wrote totem-$i.ogg ($voice): {0:N2} s, peak $peak" -f [double]$length
}
