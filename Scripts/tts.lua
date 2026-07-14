-- tts.lua - TTS proxy to send command to SubtitleTTS server
local TTS = {}

--- Windows named pipe to send speech action to the TTS serveur
local pipe = nil
--- Global configuration for Speakers
local speakers = {
    default = { voice = "Microsoft Zira Desktop", rate = 0, volume = 100, pitch = 0 },
    overlay = { voice = "Microsoft Zira Desktop", rate = 0, volume = 50, pitch = 0 }
}

--- Log a message
local function log(fmt, ...) print(string.format("[SubtitleTTS][TTS] " .. fmt, ...)) end

function TTS.send_command(payload_table)
    local pipe_path = [[\\.\pipe\TheOuterWorlds_TTS_Pipe]]
    if not pipe then
        pipe = io.open(pipe_path, "w")
    end
    if not pipe then
        log("Cannot open named pipe %s", pipe_path)
        log("Did you launch the SubtitleTTS server?")
        return false
    end

    -- Sérialisation JSON ultra-simplifiée pour éviter une DLL cjson externe
    local json_parts = {}
    for k, v in pairs(payload_table) do
        if v then
            if type(v) == "number" then
                table.insert(json_parts, string.format('"%s":%s', k, v))
            else
                local safe_text = tostring(v)
                    :gsub('[%c]', '')
                    :gsub('["\\]', '')
                table.insert(json_parts, string.format('"%s":"%s"', k, safe_text))
            end
        end
    end
    local json_str = "{" .. table.concat(json_parts, ",") .. "}\n"

    pipe:write(json_str)
    pipe:flush()
    return true
end

--- Say the given text.
--- @param text     string Text to speech
--- @param voice?   string Voice name (see installed voice)
--- @param rate?    number Speech rate, i range -10..10
--- @param volume?  number Speech volum, in range 0..100
--- @param pitch    number Pitch modifier, in relative Hz, ex: -5, 10, -7
function TTS.Speak(text, voice, rate, volume, pitch)
    -- Avant de parler, on demande l'arrêt de la phrase précédente (réactivité)
    TTS.Stop()
    TTS.send_command({
        action = "speak",
        text = text,
        voice = voice or speakers.default.voice or nil,
        rate = rate or speakers.default.rate or 0,
        volume = volume or speakers.default.volume or 100,
        pitch = pitch or speakers.default.pitch or 0,
    })
end

--- Say the given text as speaker.
--- @param text     string Text to speech
--- @param speaker  string Speaker name (default, overlay)
function TTS.SpeakAs(text, speaker)
    TTS.Stop()
    TTS.send_command({
        action = "speak",
        text = text,
        voice = speakers[speaker].voice or nil,
        rate = speakers[speaker].rate or 0,
        volume = speakers[speaker].volume or 100,
        pitch = speakers[speaker].pitch or 0
    })
end

function TTS.Stop()
    TTS.send_command({ action = "stop" })
end

--- Say the default speaker voice, rate and volume.
--- @param speaker  string Speaker name (default, overlay)
--- @param voice    string Voice name (see installed voice)
--- @param rate     number Speech rate, i range -10..10
--- @param volume   number Speech volum, in range 0..100
--- @param pitch    number Pitch modifier, in relative Hz, ex: -5, 10, -7
function TTS.SetSpeaker(speaker, voice, rate, volume, pitch)
    if speaker == "default" then
        speakers.default = { voice = voice, rate = rate, volume = volume, pitch = pitch }
    elseif speaker == "overlay" then
        speakers.overlay = { voice = voice, rate = rate, volume = volume, pitch = pitch }
    end
end

function TTS.ResetPipe()
    pipe = nil
end

return TTS
