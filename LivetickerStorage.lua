-- ============================================================
-- FS25_LiveTickerStorage.lua
-- by Marcus (Cobra Modding)
-- 
--
-- Version 1.0.0.0
--
--
-- Keine Änderung am Skript ohne meine Erlaubnis
-- ============================================================

LivetickerStorage = {}
LivetickerStorage.notifications = {}

function LivetickerStorage.save(text, notificationType, uniqueKey)
    if text == nil or notificationType == nil then
        return
    end

    if LivetickerSystem == nil or notificationType < LivetickerSystem.TYPE_WARNING then
        return
    end

    if uniqueKey ~= nil then
        for _, entry in ipairs(LivetickerStorage.notifications) do
            if entry.uniqueKey == uniqueKey then
                return
            end
        end
    end

    table.insert(LivetickerStorage.notifications, {
        text = text,
        notificationType = notificationType,
        uniqueKey = uniqueKey
    })
end

function LivetickerStorage.showSaved()
    if LivetickerSystem == nil then
        return
    end

    for _, entry in ipairs(LivetickerStorage.notifications) do
        LivetickerSystem.push(entry.text, entry.notificationType, 8, entry.uniqueKey)
    end

    LivetickerStorage.notifications = {}
end

function LivetickerStorage.saveToXML(xmlFile)
    if xmlFile == nil then
        return
    end

    local index = 0
    for _, entry in ipairs(LivetickerStorage.notifications) do
        local key = string.format("notifications.notification(%d)", index)
        xmlFile:setString(key .. "#text", entry.text)
        xmlFile:setInt(key .. "#type", entry.notificationType)
        if entry.uniqueKey ~= nil then
            xmlFile:setString(key .. "#key", entry.uniqueKey)
        end
        index = index + 1
    end
end

function LivetickerStorage.loadFromXML(xmlFile)
    if xmlFile == nil then
        return
    end

    LivetickerStorage.notifications = {}
    local count = xmlFile:getNumOfChildren("notifications.notification")

    for i = 0, count - 1 do
        local key = string.format("notifications.notification(%d)", i)
        table.insert(LivetickerStorage.notifications, {
            text = xmlFile:getString(key .. "#text"),
            notificationType = xmlFile:getInt(key .. "#type", LivetickerSystem.TYPE_WARNING),
            uniqueKey = xmlFile:getString(key .. "#key")
        })
    end
end

ModNotificationStorage = LivetickerStorage
