local ESX = exports['es_extended']:getSharedObject()

-- ─────────────────────────────────────────────────────────────────────────────
--  Helpers
-- ─────────────────────────────────────────────────────────────────────────────

--- Send an embed to a Discord webhook.
---@param webhook  string   Full webhook URL
---@param title    string   Embed title
---@param desc     string   Embed description (supports markdown)
---@param color    integer  Decimal color (e.g. 16711680 = red)
---@param author   string   Author field shown in the embed footer area
local function SendDiscordLog(webhook, title, desc, color, author)
    if not webhook or webhook == '' or webhook == 'YOUR_DISCORD_WEBHOOK_URL' then
        return
    end

    local payload = json.encode({
        username   = Config.BotName,
        avatar_url = Config.BotAvatar,
        embeds     = {
            {
                title       = title,
                description = desc,
                color       = color or 3447003,
                footer      = {
                    text = Config.ServerName
                        .. ' • '
                        .. os.date('%d/%m/%Y %H:%M:%S'),
                },
                author = author and { name = author } or nil,
            },
        },
    })

    PerformHttpRequest(
        webhook,
        function(_, _, _) end,
        'POST',
        payload,
        { ['Content-Type'] = 'application/json' }
    )
end

--- Return true if the given server source belongs to a configured admin group.
---@param source integer
---@return boolean
local function IsAdmin(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    local group = xPlayer.getGroup()
    for _, adminGroup in ipairs(Config.AdminGroups) do
        if group == adminGroup then return true end
    end
    return false
end

--- Return the first identifier of `identType` for a connected player.
---@param source    integer
---@param identType string  e.g. 'license', 'steam', 'discord'
---@return string|nil
local function GetIdentifier(source, identType)
    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local ident = GetPlayerIdentifier(source, i)
        if string.find(ident, identType .. ':', 1, true) then
            return ident
        end
    end
    return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Database – create table on resource start
-- ─────────────────────────────────────────────────────────────────────────────
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `esx_modoadmin_bans` (
            `id`         INT          AUTO_INCREMENT PRIMARY KEY,
            `identifier` VARCHAR(255) NOT NULL,
            `name`       VARCHAR(255),
            `reason`     VARCHAR(500),
            `banned_by`  VARCHAR(255),
            `expire`     BIGINT       DEFAULT NULL,
            `created_at` TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_identifier (`identifier`)
        )
    ]])
end)

-- ─────────────────────────────────────────────────────────────────────────────
--  Ban check on connect
-- ─────────────────────────────────────────────────────────────────────────────
AddEventHandler('playerConnecting', function(_, _, deferrals)
    local source = source
    deferrals.defer()
    Wait(0)

    local identifier = GetIdentifier(source, 'license')
    if not identifier then
        deferrals.done('Could not verify your identity. Please restart your game.')
        return
    end

    local ban = MySQL.single.await(
        'SELECT * FROM `esx_modoadmin_bans` WHERE `identifier` = ? AND (`expire` IS NULL OR `expire` > ?) LIMIT 1',
        { identifier, os.time() }
    )

    if ban then
        local expireText = ban.expire
            and os.date('%d/%m/%Y %H:%M', ban.expire)
            or 'Permanent'
        deferrals.done(
            'You are banned from this server.\n'
            .. 'Reason: '  .. (ban.reason     or 'No reason given') .. '\n'
            .. 'Banned by: ' .. (ban.banned_by or 'Unknown')        .. '\n'
            .. 'Expires: '  .. expireText
        )
    else
        deferrals.done()
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
--  Admin mode – broadcast to all clients so staff tags render for everyone
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('esx_modoadmin:setAdminMode', function(enabled)
    local source = source
    if not IsAdmin(source) then return end
    TriggerClientEvent('esx_modoadmin:adminModeUpdate', -1, source, enabled)
end)

-- ─────────────────────────────────────────────────────────────────────────────
--  Moderation – Ban
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('esx_modoadmin:banPlayer', function(targetId, reason, duration)
    local source = source
    if not IsAdmin(source) then return end

    local targetPlayer = ESX.GetPlayerFromId(targetId)
    if not targetPlayer then
        TriggerClientEvent('ox_lib:notify', source, {
            title       = 'Admin',
            description = 'Player not found.',
            type        = 'error',
        })
        return
    end

    local adminName      = GetPlayerName(source)
    local targetName     = GetPlayerName(targetId)
    local targetIdent    = targetPlayer.getIdentifier()

    -- duration == -1 means permanent (expire stays NULL)
    local expireTime = (duration and duration > 0) and (os.time() + duration) or nil
    local durLabel   = expireTime
        and (os.date('%d/%m/%Y %H:%M', expireTime))
        or 'Permanent'

    MySQL.insert(
        'INSERT INTO `esx_modoadmin_bans` (`identifier`, `name`, `reason`, `banned_by`, `expire`) VALUES (?, ?, ?, ?, ?)',
        { targetIdent, targetName, reason, adminName, expireTime }
    )

    local kickMsg = ('You have been banned from this server.\nReason: %s\nExpires: %s'):format(reason, durLabel)
    DropPlayer(targetId, kickMsg)

    SendDiscordLog(
        Config.DiscordWebhook,
        '🚫 Player Banned',
        ('**Player:** %s\n**Identifier:** %s\n**Reason:** %s\n**Expires:** %s\n**Banned by:** %s')
            :format(targetName, targetIdent, reason, durLabel, adminName),
        16711680,  -- red
        adminName
    )

    TriggerClientEvent('ox_lib:notify', source, {
        title       = 'Admin',
        description = targetName .. ' has been banned.',
        type        = 'success',
    })
end)

-- ─────────────────────────────────────────────────────────────────────────────
--  Moderation – Kick
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('esx_modoadmin:kickPlayer', function(targetId, reason)
    local source = source
    if not IsAdmin(source) then return end

    local targetPlayer = ESX.GetPlayerFromId(targetId)
    if not targetPlayer then
        TriggerClientEvent('ox_lib:notify', source, {
            title       = 'Admin',
            description = 'Player not found.',
            type        = 'error',
        })
        return
    end

    local adminName   = GetPlayerName(source)
    local targetName  = GetPlayerName(targetId)
    local targetIdent = targetPlayer.getIdentifier()

    DropPlayer(targetId, 'You have been kicked.\nReason: ' .. reason)

    SendDiscordLog(
        Config.DiscordWebhook,
        '👢 Player Kicked',
        ('**Player:** %s\n**Identifier:** %s\n**Reason:** %s\n**Kicked by:** %s')
            :format(targetName, targetIdent, reason, adminName),
        16744272,  -- orange
        adminName
    )

    TriggerClientEvent('ox_lib:notify', source, {
        title       = 'Admin',
        description = targetName .. ' has been kicked.',
        type        = 'success',
    })
end)

-- ─────────────────────────────────────────────────────────────────────────────
--  Moderation – Warn
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('esx_modoadmin:warnPlayer', function(targetId, reason)
    local source = source
    if not IsAdmin(source) then return end

    local targetPlayer = ESX.GetPlayerFromId(targetId)
    if not targetPlayer then
        TriggerClientEvent('ox_lib:notify', source, {
            title       = 'Admin',
            description = 'Player not found.',
            type        = 'error',
        })
        return
    end

    local adminName   = GetPlayerName(source)
    local targetName  = GetPlayerName(targetId)
    local targetIdent = targetPlayer.getIdentifier()

    -- Notify the warned player
    TriggerClientEvent('ox_lib:notify', targetId, {
        title       = '⚠️ Warning',
        description = 'You have been warned by an admin.\nReason: ' .. reason,
        type        = 'error',
        duration    = 10000,
    })

    SendDiscordLog(
        Config.DiscordWebhook,
        '⚠️ Player Warned',
        ('**Player:** %s\n**Identifier:** %s\n**Reason:** %s\n**Warned by:** %s')
            :format(targetName, targetIdent, reason, adminName),
        16776960,  -- yellow
        adminName
    )

    TriggerClientEvent('ox_lib:notify', source, {
        title       = 'Admin',
        description = targetName .. ' has been warned.',
        type        = 'success',
    })
end)

-- ─────────────────────────────────────────────────────────────────────────────
--  Inventory (ox_inventory)
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('esx_modoadmin:getInventory', function(targetId)
    local source = source
    if not IsAdmin(source) then return end

    local targetPlayer = ESX.GetPlayerFromId(targetId)
    if not targetPlayer then
        TriggerClientEvent('ox_lib:notify', source, {
            title       = 'Admin',
            description = 'Player not found.',
            type        = 'error',
        })
        return
    end

    local adminName   = GetPlayerName(source)
    local targetName  = GetPlayerName(targetId)
    local targetIdent = targetPlayer.getIdentifier()

    -- Fetch inventory from ox_inventory
    local inventory = exports.ox_inventory:GetInventory(targetIdent, false)

    local items = {}
    if inventory and inventory.items then
        for _, item in pairs(inventory.items) do
            if item and item.name then
                items[#items + 1] = {
                    name  = item.name,
                    label = item.label or item.name,
                    count = item.count or 1,
                    slot  = item.slot  or 0,
                }
            end
        end
    end

    TriggerClientEvent('esx_modoadmin:receiveInventory', source, targetName, items)

    SendDiscordLog(
        Config.DiscordWebhook,
        '🏠 Inventory Viewed',
        ('**Target:** %s\n**Identifier:** %s\n**Viewed by:** %s')
            :format(targetName, targetIdent, adminName),
        3447003,  -- blue
        adminName
    )
end)

-- ─────────────────────────────────────────────────────────────────────────────
--  Weather sync
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('esx_modoadmin:setWeather', function(weather)
    local source = source
    if not IsAdmin(source) then return end

    local adminName = GetPlayerName(source)
    TriggerClientEvent('esx_modoadmin:syncWeather', -1, weather)

    SendDiscordLog(
        Config.DiscordWebhook,
        '🌤️ Weather Changed',
        ('**Weather:** %s\n**Changed by:** %s'):format(weather, adminName),
        3447003,
        adminName
    )
end)

-- ─────────────────────────────────────────────────────────────────────────────
--  Time sync
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('esx_modoadmin:setTime', function(hour, minute)
    local source = source
    if not IsAdmin(source) then return end

    local adminName = GetPlayerName(source)
    TriggerClientEvent('esx_modoadmin:syncTime', -1, tonumber(hour), tonumber(minute))

    SendDiscordLog(
        Config.DiscordWebhook,
        '🕐 Time Changed',
        ('**Time:** %02d:%02d\n**Changed by:** %s'):format(hour, minute, adminName),
        3447003,
        adminName
    )
end)
