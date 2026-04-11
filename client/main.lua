local ESX = exports['es_extended']:getSharedObject()

-- ─────────────────────────────────────────────────────────────────────────────
--  State
-- ─────────────────────────────────────────────────────────────────────────────
local adminMode  = false   -- this client's admin mode (godmode + staff tag)
local showCoords = false   -- overlay own coordinates on screen
local showIDs    = false   -- draw player-ID tags nearby

-- Table of server IDs that currently have admin mode on (used to draw tags)
local adminPlayers = {}

-- ─────────────────────────────────────────────────────────────────────────────
--  Permission helper (client-side, best-effort)
-- ─────────────────────────────────────────────────────────────────────────────
local function IsAdmin()
    local playerData = ESX.GetPlayerData()
    if not playerData then return false end
    for _, group in ipairs(Config.AdminGroups) do
        if playerData.group == group then return true end
    end
    return false
end

-- ─────────────────────────────────────────────────────────────────────────────
--  3D text helper
-- ─────────────────────────────────────────────────────────────────────────────
local function DrawText3D(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end

    local camCoords = GetGameplayCamCoords()
    local dist = #(vector3(x, y, z) - camCoords)
    if dist > 25.0 then return end

    local scale = (1 / dist) * 2.0 * ((1 / GetGameplayCamFov()) * 100)

    SetTextScale(0.0, scale)
    SetTextFont(0)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 220)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    DrawText(sx, sy)

    local factor = (#text) / 370.0
    DrawRect(sx, sy + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 75)
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Admin mode toggle
-- ─────────────────────────────────────────────────────────────────────────────
local function ToggleAdminMode()
    adminMode = not adminMode

    SetEntityInvincible(PlayerPedId(), adminMode)

    -- Keep the local entry consistent with the network table
    local myServerId = GetPlayerServerId(PlayerId())
    adminPlayers[myServerId] = adminMode

    TriggerServerEvent('esx_modoadmin:setAdminMode', adminMode)

    lib.notify({
        title       = 'Admin Mode',
        description = adminMode and 'Admin mode enabled (godmode + staff tag)' or 'Admin mode disabled',
        type        = adminMode and 'success' or 'error',
    })
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Network: receive admin mode updates from server (for staff-tag rendering)
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('esx_modoadmin:adminModeUpdate', function(serverId, enabled)
    adminPlayers[serverId] = enabled
end)

-- ─────────────────────────────────────────────────────────────────────────────
--  Network: weather sync
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('esx_modoadmin:syncWeather', function(weather)
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    SetWeatherTypePersist(weather)
    SetWeatherTypeNow(weather)
    SetWeatherTypeNowPersist(weather)
end)

-- ─────────────────────────────────────────────────────────────────────────────
--  Network: time sync
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('esx_modoadmin:syncTime', function(hour, minute)
    NetworkOverrideClockTime(hour, minute, 0)
end)

-- ─────────────────────────────────────────────────────────────────────────────
--  Network: receive inventory data from server and show it via context menu
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('esx_modoadmin:receiveInventory', function(targetName, items)
    local options = {}

    if #items == 0 then
        options[1] = { title = 'Inventory is empty.', disabled = true }
    else
        -- Sort by slot number for readability
        table.sort(items, function(a, b) return a.slot < b.slot end)
        for _, item in ipairs(items) do
            options[#options + 1] = {
                title       = ('[%d] %s  ×%d'):format(item.slot, item.label, item.count),
                description = 'Item: ' .. item.name,
                disabled    = true,
            }
        end
    end

    lib.registerContext({
        id      = 'admin_inventory_view',
        title   = '🏠 Inventory – ' .. targetName,
        options = options,
    })
    lib.showContext('admin_inventory_view')
end)

-- ─────────────────────────────────────────────────────────────────────────────
--  Draw threads
-- ─────────────────────────────────────────────────────────────────────────────

-- Staff tags above every player currently in admin mode
CreateThread(function()
    while true do
        Wait(0)
        local myPed = PlayerPedId()
        for serverId, isOn in pairs(adminPlayers) do
            if isOn then
                local netPlayer = GetPlayerFromServerId(serverId)
                if netPlayer ~= -1 then
                    local ped    = GetPlayerPed(netPlayer)
                    local coords = GetEntityCoords(ped)
                    DrawText3D(coords.x, coords.y, coords.z + 1.15, '[STAFF]')
                end
            end
        end
        -- Also draw own tag if pedding in-place doesn't grab own serverId
        if adminMode then
            local coords = GetEntityCoords(myPed)
            DrawText3D(coords.x, coords.y, coords.z + 1.15, '[STAFF]')
        end
    end
end)

-- Coordinate overlay (bottom-centre of screen)
CreateThread(function()
    while true do
        Wait(0)
        if showCoords then
            local ped     = PlayerPedId()
            local coords  = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)

            SetTextFont(4)
            SetTextScale(0.35, 0.35)
            SetTextColour(255, 255, 255, 255)
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEntry('STRING')
            AddTextComponentString(
                ('X: %.2f   Y: %.2f   Z: %.2f   H: %.1f°')
                    :format(coords.x, coords.y, coords.z, heading)
            )
            DrawText(0.5, 0.945)
        end
    end
end)

-- Player ID labels (nearby players)
CreateThread(function()
    while true do
        Wait(0)
        if showIDs then
            local myPed    = PlayerPedId()
            local myCoords = GetEntityCoords(myPed)
            for _, playerId in ipairs(GetActivePlayers()) do
                local ped = GetPlayerPed(playerId)
                if ped ~= myPed then
                    local coords = GetEntityCoords(ped)
                    if #(myCoords - coords) < Config.IDDistance then
                        local sid  = GetPlayerServerId(playerId)
                        local name = GetPlayerName(playerId)
                        DrawText3D(coords.x, coords.y, coords.z + 1.2,
                            ('[ID: %d] %s'):format(sid, name))
                    end
                end
            end
        end
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
--  Vehicle spawn helper
-- ─────────────────────────────────────────────────────────────────────────────
local function SpawnVehicle(modelName)
    local hash = GetHashKey(modelName)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        lib.notify({
            title       = 'Spawn Vehicle',
            description = 'Unknown model: ' .. modelName,
            type        = 'error',
        })
        return
    end

    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) do
        Wait(100)
        timeout = timeout + 100
        if timeout > 10000 then
            lib.notify({ title = 'Spawn Vehicle', description = 'Model failed to load.', type = 'error' })
            return
        end
    end

    local ped     = PlayerPedId()
    local coords  = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    -- Remove the vehicle the player is currently sitting in.
    -- Use DeleteEntity so networked/owned vehicles are properly cleaned up for all clients.
    if IsPedInAnyVehicle(ped, false) then
        local old = GetVehiclePedIsIn(ped, false)
        DeleteEntity(old)
    end

    local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, heading, true, false)
    SetPedIntoVehicle(ped, vehicle, -1)
    SetEntityAsNoLongerNeeded(vehicle)
    SetModelAsNoLongerNeeded(hash)

    lib.notify({
        title       = 'Spawn Vehicle',
        description = 'Spawned ' .. modelName,
        type        = 'success',
    })
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Menus
-- ─────────────────────────────────────────────────────────────────────────────

-- Forward declarations
local OpenAdminMenu, OpenPlayersMenu, OpenPlayerActionsMenu,
      OpenBanMenu, OpenTeleportMenu, OpenWeatherMenu,
      OpenVehicleMenu, OpenVehicleCategoryMenu

-- ── Main menu ────────────────────────────────────────────────────────────────
OpenAdminMenu = function()
    if not IsAdmin() then
        lib.notify({
            title       = 'Admin Menu',
            description = 'You do not have permission to access this menu.',
            type        = 'error',
        })
        return
    end

    lib.registerContext({
        id      = 'admin_main',
        title   = '🛡️ Admin Menu',
        options = {
            {
                title       = adminMode and '✅ Disable Admin Mode' or '❌ Enable Admin Mode',
                description = 'Toggle godmode and staff tag',
                onSelect    = function()
                    ToggleAdminMode()
                    OpenAdminMenu()
                end,
            },
            {
                title       = '👥 Players',
                description = 'Manage online players (kick, ban, warn, inventory)',
                onSelect    = OpenPlayersMenu,
            },
            {
                title       = '📍 Teleport',
                description = 'Teleport to pre-configured locations',
                onSelect    = OpenTeleportMenu,
            },
            {
                title       = '🌤️ Weather & Time',
                description = 'Synchronise weather and time for all players',
                onSelect    = OpenWeatherMenu,
            },
            {
                title       = '🚗 Spawn Vehicle',
                description = 'Spawn a vehicle from a categorised list',
                onSelect    = OpenVehicleMenu,
            },
            {
                title       = showCoords and '🗺️ Hide Coordinates' or '👁️ Show Coordinates',
                description = 'Toggle coordinate/heading display',
                onSelect    = function()
                    showCoords = not showCoords
                    lib.notify({
                        title       = 'Coordinates',
                        description = showCoords and 'Coordinate display enabled.' or 'Coordinate display disabled.',
                        type        = 'inform',
                    })
                    OpenAdminMenu()
                end,
            },
            {
                title       = showIDs and '👤 Hide Player IDs' or '👤 Show Player IDs',
                description = ('Toggle nearby player ID tags  (range: %dm)'):format(Config.IDDistance),
                onSelect    = function()
                    showIDs = not showIDs
                    lib.notify({
                        title       = 'Player IDs',
                        description = showIDs and 'Player ID tags enabled.' or 'Player ID tags disabled.',
                        type        = 'inform',
                    })
                    OpenAdminMenu()
                end,
            },
        },
    })
    lib.showContext('admin_main')
end

-- ── Players list ─────────────────────────────────────────────────────────────
OpenPlayersMenu = function()
    local options = {
        {
            title    = '← Back',
            onSelect = OpenAdminMenu,
        },
    }

    local myServerId = GetPlayerServerId(PlayerId())
    for _, playerId in ipairs(GetActivePlayers()) do
        local sid  = GetPlayerServerId(playerId)
        local name = GetPlayerName(playerId)
        if sid ~= myServerId then
            options[#options + 1] = {
                title       = ('[%d] %s'):format(sid, name),
                description = 'Click to manage this player',
                onSelect    = function()
                    OpenPlayerActionsMenu(sid, name)
                end,
            }
        end
    end

    if #options == 1 then
        options[2] = { title = 'No other players online.', disabled = true }
    end

    lib.registerContext({
        id      = 'admin_players',
        title   = '👥 Online Players',
        options = options,
    })
    lib.showContext('admin_players')
end

-- ── Player actions ───────────────────────────────────────────────────────────
OpenPlayerActionsMenu = function(targetId, targetName)
    lib.registerContext({
        id      = 'admin_player_actions',
        title   = ('👤 %s  [ID: %d]'):format(targetName, targetId),
        options = {
            {
                title    = '← Back',
                onSelect = OpenPlayersMenu,
            },
            {
                title       = '📍 Teleport to Player',
                description = 'Instantly teleport to this player',
                onSelect    = function()
                    local netPlayer = GetPlayerFromServerId(targetId)
                    if netPlayer == -1 then
                        lib.notify({ title = 'Teleport', description = 'Player not found.', type = 'error' })
                        return
                    end
                    local coords = GetEntityCoords(GetPlayerPed(netPlayer))
                    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z + 0.5, false, false, false, true)
                    lib.notify({
                        title       = 'Teleport',
                        description = 'Teleported to ' .. targetName,
                        type        = 'success',
                    })
                end,
            },
            {
                title       = '👢 Kick Player',
                description = 'Remove this player from the server',
                onSelect    = function()
                    local input = lib.inputDialog('Kick – ' .. targetName, {
                        { type = 'input', label = 'Reason', placeholder = 'Enter kick reason', required = true },
                    })
                    if input and input[1] and input[1] ~= '' then
                        TriggerServerEvent('esx_modoadmin:kickPlayer', targetId, input[1])
                    end
                end,
            },
            {
                title       = '🚫 Ban Player',
                description = 'Permanently or temporarily ban this player',
                onSelect    = function()
                    OpenBanMenu(targetId, targetName)
                end,
            },
            {
                title       = '⚠️ Warn Player',
                description = 'Send a visible warning to this player',
                onSelect    = function()
                    local input = lib.inputDialog('Warn – ' .. targetName, {
                        { type = 'input', label = 'Reason', placeholder = 'Enter warning reason', required = true },
                    })
                    if input and input[1] and input[1] ~= '' then
                        TriggerServerEvent('esx_modoadmin:warnPlayer', targetId, input[1])
                    end
                end,
            },
            {
                title       = '🏠 View Inventory',
                description = 'Inspect this player\'s ox_inventory',
                onSelect    = function()
                    TriggerServerEvent('esx_modoadmin:getInventory', targetId)
                end,
            },
        },
    })
    lib.showContext('admin_player_actions')
end

-- ── Ban duration sub-menu ─────────────────────────────────────────────────────
OpenBanMenu = function(targetId, targetName)
    local options = {
        {
            title    = '← Back',
            onSelect = function() OpenPlayerActionsMenu(targetId, targetName) end,
        },
    }

    for _, entry in ipairs(Config.BanDurations) do
        local dur = entry
        options[#options + 1] = {
            title       = '🚫 ' .. dur.label,
            description = 'Ban ' .. targetName .. ' for ' .. dur.label,
            onSelect    = function()
                local input = lib.inputDialog(
                    ('Ban %s (%s)'):format(targetName, dur.label),
                    {
                        { type = 'input', label = 'Reason', placeholder = 'Enter ban reason', required = true },
                    }
                )
                if input and input[1] and input[1] ~= '' then
                    TriggerServerEvent('esx_modoadmin:banPlayer', targetId, input[1], dur.time)
                end
            end,
        }
    end

    lib.registerContext({
        id      = 'admin_ban',
        title   = '🚫 Ban – ' .. targetName,
        options = options,
    })
    lib.showContext('admin_ban')
end

-- ── Teleport locations ────────────────────────────────────────────────────────
OpenTeleportMenu = function()
    local options = {
        {
            title    = '← Back',
            onSelect = OpenAdminMenu,
        },
    }

    for _, loc in ipairs(Config.Locations) do
        local location = loc
        options[#options + 1] = {
            title       = '📍 ' .. location.name,
            description = ('X: %.1f  Y: %.1f  Z: %.1f')
                :format(location.coords.x, location.coords.y, location.coords.z),
            onSelect    = function()
                SetEntityCoords(
                    PlayerPedId(),
                    location.coords.x,
                    location.coords.y,
                    location.coords.z,
                    false, false, false, true
                )
                lib.notify({
                    title       = 'Teleport',
                    description = 'Teleported to ' .. location.name,
                    type        = 'success',
                })
            end,
        }
    end

    lib.registerContext({
        id      = 'admin_teleport',
        title   = '📍 Teleport Locations',
        options = options,
    })
    lib.showContext('admin_teleport')
end

-- ── Weather & Time ─────────────────────────────────────────────────────────────
OpenWeatherMenu = function()
    local options = {
        {
            title    = '← Back',
            onSelect = OpenAdminMenu,
        },
        {
            title       = '🕐 Set Time',
            description = 'Set the server time (synchronized for all players)',
            onSelect    = function()
                local input = lib.inputDialog('Set Time', {
                    { type = 'number', label = 'Hour (0–23)',   min = 0, max = 23 },
                    { type = 'number', label = 'Minute (0–59)', min = 0, max = 59 },
                })
                if input and input[1] ~= nil and input[2] ~= nil then
                    -- Store tonumber results to avoid redundant calls and preserve valid 0 input
                    local hn = tonumber(input[1])
                    local mn = tonumber(input[2])
                    local h = math.floor(hn ~= nil and hn or 12)
                    local m = math.floor(mn ~= nil and mn or 0)
                    TriggerServerEvent('esx_modoadmin:setTime', h, m)
                    lib.notify({
                        title       = 'Time',
                        description = ('Time set to %02d:%02d'):format(h, m),
                        type        = 'success',
                    })
                end
            end,
        },
    }

    for _, weather in ipairs(Config.WeatherTypes) do
        local w = weather
        options[#options + 1] = {
            title       = '🌤️ ' .. w,
            description = 'Set weather to ' .. w .. ' for all players',
            onSelect    = function()
                TriggerServerEvent('esx_modoadmin:setWeather', w)
                lib.notify({
                    title       = 'Weather',
                    description = 'Weather set to ' .. w,
                    type        = 'success',
                })
            end,
        }
    end

    lib.registerContext({
        id      = 'admin_weather',
        title   = '🌤️ Weather & Time',
        options = options,
    })
    lib.showContext('admin_weather')
end

-- ── Vehicle spawn – category list ─────────────────────────────────────────────
OpenVehicleMenu = function()
    local options = {
        {
            title    = '← Back',
            onSelect = OpenAdminMenu,
        },
    }

    for category, _ in pairs(Config.Vehicles) do
        local cat = category
        options[#options + 1] = {
            title       = '🚗 ' .. cat,
            description = (#Config.Vehicles[cat]) .. ' vehicles',
            onSelect    = function() OpenVehicleCategoryMenu(cat) end,
        }
    end

    lib.registerContext({
        id      = 'admin_vehicles',
        title   = '🚗 Spawn Vehicle',
        options = options,
    })
    lib.showContext('admin_vehicles')
end

-- ── Vehicle spawn – model list ────────────────────────────────────────────────
OpenVehicleCategoryMenu = function(category)
    local options = {
        {
            title    = '← Back',
            onSelect = OpenVehicleMenu,
        },
    }

    for _, model in ipairs(Config.Vehicles[category]) do
        local m = model
        options[#options + 1] = {
            title    = m,
            onSelect = function() SpawnVehicle(m) end,
        }
    end

    lib.registerContext({
        id      = 'admin_vehicle_category',
        title   = '🚗 ' .. category,
        options = options,
    })
    lib.showContext('admin_vehicle_category')
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Key binding  (default F10, re-bindable in GTA key bindings settings)
-- ─────────────────────────────────────────────────────────────────────────────
RegisterKeyMapping('+openAdminMenu', 'Open Admin Menu', 'keyboard', 'F10')
RegisterCommand('+openAdminMenu', function()
    OpenAdminMenu()
end, false)

-- Chat command fallback
RegisterCommand('adminmenu', function()
    OpenAdminMenu()
end, false)
