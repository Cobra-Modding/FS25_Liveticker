-- ============================================================
-- FS25_LiveTickerSystem.lua
-- by Marcus (Cobra Modding)
-- 
--
-- Version 1.0.0.0
--
--
-- Keine Änderung am Skript ohne meine Erlaubnis
-- ============================================================

LivetickerSystem = {}

LivetickerSystem.TYPE_INFO = 1
LivetickerSystem.TYPE_WARNING = 2
LivetickerSystem.TYPE_CRITICAL = 3
LivetickerSystem.queue = {}
LivetickerSystem.activeNotification = nil
LivetickerSystem.timer = 0
LivetickerSystem.elapsed = 0
LivetickerSystem.defaultDuration = 5
LivetickerSystem.posX = 0.245
LivetickerSystem.posY = 0.925
LivetickerSystem.width = 0.405
LivetickerSystem.height = 0.042
LivetickerSystem.paddingX = 0.012
LivetickerSystem.textSize = 0.021
LivetickerSystem.accentWidth = 0.004
LivetickerSystem.fadeTime = 0.25
LivetickerSystem.scrollStartDelay = 1.0
LivetickerSystem.scrollEndDelay = 0.55
LivetickerSystem.scrollSpeed = 0.055 
LivetickerSystem.scrollExitPadding = 0.035 

LivetickerSystem.backgroundOverlay = nil
LivetickerSystem.accentOverlay = nil

local function clamp01(value)
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

function LivetickerSystem.getTypeColor(notificationType)
    if notificationType == LivetickerSystem.TYPE_CRITICAL then
        return 0.95, 0.18, 0.12, 1
    end

    if notificationType == LivetickerSystem.TYPE_WARNING then
        return 1.00, 0.62, 0.08, 1
    end

    if HUD ~= nil and HUD.COLOR ~= nil and HUD.COLOR.ACTIVE ~= nil then
        local c = HUD.COLOR.ACTIVE
        return c[1] or 0.55, c[2] or 0.85, c[3] or 0.10, c[4] or 1
    end

    return 0.55, 0.85, 0.10, 1
end

function LivetickerSystem.push(text, notificationType, duration, uniqueKey)
    if text == nil then
        return
    end

    text = tostring(text)
    if text == "" then
        return
    end

    notificationType = notificationType or LivetickerSystem.TYPE_INFO
    duration = duration or LivetickerSystem.defaultDuration

    if uniqueKey ~= nil then
        for _, entry in ipairs(LivetickerSystem.queue) do
            if entry.uniqueKey == uniqueKey then
                return
            end
        end

        if LivetickerSystem.activeNotification ~= nil
            and LivetickerSystem.activeNotification.uniqueKey == uniqueKey then
            return
        end
    end

    local notification = {
        text = text,
        notificationType = notificationType,
        priority = notificationType,
        duration = duration,
        uniqueKey = uniqueKey,
        isScrolling = false,
        textWidth = 0,
        scrollDistance = 0,
        scrollDuration = 0,
        totalDuration = duration
    }

    if LivetickerStorage ~= nil then
        LivetickerStorage.save(text, notificationType, uniqueKey)
    end

    table.insert(LivetickerSystem.queue, notification)
end

function LivetickerSystem.getNext()
    if #LivetickerSystem.queue == 0 then
        return nil
    end
    return table.remove(LivetickerSystem.queue, 1)
end

function LivetickerSystem.prepareNotification(notification)
    local availableWidth = LivetickerSystem.width
        - LivetickerSystem.paddingX * 2
        - LivetickerSystem.accentWidth

    setTextBold(true)
    notification.textWidth = getTextWidth(LivetickerSystem.textSize, notification.text)
    setTextBold(false)

    notification.isScrolling = true

    notification.scrollDistance = availableWidth
        + notification.textWidth
        + LivetickerSystem.scrollExitPadding

    local scrollDuration = notification.scrollDistance / LivetickerSystem.scrollSpeed
    notification.scrollDuration = scrollDuration
    notification.totalDuration = LivetickerSystem.fadeTime
        + LivetickerSystem.scrollStartDelay
        + scrollDuration
        + LivetickerSystem.scrollEndDelay
        + LivetickerSystem.fadeTime
end

function LivetickerSystem:update(dt)
    local dtSeconds = dt / 1000

    if LivetickerSystem.activeNotification ~= nil then
        LivetickerSystem.timer = LivetickerSystem.timer - dtSeconds
        LivetickerSystem.elapsed = LivetickerSystem.elapsed + dtSeconds

        if LivetickerSystem.timer <= 0 then
            LivetickerSystem.activeNotification = nil
            LivetickerSystem.elapsed = 0
        end
    end

    if LivetickerSystem.activeNotification == nil then
        local nextNotification = LivetickerSystem.getNext()
        if nextNotification ~= nil then
            LivetickerSystem.prepareNotification(nextNotification)
            LivetickerSystem.activeNotification = nextNotification
            LivetickerSystem.timer = nextNotification.totalDuration
            LivetickerSystem.elapsed = 0
        end
    end
end

function LivetickerSystem.getAlpha(notification)
    local elapsed = LivetickerSystem.elapsed
    local remaining = LivetickerSystem.timer

    local fadeIn = clamp01(elapsed / LivetickerSystem.fadeTime)
    local fadeOut = clamp01(remaining / LivetickerSystem.fadeTime)
    return math.min(fadeIn, fadeOut)
end

function LivetickerSystem:draw()
    local notification = LivetickerSystem.activeNotification
    if notification == nil then
        return
    end

    local x = LivetickerSystem.posX
    local y = LivetickerSystem.posY
    local w = LivetickerSystem.width
    local h = LivetickerSystem.height
    local alpha = LivetickerSystem.getAlpha(notification)

    if LivetickerSystem.backgroundOverlay ~= nil then
        local br, bg, bb = 0.035, 0.045, 0.040
        local ba = 0.82
        if HUD ~= nil and HUD.COLOR ~= nil and HUD.COLOR.BACKGROUND ~= nil then
            local c = HUD.COLOR.BACKGROUND
            br, bg, bb, ba = c[1] or br, c[2] or bg, c[3] or bb, c[4] or ba
        end
        LivetickerSystem.backgroundOverlay:setPosition(x, y)
        LivetickerSystem.backgroundOverlay:setDimension(w, h)
        LivetickerSystem.backgroundOverlay:setColor(br, bg, bb, ba * alpha)
        LivetickerSystem.backgroundOverlay:render()
    end

    if LivetickerSystem.accentOverlay ~= nil then
        local r, g, b, a = 0.55, 0.85, 0.10, 1
        if HUD ~= nil and HUD.COLOR ~= nil and HUD.COLOR.ACTIVE ~= nil then
            local c = HUD.COLOR.ACTIVE
            r, g, b, a = c[1] or r, c[2] or g, c[3] or b, c[4] or a
        end

        LivetickerSystem.accentOverlay:setPosition(x, y)
        LivetickerSystem.accentOverlay:setDimension(LivetickerSystem.accentWidth, h)
        LivetickerSystem.accentOverlay:setColor(r, g, b, a * alpha)
        LivetickerSystem.accentOverlay:render()
    end

    local left = x + LivetickerSystem.accentWidth + LivetickerSystem.paddingX
    local right = x + w - LivetickerSystem.paddingX
    local bottom = y + 0.002
    local top = y + h - 0.002
    local centerX = (left + right) * 0.5
    local centerY = y + h * 0.5 + 0.001

    setTextClipArea(left, bottom, right, top)
    setTextColor(1, 1, 1, alpha)
    setTextBold(true)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)

    if notification.isScrolling then
        setTextAlignment(RenderText.ALIGN_LEFT)

        local startX = right
        local scrollingElapsed = math.max(
            0,
            LivetickerSystem.elapsed - LivetickerSystem.fadeTime - LivetickerSystem.scrollStartDelay
        )
        if scrollingElapsed <= notification.scrollDuration then
            local textX = startX - scrollingElapsed * LivetickerSystem.scrollSpeed
            renderText(textX, centerY, LivetickerSystem.textSize, notification.text)
        end
    else
        setTextAlignment(RenderText.ALIGN_CENTER)
        renderText(centerX, centerY, LivetickerSystem.textSize, notification.text)
    end

    setTextClipArea(0, 0, 1, 1)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(false)
    setTextColor(1, 1, 1, 1)
end

function LivetickerSystem:loadMap()
    if g_overlayManager ~= nil then
        LivetickerSystem.backgroundOverlay = g_overlayManager:createOverlay(
            "gui.rectangle_center",
            LivetickerSystem.posX,
            LivetickerSystem.posY,
            LivetickerSystem.width,
            LivetickerSystem.height
        )

        LivetickerSystem.accentOverlay = g_overlayManager:createOverlay(
            "gui.rectangle_center",
            LivetickerSystem.posX,
            LivetickerSystem.posY,
            LivetickerSystem.accentWidth,
            LivetickerSystem.height
        )
    end

    if LivetickerStorage ~= nil then
        LivetickerStorage.showSaved()
    end
end

function LivetickerSystem:deleteMap()
    if LivetickerSystem.backgroundOverlay ~= nil then
        LivetickerSystem.backgroundOverlay:delete()
        LivetickerSystem.backgroundOverlay = nil
    end
    if LivetickerSystem.accentOverlay ~= nil then
        LivetickerSystem.accentOverlay:delete()
        LivetickerSystem.accentOverlay = nil
    end
end

ModNotificationSystem = LivetickerSystem

addModEventListener(LivetickerSystem)
