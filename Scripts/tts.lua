-- tts.lua - TTS proxy to send command to SubtitleTTS server
local TTS = {}

--- Windows named pipe to send speech action to the TTS serveur
local pipe = nil

--- Global configuration for Voices
local speechVoices = {
    default = { voice = "Microsoft Zira Desktop", rate = 0, volume = 100, pitch = 0 },
    overlay = { voice = "Microsoft Zira Desktop", rate = 0, volume = 50, pitch = 0 }
}

--- Minimum pitch value return by procedural RNG
local RNG_PITCH_VAR_MIN = -10 -- Hz
--- Maximum pitch value return by procedural RNG
local RNG_PITCH_VAR_MAX = 10  -- Hz
--- List of supported voices return by procedural RNG
local RNG_VOICES = { "Microsoft Zira Desktop" }

---@class NpcVoiceConfig
---@field voice? string Le nom de la voix
---@field pitch? integer Le pitch en Hz

--- List of associated speaker => { voice, pitch }, override procedural RNG
---@type table<string, NpcVoiceConfig>
local NPC_VOICES = {}

--- Log a message
local function log(fmt, ...) print(string.format("[SubtitleTTS][TTS] " .. fmt .. "\n", ...)) end

--- Return hash based on a given string
--- Used a Procedural RNG
local function hash_string(str)
    local hash = 2166136261 -- Fowler–Noll–Vo offset basis
    for i = 1, #str do
        local char = string.byte(str, i)
        hash = (hash ~ char) * 16777619
        hash = hash & 0xFFFFFFFF -- Conserve un format 32-bit
    end
    return hash
end

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
        voice = voice or speechVoices.default.voice or nil,
        rate = rate or speechVoices.default.rate or 0,
        volume = volume or speechVoices.default.volume or 100,
        pitch = pitch or speechVoices.default.pitch or 0,
    })
end

--- Say the given text as speaker.
--- @param text         string Text to speech
--- @param speechVoice  string Speech voice (default, overlay)
--- @param speaker?     string Speaker name if any
function TTS.SpeakAs(text, speechVoice, speaker)
    local voice = speechVoices[speechVoice].voice or nil
    local pitch = speechVoices[speechVoice].pitch or 0
    -- Inject procedural RNG, usign speaker name as seed, overriden by hardcoded NPC_VOICES
    if speaker then
        local seed = hash_string(speaker)
        if NPC_VOICES[speaker] and NPC_VOICES[speaker].voice then
            voice = NPC_VOICES[speaker].voice
        else
            local voice_index = (seed % #RNG_VOICES) + 1
            voice = RNG_VOICES[voice_index]
        end
        if NPC_VOICES[speaker] and NPC_VOICES[speaker].pitch then
            pitch = NPC_VOICES[speaker].pitch
        else
            local pitch_factor = ((seed >> 5) % 1000) / 1000
            pitch = math.floor(RNG_PITCH_VAR_MIN + (pitch_factor * (RNG_PITCH_VAR_MAX - RNG_PITCH_VAR_MIN)))
        end
    end

    TTS.Stop()
    TTS.send_command({
        action = "speak",
        text = text,
        voice = voice,
        rate = speechVoices[speechVoice].rate or 0,
        volume = speechVoices[speechVoice].volume or 100,
        pitch = pitch or 0
    })
end

function TTS.Stop()
    TTS.send_command({ action = "stop" })
end

--- Set the default speaker voice, rate and volume.
--- @param speechVoice  string Speech voice (default, overlay)
--- @param voice        string Voice name (see installed voice)
--- @param rate         number Speech rate, i range -10..10
--- @param volume       number Speech volum, in range 0..100
--- @param pitch        number Pitch modifier, in relative Hz, ex: -5, 10, -7
function TTS.SetSpeechVoice(speechVoice, voice, rate, volume, pitch)
    if speechVoice == "default" then
        speechVoices.default = { voice = voice, rate = rate, volume = volume, pitch = pitch }
    elseif speechVoice == "overlay" then
        speechVoices.overlay = { voice = voice, rate = rate, volume = volume, pitch = pitch }
    end
end

--- Set list of voices used by the Procedural RNG
--- @param voices   string[] list of voices
function TTS.SetRandomVoices(voices)
    RNG_VOICES = voices
end

--- Set NPC Voices, in format {speaker name = { voice = "voice name", pitch = 123 }}
--- @param voices   table<string, NpcVoiceConfig> list of NPC voices
function TTS.SetNPCVoices(voices)
    NPC_VOICES = voices
end

function TTS.ResetPipe()
    pipe = nil
end

return TTS
