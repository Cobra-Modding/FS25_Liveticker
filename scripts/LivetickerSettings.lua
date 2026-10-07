-- ============================================================
-- FS25_LiveTickerSettings.lua
-- by Marcus (Cobra Modding)
-- 
--
-- Version 1.0.0.0
--
--
-- Keine Änderung am Skript ohne meine Erlaubnis
-- ============================================================

LivetickerSettings = {}
LivetickerSettings.VERSION = "1.0.0.0"
LivetickerSettings.basePath = getUserProfileAppPath() .. "modSettings/FS25_Liveticker/"
LivetickerSettings.filePath = LivetickerSettings.basePath .. "LivetickerBlacklist.xml"

local template = [[<?xml version="1.0" encoding="utf-8"?>
<livetickerBlacklist>
    <!-- enabled="true": Originalanzeige statt Liveticker -->
    <messages>
        <message contains="Bitte zunächst den Motor starten" enabled="true" />
    </messages>
</livetickerBlacklist>
]]

local function ensureFile()
    if not fileExists(LivetickerSettings.basePath) then
        createFolder(LivetickerSettings.basePath)
    end

    if not fileExists(LivetickerSettings.filePath) then
        local file = io.open(LivetickerSettings.filePath, "w")
        if file ~= nil then
            file:write(template)
            file:close()
        end
    end
end

function LivetickerSettings.load()
    ensureFile()

    if LivetickerVanillaBridge == nil then
        Logging.warning("[Liveticker] XML-Routing: Bridge nicht verfuegbar")
        return
    end

    LivetickerVanillaBridge.blacklistMessages = {}

    local xmlFile = loadXMLFile("LivetickerBlacklist", LivetickerSettings.filePath)
    if xmlFile == 0 then
        Logging.warning("[Liveticker] XML-Blacklist konnte nicht geladen werden")
        return
    end

    local index = 0
    while true do
        local key = string.format("livetickerBlacklist.messages.message(%d)", index)
        if not hasXMLProperty(xmlFile, key) then
            break
        end

        local text = getXMLString(xmlFile, key .. "#contains")
        local enabled = getXMLBool(xmlFile, key .. "#enabled")
        if text ~= nil and text ~= "" and enabled == true then
            table.insert(LivetickerVanillaBridge.blacklistMessages, text)
        end
        index = index + 1
    end

    delete(xmlFile)
end

LivetickerSettings.load()
