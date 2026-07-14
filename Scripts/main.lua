-- main.lua - SubtitleTTS Mod for The Outer World
local TTS = require("tts")

local lastConversationSubtitle = nil

--- Log a message
local function log(fmt, ...) print(string.format("[SubtitleTTS] " .. fmt, ...)) end


TTS.SetSpeaker("default", "fr-FR-HenriNeural", 3, 100, -3)
TTS.SetSpeaker("overlay", "fr-FR-DeniseNeural", 3, 50, 0)
TTS.Speak("SubtitleTTS mod initialized.")

--- @param widget UConversationSubtitleWidget_BP_C
NotifyOnNewObject("/Game/UI/Subtitles/ConversationSubtitleWidget_BP.ConversationSubtitleWidget_BP_C", function(widget)
    local handle = nil ---@type integer
    handle = LoopInGameThreadWithDelay(200, function()
        if not widget or not widget:IsValid() then
            CancelDelayedAction(handle)
            return
        end
        local subtitle = widget.Subtitle
        if not subtitle or not subtitle:IsValid() then return end
        
        -- filter hidden subtitles, based on the TextSizeBox visibility
        local textSize = subtitle.TextSizeBox
        if not textSize or not textSize:IsValid() or not textSize:IsVisible() then return end

        local textBlock = subtitle.MessageTextBlock
        if not textBlock or not textBlock:IsValid() then return end
        local text = textBlock.Text
        if not text or not text:IsValid() then return end
        local string = text:ToString()

        -- filter invalid and previosuly processed subtitle
        if not string or string:len() == 0 then return end
        if lastConversationSubtitle and lastConversationSubtitle == string then return end

        log("Subtitle text: %s", string)
        lastConversationSubtitle = string
        TTS.SpeakAs(string, "overlay")
    end)
end)


--> UConversationWidget
--- @param widget UConversationMessage_BP_C
NotifyOnNewObject("/Game/UI/Conversation/ConversationMessage_BP.ConversationMessage_BP_C", function(widget)
    local handle = nil ---@type integer
    handle = LoopInGameThreadWithDelay(200, function()
        if not widget or not widget:IsValid() then
            CancelDelayedAction(handle)
            return
        end

        if not widget:IsVisible() then return end

        local textBlock = widget.MessageTextBlock
        if not textBlock or not textBlock:IsValid() then return end
        local text = textBlock.Text
        if not text or not text:IsValid() then return end
        local string = text:ToString()

        -- filter invalid and previosuly processed subtitle
        if not string or string:len() == 0 then return end
        if lastConversationSubtitle and lastConversationSubtitle == string then return end

        log("Conversation text: %s", string)
        lastConversationSubtitle = string
        TTS.SpeakAs(string, "default")
    end)
end)


RegisterKeyBind(Key.END, { ModifierKey.CONTROL }, TTS.ResetPipe)
