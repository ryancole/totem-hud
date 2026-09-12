# Builds the alert sounds: "totem expired" as assets/expired.ogg, for
# a totem running out, "totem dead" as assets/dead.ogg, for one killed
# early, and "totem distance" as assets/distance.ogg, for the player
# leaving a totem's range. All are spoken by one of Windows' built-in
# text-to-speech voices, encoded as it comes. The only edit is trimming
# the silence the engine pads each side with, so the clip starts the
# instant it plays.
#
# Needs ffmpeg on PATH for the Ogg Vorbis encode. The voice is a stock
# en-US SAPI one (Settings -> Time & language -> Speech).
#
# Usage: .\etc\alert.ps1 (works from any directory)

$voice = "Microsoft David"
$phrases = @{ expired = "Totem expired"; dead = "Totem dead"; distance = "Totem distance" }

$assets = Join-Path (Split-Path $PSScriptRoot) "assets"
$tmp = Join-Path ([IO.Path]::GetTempPath()) "totem-hud-alert"
New-Item -ItemType Directory -Force $tmp | Out-Null

Add-Type -AssemblyName System.Speech
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$synth.SelectVoice($voice)
$synth.Rate = 0
$synth.Volume = 100

foreach ($name in $phrases.Keys | Sort-Object) {
    $wav = Join-Path $tmp "$name.wav"
    $ogg = Join-Path $assets "$name.ogg"

    $synth.SetOutputToWaveFile($wav)
    $synth.Speak($phrases[$name])
    $synth.SetOutputToNull() # closes the file

    # Trim leading silence, then the trailing silence by reversing
    $trim = "silenceremove=start_periods=1:start_threshold=-50dB"
    ffmpeg -v error -y -i $wav -af "$trim,areverse,$trim,areverse" -c:a libvorbis -q:a 6 $ogg
    if ($LASTEXITCODE -ne 0) { exit 1 }

    $length = ffprobe -v error -show_entries format=duration -of csv=p=0 $ogg
    $peak = (ffmpeg -i $ogg -af volumedetect -f null - 2>&1 | Select-String "max_volume").ToString().Split(":")[1].Trim()
    "wrote $name.ogg: {0:N2} s, peak $peak" -f [double]$length
}
