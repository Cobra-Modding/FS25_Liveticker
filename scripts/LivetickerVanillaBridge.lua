-- ============================================================
-- FS25_LiveTickerVanillaBridge.lua
-- by Marcus (Cobra Modding)
-- 
--
-- Version 1.0.0.0
--
--
-- Keine Änderung am Skript ohne meine Erlaubnis
-- ============================================================

LivetickerVanillaBridge = {}
LivetickerVanillaBridge.VERSION = "1.0.0"
LivetickerVanillaBridge.hideOriginal = true
LivetickerVanillaBridge.installed = false
LivetickerVanillaBridge.lastMessageTimes = {}
LivetickerVanillaBridge.messageCooldownMs = 15000
LivetickerVanillaBridge.moneyChanges = {}
LivetickerVanillaBridge.lastMoneyCapture = {}
LivetickerVanillaBridge.moneyCaptureDedupMs = 100
LivetickerVanillaBridge.originals = {}
LivetickerVanillaBridge.blacklistMessages = {}
LivetickerVanillaBridge.blacklistMods = {}
LivetickerVanillaBridge.forceOriginal = false

local function getNowMs()
    if g_time ~= nil then
        return g_time
    end
    return 0
end

local function getType(name, fallback)
    if LivetickerSystem ~= nil and LivetickerSystem[name] ~= nil then
        return LivetickerSystem[name]
    end
    return fallback
end

local function trim(value)
    if value == nil then
        return ""
    end
    return tostring(value):match("^%s*(.-)%s*$") or ""
end

local function joinText(...)
    local result = {}
    local seen = {}

    for i = 1, select("#", ...) do
        local value = trim(select(i, ...))
        if value ~= "" and not seen[value] then
            table.insert(result, value)
            seen[value] = true
        end
    end

    return table.concat(result, " - ")
end

local function getCallingModName()
    if debug == nil or debug.getinfo == nil then
        return nil
    end

    for level = 3, 12 do
        local ok, info = pcall(debug.getinfo, level, "S")
        local source = ok and info ~= nil and info.source or nil
        if source ~= nil then
            local normalized = tostring(source):gsub("\\", "/")
            local modName = normalized:match("/mods/([^/]+)/")
            if modName ~= nil
                and modName ~= ""
                and string.find(modName, "FS25_Liveticker", 1, true) ~= 1 then
                return modName
            end
        end
    end

    return nil
end

function LivetickerVanillaBridge.isBlacklistedMessage(text)
    text = trim(text)
    for _, blockedText in ipairs(LivetickerVanillaBridge.blacklistMessages) do
        if blockedText ~= "" and string.find(text, blockedText, 1, true) ~= nil then
            return true
        end
    end
    return false
end

function LivetickerVanillaBridge.isBlacklistedMod(modName)
    return modName ~= nil
        and LivetickerVanillaBridge.blacklistMods[tostring(modName)] == true
end

function LivetickerVanillaBridge.shouldForward(channel, text)
    text = trim(text)
    if text == "" then
        return false
    end

    local key = text
    local now = getNowMs()
    local lastTime = LivetickerVanillaBridge.lastMessageTimes[key]

    if lastTime ~= nil and now > 0
        and (now - lastTime) < LivetickerVanillaBridge.messageCooldownMs then
        return false
    end

    LivetickerVanillaBridge.lastMessageTimes[key] = now
    return true
end

function LivetickerVanillaBridge.getNotificationType(fsType)
    local infoType = getType("TYPE_INFO", 1)

    if FSBaseMission ~= nil then
        if FSBaseMission.INGAME_NOTIFICATION_CRITICAL ~= nil
            and fsType == FSBaseMission.INGAME_NOTIFICATION_CRITICAL then
            return getType("TYPE_CRITICAL", infoType)
        end

        if FSBaseMission.INGAME_NOTIFICATION_OK ~= nil
            and fsType == FSBaseMission.INGAME_NOTIFICATION_OK then
            return getType("TYPE_SUCCESS", infoType)
        end
    end

    return infoType
end

function LivetickerVanillaBridge.pushToTicker(text, notificationType, channel, duration, sourceMod)
    text = trim(text)
    if text == "" then
        return false
    end

    if LivetickerSystem == nil or LivetickerSystem.push == nil then
        Logging.warning("[Liveticker] Bridge: LivetickerSystem.push nicht verfuegbar")
        return false
    end

    sourceMod = sourceMod or getCallingModName()

    if LivetickerVanillaBridge.isBlacklistedMod(sourceMod) then
        return false
    end

    if LivetickerVanillaBridge.isBlacklistedMessage(text) then
        return false
    end

    if not LivetickerVanillaBridge.shouldForward(channel, text) then
        return true
    end

    LivetickerSystem.push(text, notificationType or getType("TYPE_INFO", 1), duration or 6, nil)
    return true
end

function LivetickerVanillaBridge.getMoneyType(amount)
    local infoType = getType("TYPE_INFO", 1)
    if amount ~= nil then
        if amount > 0 then
            return getType("TYPE_SUCCESS", infoType)
        elseif amount < 0 then
            return getType("TYPE_WARNING", infoType)
        end
    end
    return infoType
end

function LivetickerVanillaBridge.formatMoney(amount)
    if amount == nil then
        return nil
    end

    local sign = ""

    if amount > 0 then
        sign = "+"
    elseif amount < 0 then
        sign = "-"
    end

    local absoluteAmount = math.abs(amount)
    local formattedAmount

    if g_i18n ~= nil and g_i18n.formatNumber ~= nil then
        formattedAmount = g_i18n:formatNumber(
            absoluteAmount,
            0,
            true
        )
    else
        formattedAmount = string.format("%.0f", absoluteAmount)
    end

    return string.format(
        "%s%s €",
        sign,
        formattedAmount
    )
end

LivetickerVanillaBridge.moneyLabelFallbacks = {
    finance_harvestIncome = "Ernteverkauf",
    finance_newVehicles = "Fahrzeugkauf",
    finance_soldVehicles = "Fahrzeugverkauf",
    finance_vehicleRunningCost = "Fahrzeugkosten",
    finance_vehicleLeasingCost = "Leasingkosten",
    finance_vehicleRepair = "Reparaturkosten",
    finance_wagePayment = "Helferkosten",
    finance_propertyMaintenance = "Unterhaltskosten",
    finance_purchaseSeeds = "Saatgutkauf",
    finance_purchaseFertilizer = "Duengerkauf",
    finance_purchaseSaplings = "Setzlingskauf",
    finance_purchaseWater = "Wasserkauf",
    finance_purchaseFuel = "Kraftstoffkauf",
    finance_purchaseManure = "Mistkauf",
    finance_purchaseSlurry = "Guellekauf",
    finance_purchaseDigestate = "Gaerrestkauf",
    finance_purchaseLime = "Kalkkauf",
    finance_purchaseHerbicide = "Herbizidkauf",
    finance_purchaseAnimal = "Tierkauf",
    finance_soldAnimals = "Tierverkauf",
    finance_incomeBga = "BGA-Einnahmen",
    finance_missionIncome = "Auftragseinnahmen",
    finance_missionCost = "Auftragskosten",
    finance_other = "Geldaenderung"
}

function LivetickerVanillaBridge.getMoneyLabel(text)

    local key = trim(text)

    if key == "" then
        return ""
    end

    if string.sub(key, 1, 8) == "finance_" then

        if g_i18n ~= nil
            and g_i18n.getText ~= nil then

            local ok, translated = pcall(
                function()
                    return g_i18n:getText(key)
                end
            )

            translated = trim(
                ok and translated or nil
            )

            if translated ~= ""
                and translated ~= key
                and string.sub(translated, 1, 8) ~= "Missing " then

                return translated
            end
        end

        local fallback =
            LivetickerVanillaBridge.moneyLabelFallbacks[key]

        if fallback ~= nil then
            return fallback
        end

        return "Geldänderung"
    end

    return key
end


function LivetickerVanillaBridge.getMoneyTypeKey(moneyType)
    if moneyType == nil then
        return nil
    end

    if type(moneyType) == "table" then
        return moneyType.id or moneyType.name or moneyType.title or moneyType
    end

    return moneyType
end

function LivetickerVanillaBridge.getMoneyTypeLabel(moneyType, text)
    local labelSource = trim(text)

    if labelSource == "" and type(moneyType) == "table" then
        labelSource = trim(moneyType.title or moneyType.name or moneyType.l10nKey)
    end

    return LivetickerVanillaBridge.getMoneyLabel(labelSource)
end

function LivetickerVanillaBridge.addMoneyAmount(moneyType, amount, source)
    if moneyType == nil or type(amount) ~= "number" then
        return
    end

    local key = LivetickerVanillaBridge.getMoneyTypeKey(moneyType)
    if key == nil then
        return
    end

    local now = getNowMs()
    local captureKey = tostring(key) .. "|" .. string.format("%.4f", amount)
    local last = LivetickerVanillaBridge.lastMoneyCapture[captureKey]
    if last ~= nil and now > 0 and (now - last) < LivetickerVanillaBridge.moneyCaptureDedupMs then
        return
    end
    LivetickerVanillaBridge.lastMoneyCapture[captureKey] = now

    LivetickerVanillaBridge.moneyChanges[key] =
        (LivetickerVanillaBridge.moneyChanges[key] or 0) + amount

end

function LivetickerVanillaBridge.buildMoneyText(moneyType, text)
    local key = LivetickerVanillaBridge.getMoneyTypeKey(moneyType)
    local amount = key ~= nil and LivetickerVanillaBridge.moneyChanges[key] or nil

    if key ~= nil then
        LivetickerVanillaBridge.moneyChanges[key] = nil
    end

    local label = LivetickerVanillaBridge.getMoneyTypeLabel(moneyType, text)
    local amountText = LivetickerVanillaBridge.formatMoney(amount)

    if label ~= "" and amountText ~= nil then
        return string.format("%s: %s", label, amountText), amount
    elseif amountText ~= nil then
        return string.format("Geldaenderung: %s", amountText), amount
    elseif label ~= "" then
        return label, amount
    end

    return nil, amount
end

local function saveOriginal(key, func)
    if LivetickerVanillaBridge.originals[key] == nil then
        LivetickerVanillaBridge.originals[key] = func
    end
end

function LivetickerVanillaBridge.installMissionHooks()
    if g_currentMission == nil then
        return 0
    end

    local hookCount = 0

    if g_currentMission.addIngameNotification ~= nil then
        local originalFunc = g_currentMission.addIngameNotification
        saveOriginal("mission.addIngameNotification", originalFunc)

        g_currentMission.addIngameNotification = function(self, notificationType, text, ...)
            if LivetickerVanillaBridge.forceOriginal then
                return originalFunc(self, notificationType, text, ...)
            end

            local routed = LivetickerVanillaBridge.pushToTicker(
                text,
                LivetickerVanillaBridge.getNotificationType(notificationType),
                "addIngameNotification"
            )

            if not LivetickerVanillaBridge.hideOriginal or not routed then
                return originalFunc(self, notificationType, text, ...)
            end
            return nil
        end

        hookCount = hookCount + 1
    end

    if g_currentMission.showBlinkingWarning ~= nil then
        local originalFunc = g_currentMission.showBlinkingWarning
        saveOriginal("mission.showBlinkingWarning", originalFunc)

        g_currentMission.showBlinkingWarning = function(self, text, duration, priority, ...)
            if LivetickerVanillaBridge.forceOriginal then
                return originalFunc(self, text, duration, priority, ...)
            end

            local routed = LivetickerVanillaBridge.pushToTicker(
                text,
                getType("TYPE_WARNING", getType("TYPE_INFO", 1)),
                "showBlinkingWarning",
                math.max(4, math.min(10, ((duration or 6000) / 1000)))
            )

            if not LivetickerVanillaBridge.hideOriginal or not routed then
                return originalFunc(self, text, duration, priority, ...)
            end
            return nil
        end

        hookCount = hookCount + 1
    end

    if g_currentMission.addMoney ~= nil then
        local originalFunc = g_currentMission.addMoney
        saveOriginal("mission.addMoney", originalFunc)

        g_currentMission.addMoney = function(self, amount, farmId, moneyType, showVisualMoneyChange, ...)
            if type(amount) == "number" and moneyType ~= nil then
                if showVisualMoneyChange ~= false then
                    LivetickerVanillaBridge.addMoneyAmount(moneyType, amount, "mission.addMoney")
                end
            end

            return originalFunc(self, amount, farmId, moneyType, showVisualMoneyChange, ...)
        end

        hookCount = hookCount + 1
    end

    if g_currentMission.addMoneyChange ~= nil then
        local originalFunc = g_currentMission.addMoneyChange
        saveOriginal("mission.addMoneyChange", originalFunc)

        g_currentMission.addMoneyChange = function(self, amount, farmId, moneyType, ...)
            LivetickerVanillaBridge.addMoneyAmount(moneyType, amount, "mission.addMoneyChange")
            return originalFunc(self, amount, farmId, moneyType, ...)
        end

        hookCount = hookCount + 1
    end

    return hookCount
end

function LivetickerVanillaBridge.installClassHooks()
    local hookCount = 0

    if HUD ~= nil and HUD.addMoneyChange ~= nil then
        local originalFunc = HUD.addMoneyChange
        saveOriginal("HUD.addMoneyChange", originalFunc)

        HUD.addMoneyChange = function(self, moneyType, amount, ...)
            return originalFunc(self, moneyType, amount, ...)
        end

        hookCount = hookCount + 1
    end

    if HUD ~= nil and HUD.showMoneyChange ~= nil then
        local originalFunc = HUD.showMoneyChange
        saveOriginal("HUD.showMoneyChange", originalFunc)

        HUD.showMoneyChange = function(self, moneyType, text, ...)
            if LivetickerVanillaBridge.forceOriginal then
                return originalFunc(self, moneyType, text, ...)
            end

            local tickerText, amount = LivetickerVanillaBridge.buildMoneyText(moneyType, text)
            local routed = false

            if tickerText ~= nil then
                routed = LivetickerVanillaBridge.pushToTicker(
                    tickerText,
                    LivetickerVanillaBridge.getMoneyType(amount),
                    "HUD.showMoneyChange"
                )
            end

            if not LivetickerVanillaBridge.hideOriginal or not routed then
                return originalFunc(self, moneyType, text, ...)
            end
            return nil
        end

        hookCount = hookCount + 1
    end

    if SideNotification ~= nil and SideNotification.addNotification ~= nil then
        local originalFunc = SideNotification.addNotification
        saveOriginal("SideNotification.addNotification", originalFunc)

        SideNotification.addNotification = function(self, text, color, displayDuration, ...)
            if LivetickerVanillaBridge.forceOriginal then
                return originalFunc(self, text, color, displayDuration, ...)
            end

            local routed = LivetickerVanillaBridge.pushToTicker(
                text,
                getType("TYPE_INFO", 1),
                "SideNotification",
                math.max(4, math.min(10, ((displayDuration or 6000) / 1000)))
            )

            if not LivetickerVanillaBridge.hideOriginal or not routed then
                return originalFunc(self, text, color, displayDuration, ...)
            end
            return nil
        end

        hookCount = hookCount + 1
    end

    if AchievementMessage ~= nil and AchievementMessage.showMessage ~= nil then
        local originalFunc = AchievementMessage.showMessage
        saveOriginal("AchievementMessage.showMessage", originalFunc)

        AchievementMessage.showMessage = function(self, title, description, iconFilename, iconUVs, duration, ...)
            if LivetickerVanillaBridge.forceOriginal then
                return originalFunc(self, title, description, iconFilename, iconUVs, duration, ...)
            end

            local tickerText = joinText(title, description)

            local routed = LivetickerVanillaBridge.pushToTicker(
                tickerText,
                getType("TYPE_SUCCESS", getType("TYPE_INFO", 1)),
                "AchievementMessage",
                math.max(6, math.min(12, ((duration or 8000) / 1000)))
            )

            if not LivetickerVanillaBridge.hideOriginal or not routed then
                return originalFunc(self, title, description, iconFilename, iconUVs, duration, ...)
            end
            return nil
        end

        hookCount = hookCount + 1
    end

    return hookCount
end

function LivetickerVanillaBridge.install()
    if LivetickerVanillaBridge.installed then
        return true
    end

    if g_currentMission == nil then
        Logging.warning("[Liveticker] Bridge: g_currentMission ist noch nicht verfuegbar")
        return false
    end

    local hookCount = 0
    hookCount = hookCount + LivetickerVanillaBridge.installMissionHooks()
    hookCount = hookCount + LivetickerVanillaBridge.installClassHooks()

    if hookCount == 0 then
        Logging.error("[Liveticker] Kein geeigneter FS25 Meldungs-Hook gefunden")
        return false
    end

    LivetickerVanillaBridge.installed = true
    return true
end

function LivetickerVanillaBridge.uninstall()
    if not LivetickerVanillaBridge.installed then
        return
    end

    if g_currentMission ~= nil then
        if LivetickerVanillaBridge.originals["mission.addIngameNotification"] ~= nil then
            g_currentMission.addIngameNotification = LivetickerVanillaBridge.originals["mission.addIngameNotification"]
        end
        if LivetickerVanillaBridge.originals["mission.showBlinkingWarning"] ~= nil then
            g_currentMission.showBlinkingWarning = LivetickerVanillaBridge.originals["mission.showBlinkingWarning"]
        end
        if LivetickerVanillaBridge.originals["mission.addMoney"] ~= nil then
            g_currentMission.addMoney = LivetickerVanillaBridge.originals["mission.addMoney"]
        end
        if LivetickerVanillaBridge.originals["mission.addMoneyChange"] ~= nil then
            g_currentMission.addMoneyChange = LivetickerVanillaBridge.originals["mission.addMoneyChange"]
        end
    end

    if HUD ~= nil and LivetickerVanillaBridge.originals["HUD.addMoneyChange"] ~= nil then
        HUD.addMoneyChange = LivetickerVanillaBridge.originals["HUD.addMoneyChange"]
    end
    if HUD ~= nil and LivetickerVanillaBridge.originals["HUD.showMoneyChange"] ~= nil then
        HUD.showMoneyChange = LivetickerVanillaBridge.originals["HUD.showMoneyChange"]
    end

    if SideNotification ~= nil and LivetickerVanillaBridge.originals["SideNotification.addNotification"] ~= nil then
        SideNotification.addNotification = LivetickerVanillaBridge.originals["SideNotification.addNotification"]
    end

    if AchievementMessage ~= nil and LivetickerVanillaBridge.originals["AchievementMessage.showMessage"] ~= nil then
        AchievementMessage.showMessage = LivetickerVanillaBridge.originals["AchievementMessage.showMessage"]
    end

    LivetickerVanillaBridge.originals = {}
    LivetickerVanillaBridge.moneyChanges = {}
    LivetickerVanillaBridge.lastMoneyCapture = {}
    LivetickerVanillaBridge.lastMessageTimes = {}
    LivetickerVanillaBridge.installed = false
end

function LivetickerVanillaBridge:loadMap(mapName)
    LivetickerVanillaBridge.install()
end

function LivetickerVanillaBridge:deleteMap()
    LivetickerVanillaBridge.uninstall()
end

function LivetickerVanillaBridge:update(dt) end
function LivetickerVanillaBridge:draw() end
function LivetickerVanillaBridge:keyEvent(unicode, sym, modifier, isDown) end
function LivetickerVanillaBridge:mouseEvent(posX, posY, isDown, isUp, button) end

ModNotificationVanillaBridge = LivetickerVanillaBridge

addModEventListener(LivetickerVanillaBridge)
