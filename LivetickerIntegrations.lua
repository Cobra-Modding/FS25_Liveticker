-- ============================================================
-- FS25_LiveTickerIntegrations.lua
-- by Marcus (Cobra Modding)
-- 
--
-- Version 1.0.0.0
--
--
-- Keine Änderung am Skript ohne meine Erlaubnis
-- ============================================================

LivetickerIntegrations = {}
LivetickerIntegrations.installed = false
LivetickerIntegrations.originals = {}
LivetickerIntegrations.retryTimer = 0
LivetickerIntegrations.retryCount = 0
LivetickerIntegrations.registry = {
    FS25_AdvancedVehicleFunctions = {
        { objectName = "g_VehicleSystems", methodName = "showWarning" },
        { objectName = "g_Implement_Controls", methodName = "showWarning" }
    }
}

local function callWithOriginalNotifications(func, self, ...)
    local args = { ... }
    local argCount = select("#", ...)
    LivetickerVanillaBridge.forceOriginal = true

    local results = {
        pcall(function()
            return func(self, unpack(args, 1, argCount))
        end)
    }

    LivetickerVanillaBridge.forceOriginal = false

    if not results[1] then
        Logging.error("[Liveticker] Integrationsfehler: %s", tostring(results[2]))
        return nil
    end

    return unpack(results, 2)
end

local function resolveObject(objectName)

    if objectName == "g_VehicleSystems" then
        return g_VehicleSystems
    elseif objectName == "g_Implement_Controls" then
        return g_Implement_Controls
    end

    return _G ~= nil and _G[objectName] or nil
end

function LivetickerIntegrations.install()
    if LivetickerVanillaBridge == nil then
        return
    end

    local pending = false

    for modName, entries in pairs(LivetickerIntegrations.registry) do
        if LivetickerVanillaBridge.blacklistMods[modName] == true then
            for _, entry in ipairs(entries) do
                local object = resolveObject(entry.objectName)
                local original = object ~= nil and object[entry.methodName] or nil

                if type(original) == "function" then
                    local key = entry.objectName .. "." .. entry.methodName
                    if LivetickerIntegrations.originals[key] == nil then
                        LivetickerIntegrations.originals[key] = original
                        object[entry.methodName] = function(self, ...)
                            return callWithOriginalNotifications(original, self, ...)
                        end
                    end
                else
                    pending = true
                end
            end
        end
    end

    LivetickerIntegrations.installed = not pending

end


function LivetickerIntegrations:loadMap()
    LivetickerIntegrations.install()
end

function LivetickerIntegrations:deleteMap()
    for key, original in pairs(LivetickerIntegrations.originals) do
        local objectName, methodName = string.match(key, "^(.+)%.([^%.]+)$")
        local object = objectName ~= nil and resolveObject(objectName) or nil
        if object ~= nil and methodName ~= nil then
            object[methodName] = original
        end
    end

    LivetickerIntegrations.originals = {}
    LivetickerIntegrations.installed = false
    if LivetickerVanillaBridge ~= nil then
        LivetickerVanillaBridge.forceOriginal = false
    end
end

function LivetickerIntegrations:update(dt)
    if LivetickerIntegrations.installed then
        return
    end

    LivetickerIntegrations.retryTimer = LivetickerIntegrations.retryTimer + dt
    if LivetickerIntegrations.retryTimer >= 500 and LivetickerIntegrations.retryCount < 20 then
        LivetickerIntegrations.retryTimer = 0
        LivetickerIntegrations.retryCount = LivetickerIntegrations.retryCount + 1
        LivetickerIntegrations.install()
    end
end
function LivetickerIntegrations:draw() end
function LivetickerIntegrations:keyEvent(unicode, sym, modifier, isDown) end
function LivetickerIntegrations:mouseEvent(posX, posY, isDown, isUp, button) end

addModEventListener(LivetickerIntegrations)
