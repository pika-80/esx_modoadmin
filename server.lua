local ESX = exports["es_extended"]:getSharedObject()

-- Wrapper para compatibilidade com oxmysql
local MySQL = {
    insert = {
        await = function(query, params)
            return exports.oxmysql:insert_async(query, params)
        end
    },
    update = {
        await = function(query, params)
            return exports.oxmysql:update_async(query, params)
        end
    },
    query = {
        await = function(query, params)
            return exports.oxmysql:fetch_async(query, params)
        end
    },
    single = {
        await = function(query, params)
            return exports.oxmysql:fetch_scalar(query, params)
        end
    }
}

-- ============================================
-- CACHE E DADOS GLOBAIS
-- ============================================

local staffData = {}
local commandCooldown = {}
local banCache = {}
local banCacheTime = 0
local BAN_CACHE_DURATION = 300 -- 5 minutos
local playerIdentifiers = {}

-- ============================================
-- EVENTO: ENVIAR GRUPO DO PLAYER
-- ============================================

RegisterServerEvent('esx:getGroup')
AddEventHandler('esx:getGroup', function()
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        local grupo = xPlayer.getGroup()
        TriggerClientEvent('esx:setGroup', source, grupo)
    end
end)

-- ============================================
-- VALIDAÇÕES MELHORADAS
-- ============================================

function IsPlayerAdmin(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    
    local grupo = xPlayer.getGroup()
    return grupo == 'admin' or grupo == 'mod' or grupo == 'superadmin'
end

function HasAdminPerms(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    
    local grupo = xPlayer.getGroup()
    return grupo == 'admin' or grupo == 'mod' or grupo == 'superadmin'
end

function CanExecuteCommand(source)
    local now = os.time()
    if not commandCooldown[source] then
        commandCooldown[source] = now
        return true
    end
    
    if (now - commandCooldown[source]) >= Config.CommandCooldown then
        commandCooldown[source] = now
        return true
    end
    
    return false
end

function ValidateAdminAction(src, target)
    -- Permitir se for a si próprio para ver inventário
    local xAdmin = ESX.GetPlayerFromId(src)
    local xTarget = ESX.GetPlayerFromId(target)
    
    if not xAdmin or not xTarget then
        return false, "Player não encontrado!"
    end
    
    if not HasAdminPerms(src) then
        return false, "Sem permissão!"
    end
    
    return true, nil
end

-- ============================================
-- FUNÇÃO: OBTER DISCORD
-- ============================================

function GetPlayerDiscord(src)
    local identifiers = GetPlayerIdentifiers(src)
    
    for i=1, #identifiers do
        if string.find(identifiers[i], 'discord:') then
            return string.sub(identifiers[i], 9)
        end
    end
    
    return nil
end

-- ============================================
-- WEBHOOK DISCORD - STAFF LOG
-- ============================================

function SendDiscordLog(action, playerName, playerId, discord)
    if not Config.DiscordLogs or Config.DiscordWebhook == "" then
        return
    end
    
    local embed = {
        {
            ["color"] = action == "ENTROU" and "65280" or "16711680",
            ["title"] = "**" .. action .. " EM MODO STAFF**",
            ["description"] = playerName .. " | ID: " .. playerId .. "\n**Discord:** " .. (discord or "Não encontrado"),
            ["footer"] = {
                ["text"] = "LOGS DA ADMINISTRAÇÃO",
            },
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }
    }
    
    PerformHttpRequest(Config.DiscordWebhook, function(err, text, headers) end, 'POST', json.encode({username = "Staff Logs", embeds = embed}), { ['Content-Type'] = 'application/json' })
end

-- ============================================
-- FUNÇÃO: ENVIAR LOG PARA DISCORD (BAN/KICK/WARN/ADMIN)
-- ============================================

function SendDiscordBanLog(action, adminName, targetName, reason, duration, targetIdentifier)
    if not Config.DiscordLogs or Config.DiscordWebhook == "" then
        return
    end
    
    local durationText = "Permanente"
    if action == "BAN" and duration then
        if duration == 2147483647 then
            durationText = "Permanente"
        elseif duration == 600 then
            durationText = "10 Minutos"
        elseif duration == 1800 then
            durationText = "30 Minutos"
        elseif duration == 3600 then
            durationText = "1 Hora"
        elseif duration == 21600 then
            durationText = "6 Horas"
        elseif duration == 43200 then
            durationText = "12 Horas"
        elseif duration == 86400 then
            durationText = "1 Dia"
        elseif duration == 259200 then
            durationText = "3 Dias"
        elseif duration == 604800 then
            durationText = "1 Semana"
        end
    end
    
    local color = "16711680"
    if action == "TELEPORTE" then
        color = "3447003"
    elseif string.find(action, "COORDENADAS") then
        color = "10181046"
    elseif action == "WARN" then
        color = "16776960"
    elseif action == "KICK" then
        color = "16744192"
    elseif action == "UNBAN" then
        color = "65280"
    elseif action == "WEATHER CHANGE" then
        color = "16753920"
    elseif action == "TIME CHANGE" then
        color = "16753920"
    elseif action == "SPAWN VEÍCULO" then
        color = "16753920"
    end
    
    local description
    
    if action == "TELEPORTE" then
        description = string.format(
            "**Admin:** %s\n**Detalhes:** %s",
            adminName,
            reason or "N/A"
        )
    elseif string.find(action, "COORDENADAS") then
        description = string.format(
            "**Admin:** %s\n**Ação:** %s\n**Detalhes:** %s",
            adminName,
            action,
            reason or "N/A"
        )
    elseif action == "BAN" then
        description = string.format(
            "**Admin:** %s\n**Player:** %s\n**Razão:** %s\n**Duração:** %s\n**Identifier:** %s",
            adminName,
            targetName,
            reason or "Não especificado",
            durationText,
            targetIdentifier or "N/A"
        )
    elseif action == "WEATHER CHANGE" or action == "TIME CHANGE" then
        description = string.format(
            "**Admin:** %s\n**Detalhes:** %s",
            adminName,
            reason or "N/A"
        )
    elseif action == "SPAWN VEÍCULO" then
        description = string.format(
            "**Admin:** %s\n**Detalhes:** %s",
            adminName,
            reason or "N/A"
        )
    else
        description = string.format(
            "**Admin:** %s\n**Player:** %s\n**Razão:** %s\n**Identifier:** %s",
            adminName,
            targetName,
            reason or "Não especificado",
            targetIdentifier or "N/A"
        )
    end
    
    local embed = {
        {
            ["color"] = tonumber(color),
            ["title"] = "**" .. action .. "**",
            ["description"] = description,
            ["footer"] = {
                ["text"] = "LOGS DE MODERAÇÃO",
            },
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }
    }
    
    PerformHttpRequest(Config.DiscordWebhook, function(err, text, headers) end, 'POST', json.encode({username = "Moderação Logs", embeds = embed}), { ['Content-Type'] = 'application/json' })
end

-- ============================================
-- FUNÇÃO: LOG DE AÇÕES (SEM CONSOLE)
-- ============================================

function LogAdminAction(adminName, action, targetName, details)
    -- Esta função está aqui apenas para manter compatibilidade
    -- Logs vão apenas para Discord agora
end

-- ============================================
-- CACHE DE BANS
-- ============================================

function GetBanFromCache(identifier)
    local now = os.time()
    if (now - banCacheTime) > BAN_CACHE_DURATION then
        banCache = {}
        banCacheTime = now
    end
    return banCache[identifier]
end

function SetBanCache(identifier, ban)
    banCache[identifier] = ban
end

function InvalidateBanCache()
    banCache = {}
    banCacheTime = 0
end

-- ============================================
-- LIMPEZA DE BANS EXPIRADOS
-- ============================================

function CleanExpiredBans()
    Citizen.CreateThread(function()
        while true do
            Wait(300000) -- A cada 5 minutos
            
            local result = exports.oxmysql:update_async('DELETE FROM bans WHERE banned_until > 0 AND banned_until < ?', {os.time()})
            
            if result and result > 0 then
                InvalidateBanCache()
            end
        end
    end)
end

-- Chamar na inicialização
CleanExpiredBans()

-- ============================================
-- EVENTO: TELEPORTAR PARA LOCALIZAÇÃO
-- ============================================

RegisterServerEvent('esx_modoadmin:teleportToLocation')
AddEventHandler('esx_modoadmin:teleportToLocation', function(locationName)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    if not HasAdminPerms(source) then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Erro',
            description = 'Sem permissão!',
            type = 'error'
        })
        return
    end
    
    local adminName = GetPlayerName(source)
    SendDiscordBanLog("TELEPORTE", adminName, "N/A", "Teleportado para: " .. locationName, nil, nil)
    LogAdminAction(adminName, "TELEPORTE", "N/A", "Localização: " .. locationName)
end)

-- ============================================
-- EVENTO: ATIVAR/DESATIVAR COORDENADAS
-- ============================================

RegisterServerEvent('esx_modoadmin:toggleCoords')
AddEventHandler('esx_modoadmin:toggleCoords', function(state)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    if not HasAdminPerms(source) then
        return
    end
    
    local adminName = GetPlayerName(source)
    local action = state and "ATIVAR COORDENADAS" or "DESATIVAR COORDENADAS"
    
    SendDiscordBanLog(action, adminName, "N/A", "Coordenadas " .. (state and "ativadas" or "desativadas"), nil, nil)
    LogAdminAction(adminName, action, "N/A", nil)
end)

-- ============================================
-- EVENTO: OBTER DISCORD
-- ============================================

RegisterServerEvent('esx_modoadmin:getDiscord')
AddEventHandler('esx_modoadmin:getDiscord', function(cb)
    local discord = GetPlayerDiscord(source)
    TriggerClientEvent('esx_modoadmin:discordReceived', source, discord)
end)

-- ============================================
-- COMANDO: ENTRAR EM MODO STAFF
-- ============================================

RegisterCommand("modostaff", function(source, args, showError)
    if not IsPlayerAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, {
            args = {"Sistema", "Você não tem permissão para usar este comando!"},
            color = {255, 0, 0}
        })
        return
    end
    
    if not CanExecuteCommand(source) then
        TriggerClientEvent('chat:addMessage', source, {
            args = {"Sistema", "Aguarde " .. Config.CommandCooldown .. " segundos antes de usar novamente!"},
            color = {255, 165, 0}
        })
        return
    end
    
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    local groupType = xPlayer.getGroup()
    local nome = GetPlayerName(source)
    local discord = GetPlayerDiscord(source)
    
    if not staffData[source] then
        staffData[source] = {
            job = xPlayer.job.name,
            grade = xPlayer.job.grade
        }
    end
    
    TriggerClientEvent("entraradmin", -1, source, nome, groupType)
    xPlayer.setJob(Config.StaffJob, 0)
    SendDiscordLog("ENTROU", nome, source, discord)
    LogAdminAction(nome, "ENTROU EM STAFF", "N/A", "Grupo: " .. groupType)
end)

-- ============================================
-- COMANDO: SAIR DE MODO STAFF
-- ============================================

RegisterCommand("sairstaff", function(source, args, showError)
    if not IsPlayerAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, {
            args = {"Sistema", "Você não tem permissão para usar este comando!"},
            color = {255, 0, 0}
        })
        return
    end
    
    if not CanExecuteCommand(source) then
        TriggerClientEvent('chat:addMessage', source, {
            args = {"Sistema", "Aguarde " .. Config.CommandCooldown .. " segundos antes de usar novamente!"},
            color = {255, 165, 0}
        })
        return
    end
    
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    -- VERIFICAR SE ESTÁ EM STAFF
    if xPlayer.job.name ~= Config.StaffJob then
        TriggerClientEvent('chat:addMessage', source, {
            args = {"Sistema", "Você não está em modo staff!"},
            color = {255, 0, 0}
        })
        return
    end
    
    local groupType = xPlayer.getGroup()
    local nome = GetPlayerName(source)
    local discord = GetPlayerDiscord(source)
    
    -- RESTAURAR JOB ANTERIOR (IMPORTANTE: verifica se existe)
    if staffData[source] and staffData[source].job then
        xPlayer.setJob(staffData[source].job, staffData[source].grade)
        staffData[source] = nil -- LIMPAR DATA
    else
        xPlayer.setJob('unemployed', 0)
    end
    
    TriggerClientEvent("sairadmin", -1, source, nome, groupType)
    SendDiscordLog("SAIU", nome, source, discord)
    LogAdminAction(nome, "SAIU DE STAFF", "N/A", "Grupo: " .. groupType)
end)

-- ============================================
-- COMANDO: LISTAR ADMINS ONLINE
-- ============================================

RegisterCommand('admins', function(source, args, rawCommand)
    if source == 0 then
        return
    end
    
    TriggerClientEvent('chatMessage', source, "^1Administradores Online:", {20, 200, 20}, "")
    TriggerClientEvent("sendMessageAdmOn", -1, source)
end, false)

-- ============================================
-- EVENTO: MENSAGEM DE ADMIN
-- ============================================

RegisterServerEvent('adminson')
AddEventHandler('adminson', function(id1, modo)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    local grupo = xPlayer.getGroup()
    
    if grupo == 'admin' or grupo == 'mod' or grupo == 'superadmin' then
        local nome = GetPlayerName(source)
        
        if modo == 1 then
            TriggerClientEvent('chatMessage', id1, "STAFF | ", {20, 200, 20}, "^1" .. nome .. " ^0 - ^2MODO ADMIN^0")
        elseif modo == 2 then
            TriggerClientEvent('chatMessage', id1, "STAFF | ", {20, 200, 20}, "^1" .. nome .. " ^0 - ^2MODO NORMAL^0")
        end
    end
end)

-- ============================================
-- EVENTO: MUDAR CLIMA
-- ============================================

RegisterServerEvent('esx_modoadmin:setWeather')
AddEventHandler('esx_modoadmin:setWeather', function(weather)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not HasAdminPerms(source) then return end
    
    local adminName = GetPlayerName(source)
    SendDiscordBanLog("WEATHER CHANGE", adminName, "N/A", "Clima alterado para: " .. weather, nil, nil)
    LogAdminAction(adminName, "MUDOU CLIMA", "N/A", "Novo clima: " .. weather)
    
    -- SINCRONIZAR PARA TODOS
    TriggerClientEvent('updateWeather', -1, weather)
end)

-- ============================================
-- EVENTO: MUDAR HORA
-- ============================================

RegisterServerEvent('esx_modoadmin:setTime')
AddEventHandler('esx_modoadmin:setTime', function(hour, minute)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not HasAdminPerms(source) then return end
    
    local adminName = GetPlayerName(source)
    SendDiscordBanLog("TIME CHANGE", adminName, "N/A", string.format("Hora alterada para %02d:%02d", hour, minute), nil, nil)
    LogAdminAction(adminName, "MUDOU HORA", "N/A", string.format("Nova hora: %02d:%02d", hour, minute))
    -- SINCRONIZAR PARA TODOS
    TriggerClientEvent('updateTime', -1, hour, minute)
end)
-- ============================================
-- LIMPEZA AO DESCONECTAR
-- ============================================

AddEventHandler('playerDropped', function(reason)
    local source = source
    if staffData[source] then
        staffData[source] = nil
    end
    if commandCooldown[source] then
        commandCooldown[source] = nil
    end
    if playerIdentifiers[source] then
        playerIdentifiers[source] = nil
    end
end)

-- ============================================
-- CALLBACK: OBTER LISTA DE PLAYERS ONLINE
-- ============================================

ESX.RegisterServerCallback('esx_admin:getOnlinePlayers', function(source, cb)
    local xPlayers = ESX.GetExtendedPlayers()
    local playerList = {}
    
    for i, xPlayer in ipairs(xPlayers) do
        table.insert(playerList, {
            id = xPlayer.source,
            name = xPlayer.getName(),
            job = xPlayer.job.label,
            money = xPlayer.getMoney()
        })
    end
    
    cb(playerList)
end)

-- ============================================
-- CALLBACK: OBTER INVENTÁRIO DO PLAYER
-- ============================================

ESX.RegisterServerCallback('esx_admin:getPlayerInventory', function(source, cb, targetId)
    local valid, err = ValidateAdminAction(source, targetId)
    if not valid then
        cb(nil)
        return
    end
    
    local xTarget = ESX.GetPlayerFromId(targetId)
    
    if not xTarget then
        cb(nil)
        return
    end
    
    local inventory = {
        name = xTarget.getName(),
        id = xTarget.source,
        job = xTarget.job.label,
        grade = xTarget.job.grade_label,
        items = {},
        weapons = {},
        money = xTarget.getMoney(),
        bank = xTarget.getAccount('bank').money,
        black_money = xTarget.getAccount('black_money').money
    }
    
    -- ITEMS (ox_inventory)
    local playerInventory = exports.ox_inventory:GetInventoryItems(targetId)
    if playerInventory then
        for slot, item in pairs(playerInventory) do
            if item and item.count and item.count > 0 then
                table.insert(inventory.items, {
                    name = item.name,
                    label = item.label,
                    count = item.count
                })
            end
        end
    end
    
    -- ARMAS
    local weapons = xTarget.getLoadout()
    if weapons then
        for i, weapon in ipairs(weapons) do
            table.insert(inventory.weapons, {
                name = weapon.name,
                label = weapon.label or weapon.name,
                ammo = weapon.ammo or 0
            })
        end
    end
    
    cb(inventory)
end)

-- ============================================
-- CALLBACK: OBTER LISTA DE BANS
-- ============================================

ESX.RegisterServerCallback('esx_admin:getBansList', function(source, cb)
    local xAdmin = ESX.GetPlayerFromId(source)
    
    if not xAdmin or not HasAdminPerms(source) then
        cb(nil)
        return
    end
    
    local result = exports.oxmysql:fetch_async('SELECT * FROM bans ORDER BY created_at DESC LIMIT 50', {})
    cb(result)
end)

-- ============================================
-- BAN PLAYER
-- ============================================

RegisterServerEvent('esx_admin:banPlayer')
AddEventHandler('esx_admin:banPlayer', function(playerId, reason, duration)
    local src = source
    local valid, err = ValidateAdminAction(src, playerId)
    
    if not valid then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Erro',
            description = err,
            type = 'error'
        })
        return
    end
    
    local xTarget = ESX.GetPlayerFromId(playerId)
    local adminName = GetPlayerName(src)
    local targetName = GetPlayerName(playerId)
    
    local identifiers = GetPlayerIdentifiers(playerId)
    local targetIdentifier
    
    for _, id in pairs(identifiers) do
        if string.sub(id, 1, string.len('license:')) == 'license:' then
            targetIdentifier = id
            break
        end
    end
    
    if not targetIdentifier then
        targetIdentifier = xTarget.getIdentifier()
    end
    
    local banUntil = 0
    if duration ~= 2147483647 then
        banUntil = os.time() + duration
    end
    
    exports.oxmysql:insert_async('INSERT INTO bans (identifier, reason, banned_by, banned_until) VALUES (?, ?, ?, ?)', {
        targetIdentifier,
        reason,
        adminName,
        banUntil
    }, function(id)
        InvalidateBanCache()
    end)
    
    SendDiscordBanLog("BAN", adminName, targetName, reason, duration, targetIdentifier)
    LogAdminAction(adminName, "BANIR", targetName, "Razão: " .. reason)
    
    DropPlayer(playerId, string.format('Você foi banido.\nRazão: %s\nBanido por: %s', reason, adminName))
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Ban',
        description = string.format('%s foi banido por: %s', targetName, reason),
        type = 'success'
    })
    
end)

-- ============================================
-- UNBAN PLAYER
-- ============================================

RegisterServerEvent('esx_admin:unbanPlayer')
AddEventHandler('esx_admin:unbanPlayer', function(identifier)
    local src = source
    local xAdmin = ESX.GetPlayerFromId(src)
    
    if not xAdmin or not HasAdminPerms(src) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Erro',
            description = 'Sem permissão!',
            type = 'error'
        })
        return
    end
    
    local adminName = GetPlayerName(src)
    local result = exports.oxmysql:update_async('DELETE FROM bans WHERE identifier = ?', {identifier})
    
    if result and result > 0 then
        SendDiscordBanLog("UNBAN", adminName, "Unknown", "Ban removido", nil, identifier)
        LogAdminAction(adminName, "DESBANIR", "Unknown", "Identifier: " .. identifier)
        InvalidateBanCache()
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Unban',
            description = 'Player desbанido com sucesso!',
            type = 'success'
        })
        
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Erro',
            description = 'Ban não encontrado!',
            type = 'error'
        })
    end
end)

-- ============================================
-- KICK PLAYER
-- ============================================

RegisterServerEvent('esx_admin:kickPlayer')
AddEventHandler('esx_admin:kickPlayer', function(playerId, reason)
    local src = source
    local valid, err = ValidateAdminAction(src, playerId)
    
    if not valid then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Erro',
            description = err,
            type = 'error'
        })
        return
    end
    
    local xTarget = ESX.GetPlayerFromId(playerId)
    local adminName = GetPlayerName(src)
    local targetName = GetPlayerName(playerId)
    local targetIdentifier = xTarget.getIdentifier()
    
    SendDiscordBanLog("KICK", adminName, targetName, reason, nil, targetIdentifier)
    LogAdminAction(adminName, "KICKAR", targetName, "Razão: " .. reason)
    
    DropPlayer(playerId, string.format('Você foi kickado.\nRazão: %s\nKickado por: %s', reason, adminName))
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Kick',
        description = string.format('%s foi kickado por: %s', targetName, reason),
        type = 'success'
    })

end)

-- ============================================
-- WARN PLAYER
-- ============================================

RegisterServerEvent('esx_admin:warnPlayer')
AddEventHandler('esx_admin:warnPlayer', function(playerId, reason)
    local src = source
    local valid, err = ValidateAdminAction(src, playerId)
    
    if not valid then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Erro',
            description = err,
            type = 'error'
        })
        return
    end
    
    local xTarget = ESX.GetPlayerFromId(playerId)
    local adminName = GetPlayerName(src)
    local targetName = GetPlayerName(playerId)
    local targetIdentifier = xTarget.getIdentifier()
    
    SendDiscordBanLog("WARN", adminName, targetName, reason, nil, targetIdentifier)
    LogAdminAction(adminName, "AVISAR", targetName, "Razão: " .. reason)
    
    TriggerClientEvent('ox_lib:notify', playerId, {
        title = 'Aviso',
        description = string.format('Você recebeu um aviso por: %s', reason),
        type = 'warning',
        duration = 5000
    })
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Aviso',
        description = string.format('%s foi avisado por: %s', targetName, reason),
        type = 'success'
    })
    
end)

-- ============================================
-- VERIFICAR BAN AO CONECTAR
-- ============================================

AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals)
    deferrals.defer()
    
    local src = source
    local identifiers = GetPlayerIdentifiers(src)
    
    -- Guardar identifiers do player
    playerIdentifiers[src] = identifiers
    
    if not identifiers or #identifiers == 0 then
        deferrals.done()
        return
    end
    
    Citizen.CreateThread(function()
        Wait(1000)
        
        if not src or src == 0 then
            deferrals.done()
            return
        end
        
        local identifier
        for _, id in pairs(identifiers) do
            if string.sub(id, 1, string.len('license:')) == 'license:' then
                identifier = id
                break
            end
        end
        
        if identifier then
            -- Verificar cache primeiro
            local cachedBan = GetBanFromCache(identifier)
            local result
            
            if cachedBan then
                result = {cachedBan}
            else
                result = exports.oxmysql:fetch_async('SELECT * FROM bans WHERE identifier = ? LIMIT 1', {identifier})
            end
            
            if result and #result > 0 then
                local ban = result[1]
                
                if ban.banned_until == 0 or ban.banned_until > os.time() then
                    local timeRemaining = ban.banned_until - os.time()
                    local timeLeft
                    
                    if ban.banned_until == 0 then
                        timeLeft = 'permanente'
                    elseif timeRemaining < 60 then
                        timeLeft = math.ceil(timeRemaining) .. ' segundos'
                    elseif timeRemaining < 3600 then
                        timeLeft = math.ceil(timeRemaining / 60) .. ' minutos'
                    elseif timeRemaining < 86400 then
                        timeLeft = math.ceil(timeRemaining / 3600) .. ' horas'
                    else
                        timeLeft = math.ceil(timeRemaining / 86400) .. ' dias'
                    end
                    
                    deferrals.done(string.format('Você está banido do servidor.\nRazão: %s\nTempo restante: %s\nBanido por: %s', 
                        ban.reason, timeLeft, ban.banned_by))
                    return
                else
                    -- Ban expirou, remover
                    exports.oxmysql:update_async('DELETE FROM bans WHERE id = ?', {ban.id})
                    InvalidateBanCache()
                end
            else
                -- Guardar no cache se não tem ban
                SetBanCache(identifier, nil)
            end
        end
        
        deferrals.done()
    end)
end)

-- ============================================
-- VARIÁVEIS DO SISTEMA DE CLIMA E HORA (vSync)
-- ============================================

local CurrentWeather = "EXTRASUNNY"
local baseTime = 0
local timeOffset = 0
local freezeTime = false
local blackout = false
local DynamicWeather = true

local AvailableWeatherTypes = {
    'EXTRASUNNY', 
    'CLEAR', 
    'NEUTRAL', 
    'SMOG', 
    'FOGGY', 
    'OVERCAST', 
    'CLOUDS', 
    'CLEARING', 
    'RAIN', 
    'THUNDER', 
    'SNOW', 
    'BLIZZARD', 
    'SNOWLIGHT', 
    'XMAS', 
    'HALLOWEEN',
}

-- ============================================
-- FUNÇÕES DE TEMPO E CLIMA
-- ============================================

function ShiftToMinute(minute)
    timeOffset = timeOffset - ( ( (baseTime+timeOffset) % 60 ) - minute )
end

function ShiftToHour(hour)
    timeOffset = timeOffset - ( ( ((baseTime+timeOffset)/60) % 24 ) - hour ) * 60
end

function SyncTimeWeather()
    TriggerClientEvent('vSync:updateWeather', -1, CurrentWeather, blackout)
    TriggerClientEvent('vSync:updateTime', -1, baseTime, timeOffset, freezeTime)
end

-- ============================================
-- EVENTO: MUDAR CLIMA
-- ============================================

RegisterServerEvent('esx_modoadmin:setWeather')
AddEventHandler('esx_modoadmin:setWeather', function(weather)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not HasAdminPerms(source) then return end
    
    local validWeather = false
    for i, wtype in ipairs(AvailableWeatherTypes) do
        if wtype == string.upper(weather) then
            validWeather = true
        end
    end
    
    if not validWeather then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Erro',
            description = 'Clima inválido!',
            type = 'error'
        })
        return
    end
    
    CurrentWeather = string.upper(weather)
    local adminName = GetPlayerName(source)
    
    SendDiscordBanLog("WEATHER CHANGE", adminName, "N/A", "Clima alterado para: " .. CurrentWeather, nil, nil)
    LogAdminAction(adminName, "MUDOU CLIMA", "N/A", "Novo clima: " .. CurrentWeather)
    
    SyncTimeWeather()
    
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Clima',
        description = 'Clima alterado para: ' .. CurrentWeather,
        type = 'success'
    })
end)

-- ============================================
-- EVENTO: MUDAR HORA
-- ============================================

RegisterServerEvent('esx_modoadmin:setTime')
AddEventHandler('esx_modoadmin:setTime', function(hour, minute)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not HasAdminPerms(source) then return end
    
    if hour < 24 then
        ShiftToHour(hour)
    else
        ShiftToHour(0)
    end
    
    if minute < 60 then
        ShiftToMinute(minute)
    else
        ShiftToMinute(0)
    end
    
    local adminName = GetPlayerName(source)
    
    SendDiscordBanLog("TIME CHANGE", adminName, "N/A", string.format("Hora alterada para %02d:%02d", hour, minute), nil, nil)
    LogAdminAction(adminName, "MUDOU HORA", "N/A", string.format("Nova hora: %02d:%02d", hour, minute))
    
    SyncTimeWeather()
    
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Hora',
        description = string.format('Hora alterada para %02d:%02d', hour, minute),
        type = 'success'
    })
end)

-- ============================================
-- THREAD: ATUALIZAR HORA E CLIMA
-- ============================================

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local newBaseTime = os.time(os.date("!*t"))/2 + 360
        if freezeTime then
            timeOffset = timeOffset + baseTime - newBaseTime			
        end
        baseTime = newBaseTime
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000)
        SyncTimeWeather()
    end
end)

-- ============================================
-- EVENTO: SPAWN VEÍCULO
-- ============================================

RegisterServerEvent('esx_modoadmin:spawnVehicle')
AddEventHandler('esx_modoadmin:spawnVehicle', function(model, vehicleName)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not HasAdminPerms(source) then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Erro',
            description = 'Sem permissão!',
            type = 'error'
        })
        return
    end
    
    local adminName = GetPlayerName(source)
    
    SendDiscordBanLog("SPAWN VEÍCULO", adminName, "N/A", "Veículo: " .. vehicleName .. " (Modelo: " .. model .. ")", nil, nil)
    LogAdminAction(adminName, "SPAWN VEÍCULO", "N/A", "Veículo: " .. vehicleName)
    
end)
