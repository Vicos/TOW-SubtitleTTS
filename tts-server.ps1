# SubtitleTTS mod server for The Outer Worlds

$pipeName = "TheOuterWorlds_TTS_Pipe"
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer


Write-Host "SubtitleTTS mod server for The Outer Worlds." -ForegroundColor Green


# Generate PromptBuilder with voice details
# This is mainly a workaround: $synth.SelectVoice is not able to find all installed voices
function Build-TTSPrompt {
    param (
        [string]$text,
        [string]$voice,
        [int]$rate = 0, # -10..10
        [int]$volume = 10, # 0..100
        [string]$pitch = "medium" # "x-high", "high", "medium", "low", "x-low"
    )
    $synth.Rate = $rate; $synth.Volume = $volume
    $pb = New-Object System.Speech.Synthesis.PromptBuilder
    
    $vObj = $synth.GetInstalledVoices() | Where-Object { $_.VoiceInfo.Name -like "*$voice*" } | Select-Object -First 1
    if ($vObj) { $pb.StartVoice($vObj.VoiceInfo) }
    [void]$pb.AppendSsmlMarkup("<prosody pitch='$pitch'>")
    [void]$pb.AppendText($text)
    [void]$pb.AppendSsmlMarkup("</prosody>")
    if ($vObj) { $pb.EndVoice() }

    Write-Host $pb.ToXml()

    return $pb
}


Write-Host "Available Voices:" -ForegroundColor Yellow
$synth.GetInstalledVoices() | 
Select-Object -ExpandProperty VoiceInfo | 
Format-Table Name, Culture -AutoSize

while ($true) {
    Write-Host "Listening '\\.\pipe\$pipeName'..." -ForegroundColor Green
    $pipe = New-Object System.IO.Pipes.NamedPipeServerStream($pipeName, [System.IO.Pipes.PipeDirection]::In)
    try {
        $pipe.WaitForConnection()
        $reader = New-Object System.IO.StreamReader($pipe)
        
        while (!$reader.EndOfStream) {
            $jsonRaw = $reader.ReadLine()
            if ($jsonRaw) {
                $data = $jsonRaw | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($null -eq $data) { continue }

                switch ($data.action) {
                    "speak" {
                        Write-Host "Speak command: $data" -ForegroundColor Gray
                        $r = if ($data.rate) { $data.rate } else { 0 }
                        $v = if ($data.volume) { $data.volume } else { 100 }
                        $p = if ($data.pitch) { $data.pitch } else { "medium" }
                        $prompt = Build-TTSPrompt $data.text $data.voice $r $v $p
                        
                        Write-Host "[TTS] Speaking: $($data.text)" -ForegroundColor Cyan
                        [void]$synth.SpeakAsync($prompt)
                    }
                    
                    "stop" {
                        Write-Host "[TTS] Stop speaking" -ForegroundColor Yellow
                        $synth.SpeakAsyncCancelAll()
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Error: $_"
    }
    finally {
        $pipe.Dispose()
    }
}
