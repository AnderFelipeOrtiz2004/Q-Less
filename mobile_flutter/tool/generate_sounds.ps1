# Generates short UI WAV files (royalty-free, generated locally).
param(
    [string]$OutDir = "$PSScriptRoot\..\assets\sounds"
)

function Write-SineWav {
    param(
        [string]$Path,
        [double[]]$Frequencies,
        [double[]]$DurationsMs,
        [double]$Volume = 0.25,
        [int]$SampleRate = 22050
    )

    $samples = New-Object System.Collections.Generic.List[int16]
    for ($i = 0; $i -lt $Frequencies.Length; $i++) {
        $freq = $Frequencies[$i]
        $count = [int]($SampleRate * ($DurationsMs[$i] / 1000.0))
        for ($n = 0; $n -lt $count; $n++) {
            $t = $n / $SampleRate
            $envelope = 1.0 - ($n / [double]$count)
            $value = [Math]::Sin(2 * [Math]::PI * $freq * $t) * $Volume * $envelope
            $samples.Add([int16]([Math]::Max(-32767, [Math]::Min(32767, $value * 32767))))
        }
    }

    $dataSize = $samples.Count * 2
    $fs = [System.IO.File]::Create($Path)
    $bw = New-Object System.IO.BinaryWriter($fs)
    $bw.Write([char[]]@('R','I','F','F'))
    $bw.Write([int](36 + $dataSize))
    $bw.Write([char[]]@('W','A','V','E'))
    $bw.Write([char[]]@('f','m','t',' '))
    $bw.Write([int]16)
    $bw.Write([Int16]1)
    $bw.Write([Int16]1)
    $bw.Write([int]$SampleRate)
    $bw.Write([int]($SampleRate * 2))
    $bw.Write([Int16]2)
    $bw.Write([Int16]16)
    $bw.Write([char[]]@('d','a','t','a'))
    $bw.Write([int]$dataSize)
    foreach ($s in $samples) { $bw.Write($s) }
    $bw.Close()
    $fs.Close()
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Write-SineWav -Path (Join-Path $OutDir 'click.wav') -Frequencies @(1200) -DurationsMs @(55) -Volume 0.18
Write-SineWav -Path (Join-Path $OutDir 'navigate.wav') -Frequencies @(640, 920) -DurationsMs @(45, 55) -Volume 0.16
Write-SineWav -Path (Join-Path $OutDir 'purchase.wav') -Frequencies @(880, 1175, 1480) -DurationsMs @(60, 60, 90) -Volume 0.22
Write-SineWav -Path (Join-Path $OutDir 'success.wav') -Frequencies @(740, 988, 1318) -DurationsMs @(70, 70, 120) -Volume 0.24
Write-SineWav -Path (Join-Path $OutDir 'edit.wav') -Frequencies @(520, 780) -DurationsMs @(50, 70) -Volume 0.17
Write-Host "Generated sounds in $OutDir"
