local ESX = exports["es_extended"]:getSharedObject()

-- Event para receber o grupo do player
RegisterNetEvent('esx:setGroup')
AddEventHandler('esx:setGroup', function(g)
    group = g
    
    -- Verificar se está em um grupo de staff
    if Config.StaffGroups and Config.StaffGroups[g] then

    end
end)

-- Trigger para pedir o grupo ao server
Citizen.CreateThread(function()
    Wait(2000)
    TriggerServerEvent('esx:getGroup')
end)

-- ✅ IMPORTAR OX_LIB
local lib = nil
Citizen.CreateThread(function()
    while not lib do
        lib = exports.ox_lib
        Wait(100)
    end

end)

-- Aguardar que Config seja carregado
while not Config do
    Wait(100)
end

-- Variáveis de Estado
local IsAdminMod = false
local godmode = false
local teleporte = false
local estadom = false
local checkm = true
local group = nil
local previousSkin = {}
local staffTag = nil
local coordsEnabled = false

playerDistances = {}


-- ============================================
-- EVENTOS DE STAFF
-- ============================================

RegisterNetEvent('es_admin:setGroup')
AddEventHandler('es_admin:setGroup', function(g)

    group = g
end)

RegisterNetEvent('entraradmin')
AddEventHandler('entraradmin', function(id, name, groupType)
    local myId = PlayerId()
    local pid = GetPlayerFromServerId(id)
    
    if pid == myId then

        
        if not Config or not Config.Admins or not Config.Admins[groupType] then 

            return 
        end
        
        IsAdminMod = true
        godmode = true
        
        -- Se tem ped configurado
        if Config.Admins[groupType].ped then
            if IsModelInCdimage(Config.Admins[groupType].ped) and IsModelValid(Config.Admins[groupType].ped) then
                RequestModel(Config.Admins[groupType].ped)
                while not HasModelLoaded(Config.Admins[groupType].ped) do
                    Wait(10)
                end
                SetPlayerModel(PlayerId(), Config.Admins[groupType].ped)
                SetModelAsNoLongerNeeded(Config.Admins[groupType].ped)
            else 

            end 
        -- Se tem roupa configurada
        elseif Config.Admins[groupType].cloth then 
            TriggerEvent('skinchanger:getSkin', function(skin)
                if not skin then 

                    return 
                end
                
                -- Guardar roupa anterior
                previousSkin = skin
                
                -- Aplicar roupa de staff
                local outfit = (skin.sex == 1 and Config.Admins[groupType].cloth.female or Config.Admins[groupType].cloth.male)
                TriggerEvent('skinchanger:loadClothes', skin, outfit)

            end)
        end
        
        -- Criar tag acima da cabeça
        CreateStaffTag()
        
        TriggerEvent('ox_lib:notify', {
            title = "Modo Staff",
            description = "Você entrou em modo staff!",
            type = "success",
            duration = 5000
        })
    else
        TriggerEvent('ox_lib:notify', {
            title = "Staff Online",
            description = name .. " entrou em modo staff!",
            type = "info",
            duration = 5000
        })
    end
end)

RegisterNetEvent('sairadmin')
AddEventHandler('sairadmin', function(id, name, groupType)
    local myId = PlayerId()
    local pid = GetPlayerFromServerId(id)
    
    if pid == myId then
        
        if not Config or not Config.Admins or not Config.Admins[groupType] then 
            return 
        end
        
        IsAdminMod = false
        godmode = false
        coordsEnabled = false  -- DESATIVAR COORDENADAS
        
        -- Remover tag de staff
        if staffTag then
            RemoveMpGamerTag(staffTag)
            staffTag = nil
        end
        
        -- Se tinha ped, restaurar modelo padrão
        if Config.Admins[groupType].ped then
            TriggerEvent('skinchanger:getSkin', function(skin)
                local model = skin.sex == 1 and `mp_f_freemode_01` or `mp_m_freemode_01`
                
                if IsModelInCdimage(model) and IsModelValid(model) then
                    RequestModel(model)
                    while not HasModelLoaded(model) do
                        Wait(10)
                    end
                    SetPlayerModel(PlayerId(), model)
                    SetModelAsNoLongerNeeded(model)
                    TriggerEvent('skinchanger:loadSkin', skin)
                    TriggerEvent('esx:restoreLoadout')
                end
            end)
        -- Se tinha roupa, restaurar anterior
        elseif Config.Admins[groupType].cloth then 
            ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
                if not skin then return end 
                
                -- Se tem roupa anterior guardada, restaurar
                if previousSkin and next(previousSkin) then
                    TriggerEvent('skinchanger:loadSkin', previousSkin)
                else
                    -- Senão, carregar do banco
                    TriggerEvent('skinchanger:loadSkin', skin)
                end
            end)
        end
        
        -- Remover texto UI se existir
        exports.ox_lib:hideTextUI()
        
        TriggerEvent('ox_lib:notify', {
            title = "Modo Staff",
            description = "Você saiu do modo staff!",
            type = "info",
            duration = 5000
        })
    else
        TriggerEvent('ox_lib:notify', {
            title = "Staff Online",
            description = name .. " saiu do modo staff!",
            type = "info",
            duration = 5000
        })
    end
end)

RegisterNetEvent('tpon')
AddEventHandler('tpon', function(id, name)
    local myId = PlayerId()
    local pid = GetPlayerFromServerId(id)
    if pid == myId then
        teleporte = true
    end
end)

RegisterNetEvent('tpoff')
AddEventHandler('tpoff', function(id, name)
    local myId = PlayerId()
    local pid = GetPlayerFromServerId(id)
    if pid == myId then
        teleporte = false
    end
end)

RegisterNetEvent('sendMessageAdmOn')
AddEventHandler('sendMessageAdmOn', function(id)
    local myId = PlayerId()
    local finalid = id
    local pid = GetPlayerFromServerId(id)
    
    if (pid == myId and group ~= 'user' and IsAdminMod == true) then
        TriggerServerEvent('adminson', finalid, 1)
    elseif (group ~= 'user' and pid ~= myId and IsAdminMod == true) then
        TriggerServerEvent('adminson', finalid, 1)
    elseif (group ~= 'user' and pid == myId and IsAdminMod == false) then
        TriggerServerEvent('adminson', finalid, 2)
    elseif (group ~= 'user' and pid ~= myId and IsAdminMod == false) then
        TriggerServerEvent('adminson', finalid, 2)
    end
end)

-- ============================================
-- FUNÇÃO: CRIAR TAG DE STAFF
-- ============================================

function CreateStaffTag()
    -- Criar thread para manter a tag sempre visível
    Citizen.CreateThread(function()
        while IsAdminMod do
            local ped = PlayerPedId()
            local tagText = "[STAFF]-" .. GetPlayerName(PlayerId())
            
            -- Criar a tag apenas se não existir
            if not staffTag or not IsMpGamerTagActive(staffTag) then
                staffTag = CreateFakeMpGamerTag(ped, tagText, false, false, '', 0)
                SetMpGamerTagName(staffTag, tagText)
                SetMpGamerTagAlpha(staffTag, 2, 255)
            end
            
            -- Manter a tag visível
            if staffTag and IsMpGamerTagActive(staffTag) then
                SetMpGamerTagVisibility(staffTag, 0, true)
                SetMpGamerTagVisibility(staffTag, 2, true)
            end
            
            Wait(100)
        end
    end)
end

-- ============================================
-- DESENHO DE TEXTO 3D
-- ============================================

function DrawText3D(x, y, z, text, r, g, b)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    local dist = GetDistanceBetweenCoords(px, py, pz, x, y, z, 1)

    local scale = (1 / dist) * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    scale = scale * fov

    if onScreen then
        SetTextScale(0.0 * scale, 1.2 * scale)
        SetTextFont(0)
        SetTextProportional(1)
        SetTextColour(r, g, b, 255)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

function DrawText3D2(x, y, z, text, r, g, b)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    local dist = GetDistanceBetweenCoords(px, py, pz, x, y, z, 1)

    local scale = (1 / dist) * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    scale = scale * fov

    if onScreen then
        SetTextScale(0.0 * scale, 0.55 * scale)
        SetTextFont(0)
        SetTextProportional(1)
        SetTextColour(r, g, b, 255)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

-- ============================================
-- COMANDOS
-- ============================================

RegisterCommand("ids", function()
    estadom = not estadom
    if estadom == false then
        TriggerEvent('ox_lib:notify', {
            title = "IDs",
            description = "IDs desativados",
            type = "info",
            duration = 2000
        })
    else
        TriggerEvent('ox_lib:notify', {
            title = "IDs",
            description = "IDs ativados",
            type = "success",
            duration = 2000
        })
    end
end, false)

RegisterNetEvent("ids:desativarfoto")
AddEventHandler("ids:desativarfoto", function()
    if checkm == true then
        checkm = false
        local backupstatus = estadom
        estadom = false
        Citizen.Wait(8000)
        estadom = backupstatus
        checkm = true
    end
end)

-- ============================================
-- THREAD - MOSTRAR IDS
-- ============================================

Citizen.CreateThread(function()
    Wait(50)
    while true do
        if estadom == true then
            for _, player in ipairs(GetActivePlayers()) do
                if NetworkIsPlayerActive(player) and group ~= "user" and IsAdminMod == true then
                    if playerDistances[player] ~= nil then
                        if GetPlayerPed(player) ~= PlayerPedId() then
                            if (playerDistances[player] < Config.IDDistanceStaff) then
                                x2, y2, z2 = table.unpack(GetEntityCoords(GetPlayerPed(player), true))
                                if NetworkIsPlayerTalking(player) then
                                    DrawText3D(x2, y2, z2 + 1, GetPlayerServerId(player) .. ' | ' .. GetPlayerName(player), 247, 124, 24)
                                else
                                    DrawText3D(x2, y2, z2 + 1, GetPlayerServerId(player) .. ' | ' .. GetPlayerName(player), 255, 255, 255)
                                end
                            end
                        end
                    end
                elseif NetworkIsPlayerActive(player) then
                    if GetPlayerPed(player) ~= PlayerPedId() then
                        if playerDistances[player] ~= nil then
                            if (playerDistances[player] < Config.IDDistanceNormal) and HasEntityClearLosToEntity(PlayerPedId(), GetPlayerPed(player), 17) then
                                x2, y2, z2 = table.unpack(GetEntityCoords(GetPlayerPed(player), true))
                                if NetworkIsPlayerTalking(player) then
                                    DrawText3D2(x2, y2, z2 + 1, GetPlayerServerId(player), 56, 176, 222)
                                else
                                    DrawText3D2(x2, y2, z2 + 1, GetPlayerServerId(player), 255, 255, 255)
                                end
                            end
                        end
                    end
                end
            end
        elseif checkm == false then
            HideHudAndRadarThisFrame()
        end
        Citizen.Wait(0)
    end
end)

-- ============================================
-- THREAD - DISTÂNCIA DE PLAYERS
-- ============================================

Citizen.CreateThread(function()
    while true do
        for _, player in ipairs(GetActivePlayers()) do
            if GetPlayerPed(player) ~= PlayerPedId() then
                x1, y1, z1 = table.unpack(GetEntityCoords(PlayerPedId(), true))
                x2, y2, z2 = table.unpack(GetEntityCoords(GetPlayerPed(player), true))
                distance = math.floor(GetDistanceBetweenCoords(x1, y1, z1, x2, y2, z2, true))
                playerDistances[player] = distance
            end
        end
        Citizen.Wait(3000)
    end
end)

-- ============================================
-- THREAD - GODMODE
-- ============================================

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)
        if group ~= "user" and IsAdminMod == true and godmode == true then
            local ped = PlayerPedId()
            
            -- Godmode
            SetEntityInvincible(ped, true)
            SetPlayerInvincible(PlayerId(), true)
            SetPedCanRagdoll(ped, false)
            ClearPedBloodDamage(ped)
            ResetPedVisibleDamage(ped)
            ClearPedLastWeaponDamage(ped)
            SetEntityProofs(ped, true, true, true, true, true, true, true, true)
            SetEntityCanBeDamaged(ped, false)
            
            -- Vida ao máximo
            SetEntityHealth(ped, GetEntityMaxHealth(ped))
            
            -- Armadura ao máximo
            AddArmourToPed(ped, 100)
            
        elseif group ~= "user" and IsAdminMod == false and godmode == false then
            local ped = PlayerPedId()
            
            SetEntityInvincible(ped, false)
            SetPlayerInvincible(PlayerId(), false)
            SetPedCanRagdoll(ped, true)
            ClearPedLastWeaponDamage(ped)
            SetEntityProofs(ped, false, false, false, false, false, false, false, false)
            SetEntityCanBeDamaged(ped, true)
        end
    end
end)
-- ============================================
-- KEYBIND F10 - MENU ADMIN
-- ============================================

Citizen.CreateThread(function()
    while true do
        Wait(0)
        
        if IsControlJustReleased(0, 57) then
            if IsAdminMod then
                OpenAdminMenu()
            end
        end
    end
end)

-- ============================================
-- MENU PRINCIPAL ADMIN
-- ============================================

function OpenAdminMenu()
    local options = {
        {
            title = "📦 Ver Inventário de Player",
            description = "Visualizar items de um player",
            icon = 'fa-solid fa-box',
            onSelect = function()
                SelectPlayerForInventory()
            end
        },
        {
            title = "👥 Ver Players Online",
            description = "Lista de todos os players",
            icon = 'fa-solid fa-users',
            onSelect = function()
                ShowPlayersOnline()
            end
        },
        {
            title = "🚫 Banimentos",
            description = "Gerenciar banimentos de players",
            icon = 'fa-solid fa-gavel',
            onSelect = function()
                OpenBanishmentsMenu()
            end
        },
        {
            title = "📍 Coordenadas",
            description = "Gerenciar coordenadas e teleportes",
            icon = 'fa-solid fa-location-dot',
            onSelect = function()
                OpenCoordsMenu()
            end
        },
        {
            title = "🚗 Spawn Veículo",
            description = "Spawnar um veículo",
            icon = 'fa-solid fa-car',
            onSelect = function()
                SpawnVehicleMenu()
            end
        },
        {
            title = "🌤️ Clima",
            description = "Alterar clima do servidor",
            icon = 'fa-solid fa-cloud',
            onSelect = function()
                OpenWeatherMenu()
            end
        },
        {
            title = "⏰ Hora",
            description = "Definir hora do servidor",
            icon = 'fa-solid fa-clock',
            onSelect = function()
                OpenTimeMenu()
            end
        },
        {
            title = "👻 Invisibilidade",
            description = "Ficar invisível",
            icon = 'fa-solid fa-eye-slash',
            onSelect = function()
                ToggleInvisibility()
            end
        },
        {
            title = "🔄 Sair de Staff",
            description = "Desativar modo staff",
            icon = 'fa-solid fa-sign-out-alt',
            onSelect = function()
                ExecuteCommand('sairstaff')
            end
        }
    }
    
    exports.ox_lib:registerContext({
        id = 'admin_main_menu',
        title = "🛡️ Menu Admin - F10",
        options = options
    })
    
    exports.ox_lib:showContext('admin_main_menu')
end

-- ============================================
-- MENU DE COORDENADAS
-- ============================================

function OpenCoordsMenu()
    local options = {
        {
            title = "📍 Ativar Coordenadas",
            description = "Mostrar coordenadas na tela",
            icon = 'fa-solid fa-eye',
            onSelect = function()
                OpenCoordsDisplayMenu()
            end
        },
        {
            title = "🗺️ Teleportar Para",
            description = "Teleportar para locais pré-definidos",
            icon = 'fa-solid fa-location-crosshairs',
            onSelect = function()
                OpenTeleportMenu()
            end
        },
        {
            title = "← Voltar",
            description = "Voltar ao menu anterior",
            icon = 'fa-solid fa-arrow-left',
            onSelect = function()
                OpenAdminMenu()
            end
        }
    }
    
    exports.ox_lib:registerContext({
        id = 'admin_coords_menu',
        title = "📍 Menu de Coordenadas",
        options = options
    })
    
    exports.ox_lib:showContext('admin_coords_menu')
end

-- ============================================
-- MENU DE TELEPORTE
-- ============================================

function OpenTeleportMenu()
    local options = {
        {
            title = "💊 Drogas",
            description = "Teleportar para locais de drogas",
            icon = 'fa-solid fa-leaf',
            onSelect = function()
                OpenTeleportCategoryMenu("Drogas")
            end
        },
        {
            title = "💰 Vendas",
            description = "Teleportar para locais de venda",
            icon = 'fa-solid fa-money-bill',
            onSelect = function()
                OpenTeleportCategoryMenu("Vendas")
            end
        },
        {
            title = "🏢 Organizações",
            description = "Teleportar para sedes de organizações",
            icon = 'fa-solid fa-building',
            onSelect = function()
                OpenTeleportCategoryMenu("Organizacoes")
            end
        },
        {
            title = "← Voltar",
            description = "Voltar ao menu anterior",
            icon = 'fa-solid fa-arrow-left',
            onSelect = function()
                OpenCoordsMenu()
            end
        }
    }
    
    exports.ox_lib:registerContext({
        id = 'admin_teleport_menu',
        title = "🗺️ Teleportar Para",
        options = options
    })
    
    exports.ox_lib:showContext('admin_teleport_menu')
end

-- ============================================
-- MENU DE TELEPORTE POR CATEGORIA
-- ============================================

function OpenTeleportCategoryMenu(category)
    local options = {}
    local locations = Config.Locations[category]
    
    if not locations then
        exports.ox_lib:notify({
            title = "Erro",
            description = "Categoria não encontrada!",
            type = "error"
        })
        return
    end
    
    for i, location in ipairs(locations) do
        table.insert(options, {
            title = location.name,
            description = string.format("X: %.2f | Y: %.2f | Z: %.2f", location.coords.x, location.coords.y, location.coords.z),
            icon = 'fa-solid fa-map-pin',
            onSelect = function()
                TeleportToLocation(location.coords, location.name)
            end
        })
    end
    
    table.insert(options, {
        title = "← Voltar",
        description = "Voltar ao menu anterior",
        icon = 'fa-solid fa-arrow-left',
        onSelect = function()
            OpenTeleportMenu()
        end
    })
    
    exports.ox_lib:registerContext({
        id = 'admin_teleport_category_' .. category,
        title = "🗺️ " .. category,
        options = options
    })
    
    exports.ox_lib:showContext('admin_teleport_category_' .. category)
end

-- ============================================
-- MENU DE EXIBIÇÃO DE COORDENADAS
-- ============================================

function OpenCoordsDisplayMenu()
    local options = {
        {
            title = "✅ Ativar Coordenadas",
            description = "Mostrar suas coordenadas na tela",
            icon = 'fa-solid fa-check',
            onSelect = function()
                coordsEnabled = true
                StartCoordsDisplay()
                exports.ox_lib:notify({
                    title = "Coordenadas",
                    description = "Coordenadas ativadas!",
                    type = "success",
                    duration = 2000
                })
                OpenCoordsMenu()
            end
        },
        {
            title = "❌ Desativar Coordenadas",
            description = "Parar de mostrar coordenadas",
            icon = 'fa-solid fa-xmark',
            onSelect = function()
                coordsEnabled = false
                exports.ox_lib:notify({
                    title = "Coordenadas",
                    description = "Coordenadas desativadas!",
                    type = "info",
                    duration = 2000
                })
                OpenCoordsMenu()
            end
        },
        {
            title = "← Voltar",
            description = "Voltar ao menu anterior",
            icon = 'fa-solid fa-arrow-left',
            onSelect = function()
                OpenCoordsMenu()
            end
        }
    }
    
    exports.ox_lib:registerContext({
        id = 'admin_coords_display_menu',
        title = "📍 Exibição de Coordenadas",
        options = options
    })
    
    exports.ox_lib:showContext('admin_coords_display_menu')
end

-- ============================================
-- THREAD - EXIBIR COORDENADAS
-- ============================================


function StartCoordsDisplay()
    -- Disparar evento para log (ativar)
    TriggerServerEvent('esx_modoadmin:toggleCoords', true)
    
    Citizen.CreateThread(function()
        while coordsEnabled do
            local ped = PlayerPedId()
            local x, y, z = table.unpack(GetEntityCoords(ped))
            local heading = GetEntityHeading(ped)
            
            local text = string.format('X: %.2f | Y: %.2f | Z: %.2f | H: %.2f', x, y, z, heading)
            
            -- Desenhar usando ox_lib
            exports.ox_lib:showTextUI(text, {
                position = "top-center",
                icon = 'fa-solid fa-location-dot',
                style = {
                    borderRadius = 10,
                    backgroundColor = '#1a1a1a',
                    color = '#00ff00'
                }
            })
            
            Wait(0)
        end
        
        exports.ox_lib:hideTextUI()
        -- Disparar evento para log (desativar)
        TriggerServerEvent('esx_modoadmin:toggleCoords', false)
    end)
end

-- ============================================
-- FUNÇÃO: TELEPORTAR
-- ============================================

function TeleportToLocation(coords, locationName)
    local ped = PlayerPedId()
    
    -- Encontrar chão
    local x, y, z = coords.x, coords.y, coords.z
    local groundZ = z
    
    for i = z, z - 100, -1.0 do
        if GetGroundZFor_3dCoord(x, y, i, groundZ, false) then
            break
        end
    end
    
    -- Teleportar
    SetEntityCoordsNoOffset(ped, x, y, groundZ, false, false, false)
    
    -- Disparar evento para log
    TriggerServerEvent('esx_modoadmin:teleportToLocation', locationName)
    
    exports.ox_lib:notify({
        title = "Teleporte",
        description = "Teleportado para: " .. locationName,
        type = "success",
        duration = 3000
    })
end

-- ============================================
-- MENU DE BANIMENTOS (SUBMENU)
-- ============================================

function OpenBanishmentsMenu()
    local options = {
        {
            title = "🔨 Banir Player",
            description = "Banir um player do servidor",
            icon = 'fa-solid fa-ban',
            onSelect = function()
                SelectPlayerForBan()
            end
        },
        {
            title = "👋 Kickar Player",
            description = "Kickar um player do servidor",
            icon = 'fa-solid fa-door-open',
            onSelect = function()
                SelectPlayerForKick()
            end
        },
        {
            title = "⚠️ Avisar Player",
            description = "Dar um aviso a um player",
            icon = 'fa-solid fa-exclamation-triangle',
            onSelect = function()
                SelectPlayerForWarn()
            end
        },
        {
            title = "🔓 Ver Lista de Bans",
            description = "Visualizar todos os banimentos",
            icon = 'fa-solid fa-list',
            onSelect = function()
                ShowBansList()
            end
        },
        {
            title = "← Voltar",
            description = "Voltar ao menu anterior",
            icon = 'fa-solid fa-arrow-left',
            onSelect = function()
                OpenAdminMenu()
            end
        }
    }
    
    exports.ox_lib:registerContext({
        id = 'admin_banishments_menu',
        title = "🚫 Menu de Banimentos",
        options = options
    })
    
    exports.ox_lib:showContext('admin_banishments_menu')
end

-- ============================================
-- SELECIONAR PLAYER PARA BANIR
-- ============================================

function SelectPlayerForBan()
    ESX.TriggerServerCallback('esx_admin:getOnlinePlayers', function(players)
        if not players or #players == 0 then
            exports.ox_lib:notify({
                title = "Erro",
                description = "Nenhum player online!",
                type = "error",
                duration = 3000
            })
            return
        end
        
        local options = {}
        
        for i, player in ipairs(players) do
            table.insert(options, {
                title = player.name,
                description = "ID: " .. player.id,
                icon = 'fa-solid fa-user',
                onSelect = function()
                    BanPlayerMenu(player.id, player.name)
                end
            })
        end
        
        table.insert(options, {
            title = "← Voltar",
            description = "Voltar ao menu anterior",
            icon = 'fa-solid fa-arrow-left',
            onSelect = function()
                OpenBanishmentsMenu()
            end
        })
        
        exports.ox_lib:registerContext({
            id = 'admin_ban_select',
            title = "🔨 Selecione um Player para Banir",
            options = options
        })
        
        exports.ox_lib:showContext('admin_ban_select')
    end)
end

function BanPlayerMenu(playerId, playerName)
    local input = exports.ox_lib:inputDialog('Banir ' .. playerName, {
        {type = 'input', label = 'Razão do Ban', placeholder = 'Ex: Hack, Spam...', required = true},
        {type = 'select', label = 'Duração', options = {
            {label = '10 Minutos', value = 600},
            {label = '30 Minutos', value = 1800},
            {label = '1 Hora', value = 3600},
            {label = '6 Horas', value = 21600},
            {label = '12 Horas', value = 43200},
            {label = '1 Dia', value = 86400},
            {label = '3 Dias', value = 259200},
            {label = '1 Semana', value = 604800},
            {label = 'Permanente', value = 2147483647}
        }, required = true}
    })
    
    if not input then return end
    
    local reason = input[1]
    local duration = input[2]
    
    if reason == '' then
        exports.ox_lib:notify({
            title = "Erro",
            description = "Razão obrigatória!",
            type = "error"
        })
        return
    end
    
    TriggerServerEvent('esx_admin:banPlayer', playerId, reason, duration)
end

-- ============================================
-- SELECIONAR PLAYER PARA KICKAR
-- ============================================

function SelectPlayerForKick()
    ESX.TriggerServerCallback('esx_admin:getOnlinePlayers', function(players)
        if not players or #players == 0 then
            exports.ox_lib:notify({
                title = "Erro",
                description = "Nenhum player online!",
                type = "error",
                duration = 3000
            })
            return
        end
        
        local options = {}
        
        for i, player in ipairs(players) do
            table.insert(options, {
                title = player.name,
                description = "ID: " .. player.id,
                icon = 'fa-solid fa-user',
                onSelect = function()
                    KickPlayerMenu(player.id, player.name)
                end
            })
        end
        
        table.insert(options, {
            title = "← Voltar",
            description = "Voltar ao menu anterior",
            icon = 'fa-solid fa-arrow-left',
            onSelect = function()
                OpenBanishmentsMenu()
            end
        })
        
        exports.ox_lib:registerContext({
            id = 'admin_kick_select',
            title = "👋 Selecione um Player para Kickar",
            options = options
        })
        
        exports.ox_lib:showContext('admin_kick_select')
    end)
end

function KickPlayerMenu(playerId, playerName)
    local input = exports.ox_lib:inputDialog('Kickar ' .. playerName, {
        {type = 'input', label = 'Razão', placeholder = 'Ex: AFK, Comportamento...', required = true}
    })
    
    if not input or input[1] == '' then
        exports.ox_lib:notify({
            title = "Erro",
            description = "Razão obrigatória!",
            type = "error"
        })
        return
    end
    
    TriggerServerEvent('esx_admin:kickPlayer', playerId, input[1])
end

-- ============================================
-- SELECIONAR PLAYER PARA AVISAR
-- ============================================

function SelectPlayerForWarn()
    ESX.TriggerServerCallback('esx_admin:getOnlinePlayers', function(players)
        if not players or #players == 0 then
            exports.ox_lib:notify({
                title = "Erro",
                description = "Nenhum player online!",
                type = "error",
                duration = 3000
            })
            return
        end
        
        local options = {}
        
        for i, player in ipairs(players) do
            table.insert(options, {
                title = player.name,
                description = "ID: " .. player.id,
                icon = 'fa-solid fa-user',
                onSelect = function()
                    WarnPlayerMenu(player.id, player.name)
                end
            })
        end
        
        table.insert(options, {
            title = "← Voltar",
            description = "Voltar ao menu anterior",
            icon = 'fa-solid fa-arrow-left',
            onSelect = function()
                OpenBanishmentsMenu()
            end
        })
        
        exports.ox_lib:registerContext({
            id = 'admin_warn_select',
            title = "⚠️ Selecione um Player para Avisar",
            options = options
        })
        
        exports.ox_lib:showContext('admin_warn_select')
    end)
end

function WarnPlayerMenu(playerId, playerName)
    local input = exports.ox_lib:inputDialog('Avisar ' .. playerName, {
        {type = 'input', label = 'Razão', placeholder = 'Ex: Aviso por comportamento...', required = true}
    })
    
    if not input or input[1] == '' then
        exports.ox_lib:notify({
            title = "Erro",
            description = "Razão obrigatória!",
            type = "error"
        })
        return
    end
    
    TriggerServerEvent('esx_admin:warnPlayer', playerId, input[1])
end

-- ============================================
-- LISTAR BANS
-- ============================================

function ShowBansList()
    ESX.TriggerServerCallback('esx_admin:getBansList', function(bans)
        if not bans or #bans == 0 then
            exports.ox_lib:notify({
                title = "Erro",
                description = "Nenhum ban registado!",
                type = "error",
                duration = 3000
            })
            return
        end
        
        local options = {}
        
        for i, ban in ipairs(bans) do
            local status = "Permanente"
            if ban.banned_until > 0 then
                local daysLeft = math.ceil((ban.banned_until - os.time()) / 86400)
                if daysLeft > 0 then
                    status = daysLeft .. " dias"
                else
                    status = "Expirado"
                end
            end
            
            table.insert(options, {
                title = ban.identifier,
                description = "Razão: " .. ban.reason .. " | Banido por: " .. ban.banned_by .. " | " .. status,
                icon = 'fa-solid fa-ban',
                onSelect = function()
                    local confirm = exports.ox_lib:confirm({
                        title = "Desbanir?",
                        description = "Tem certeza que quer desbanir " .. ban.identifier .. "?",
                        centered = true,
                        cancel = "Cancelar"
                    })
                    
                    if confirm then
                        TriggerServerEvent('esx_admin:unbanPlayer', ban.identifier)
                        ShowBansList()
                    end
                end
            })
        end
        
        table.insert(options, {
            title = "← Voltar",
            description = "Voltar ao menu anterior",
            icon = 'fa-solid fa-arrow-left',
            onSelect = function()
                OpenBanishmentsMenu()
            end
        })
        
        exports.ox_lib:registerContext({
            id = 'admin_bans_list',
            title = "🚫 Lista de Bans (" .. #bans .. ")",
            options = options
        })
        
        exports.ox_lib:showContext('admin_bans_list')
    end)
end

-- ============================================
-- SELECIONAR PLAYER PARA VER INVENTÁRIO
-- ============================================

function SelectPlayerForInventory()
    ESX.TriggerServerCallback('esx_admin:getOnlinePlayers', function(players)
        if not players or #players == 0 then
            exports.ox_lib:notify({
                title = "Erro",
                description = "Nenhum player online!",
                type = "error",
                duration = 3000
            })
            return
        end
        
        local options = {}
        
        for i, player in ipairs(players) do
            table.insert(options, {
                title = player.name,
                description = "ID: " .. player.id .. " | Trabalho: " .. player.job,
                icon = 'fa-solid fa-user',
                onSelect = function()
                    ViewPlayerInventory(player.id, player.name)
                end
            })
        end
        
        table.insert(options, {
            title = "← Voltar",
            description = "Voltar ao menu anterior",
            icon = 'fa-solid fa-arrow-left',
            onSelect = function()
                OpenAdminMenu()
            end
        })
        
        exports.ox_lib:registerContext({
            id = 'admin_select_player',
            title = "👥 Selecione um Player",
            options = options
        })
        
        exports.ox_lib:showContext('admin_select_player')
    end)
end

-- ============================================
-- VER INVENTÁRIO DO PLAYER
-- ============================================

function ViewPlayerInventory(playerId, playerName)
    ESX.TriggerServerCallback('esx_admin:getPlayerInventory', function(inventory)
        if not inventory then
            exports.ox_lib:notify({
                title = "Erro",
                description = "Inventário não encontrado!",
                type = "error",
                duration = 3000
            })
            return
        end
        
        local options = {}
        
        table.insert(options, {
            title = "💵 Dinheiro Mão",
            description = "€" .. ESX.Math.GroupDigits(inventory.money),
            icon = 'fa-solid fa-wallet',
            disabled = true
        })
        
        table.insert(options, {
            title = "🏦 Saldo Banco",
            description = "€" .. ESX.Math.GroupDigits(inventory.bank),
            icon = 'fa-solid fa-university',
            disabled = true
        })
        
        table.insert(options, {
            title = "💰 Dinheiro Sujo",
            description = "€" .. ESX.Math.GroupDigits(inventory.black_money),
            icon = 'fa-solid fa-money-bill',
            disabled = true
        })
        
        -- ITEMS
        if inventory.items and #inventory.items > 0 then
            for i, item in ipairs(inventory.items) do
                if item.count > 0 then
                    table.insert(options, {
                        title = "  • " .. item.label,
                        description = "Quantidade: " .. item.count .. "x",
                        icon = 'fa-solid fa-cube',
                        disabled = true
                    })
                end
            end
        end
        
        -- ARMAS
        if inventory.weapons and #inventory.weapons > 0 then
            for i, weapon in ipairs(inventory.weapons) do
                table.insert(options, {
                    title = "  🔫 " .. (weapon.label or weapon.name),
                    description = "Munição: " .. (weapon.ammo or 0) .. "x",
                    icon = 'fa-solid fa-gun',
                    disabled = true
                })
            end
        end
        
        if (not inventory.items or #inventory.items == 0) and (not inventory.weapons or #inventory.weapons == 0) then
            table.insert(options, {
                title = "📦 Sem Items",
                description = "O player não tem nenhum item",
                icon = 'fa-solid fa-ban',
                disabled = true
            })
        end
        
        table.insert(options, {
            title = "← Voltar",
            description = "Voltar ao menu anterior",
            icon = 'fa-solid fa-arrow-left',
            onSelect = function()
                SelectPlayerForInventory()
            end
        })
        
        exports.ox_lib:registerContext({
            id = 'admin_inventory_' .. playerId,
            title = "📦 Inventário de " .. playerName .. " (ID: " .. playerId .. ")",
            options = options
        })
        
        exports.ox_lib:showContext('admin_inventory_' .. playerId)
    end, playerId)
end

-- ============================================
-- LISTAR PLAYERS ONLINE
-- ============================================

function ShowPlayersOnline()
    ESX.TriggerServerCallback('esx_admin:getOnlinePlayers', function(players)
        if not players or #players == 0 then
            exports.ox_lib:notify({
                title = "Erro",
                description = "Nenhum player online!",
                type = "error",
                duration = 3000
            })
            return
        end
        
        local options = {}
        
        for i, player in ipairs(players) do
            table.insert(options, {
                title = player.name,
                description = "ID: " .. player.id .. " | Trabalho: " .. player.job .. " | Dinheiro: €" .. ESX.Math.GroupDigits(player.money),
                icon = 'fa-solid fa-user'
            })
        end
        
        table.insert(options, {
            title = "← Voltar",
            description = "Voltar ao menu anterior",
            icon = 'fa-solid fa-arrow-left',
            onSelect = function()
                OpenAdminMenu()
            end
        })
        
        exports.ox_lib:registerContext({
            id = 'admin_players_list',
            title = "👥 Players Online (" .. #players .. ")",
            options = options
        })
        
        exports.ox_lib:showContext('admin_players_list')
    end)
end

-- ============================================
-- MENU DE VEÍCULOS
-- ============================================

function SpawnVehicleMenu()
    local options = {}
    
    for i, vehicle in ipairs(Config.Vehicles) do
        table.insert(options, {
            title = vehicle.name,
            description = "Modelo: " .. vehicle.model,
            icon = 'fa-solid fa-car',
            onSelect = function()
                SpawnVehicle(vehicle.model, vehicle.name)
            end
        })
    end
    
    table.insert(options, {
        title = "← Voltar",
        description = "Voltar ao menu anterior",
        icon = 'fa-solid fa-arrow-left',
        onSelect = function()
            OpenAdminMenu()
        end
    })
    
    exports.ox_lib:registerContext({
        id = 'admin_vehicles_menu',
        title = "🚗 Spawn Veículo",
        options = options
    })
    
    exports.ox_lib:showContext('admin_vehicles_menu')
end

function SpawnVehicle(model, vehicleName)
    local ped = PlayerPedId()
    local x, y, z = table.unpack(GetEntityCoords(ped))
    
    RequestModel(GetHashKey(model))
    while not HasModelLoaded(GetHashKey(model)) do
        Wait(10)
    end
    
    local veh = CreateVehicle(GetHashKey(model), x, y, z + 1, GetEntityHeading(ped), true, false)
    SetPedIntoVehicle(ped, veh, -1)
    SmashVehicleWindow(veh, 0)
    SmashVehicleWindow(veh, 1)
    SmashVehicleWindow(veh, 2)
    SmashVehicleWindow(veh, 3)
    
    SetModelAsNoLongerNeeded(GetHashKey(model))
    
    -- Enviar evento para o server registar a log
    TriggerServerEvent('esx_modoadmin:spawnVehicle', model, vehicleName)
    
    TriggerEvent('ox_lib:notify', {
        title = "Veículo",
        description = "Veículo spawnado: " .. vehicleName,
        type = "success"
    })
end

-- ============================================
-- NOCLIP
-- ============================================

local noclipEnabled = false
local noclipSpeed = 1.0

RegisterCommand("noclip", function()
    if not IsAdminMod then return end
    noclipEnabled = not noclipEnabled
    
    TriggerEvent('ox_lib:notify', {
        title = "Noclip",
        description = noclipEnabled and "Ativado" or "Desativado",
        type = "info",
        duration = 2000
    })
end, false)

Citizen.CreateThread(function()
    while true do
        if noclipEnabled and IsAdminMod then
            local ped = PlayerPedId()
            local x, y, z = table.unpack(GetEntityCoords(ped))
            
            SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
            SetEntityVisible(ped, true, false)
            SetEntityCollision(ped, false, false)
            
            if IsControlPressed(0, 32) then z = z + noclipSpeed end  -- W
            if IsControlPressed(0, 33) then z = z - noclipSpeed end  -- S
            if IsControlPressed(0, 34) then x = x - noclipSpeed end  -- A
            if IsControlPressed(0, 35) then x = x + noclipSpeed end  -- D
            
            SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
        else
            local ped = PlayerPedId()
            SetEntityCollision(ped, true, true)
        end
        Wait(0)
    end
end)

-- ============================================
-- INVISIBILIDADE
-- ============================================

function ToggleInvisibility()
    if not IsAdminMod then return end
    
    local ped = PlayerPedId()
    local isVisible = IsEntityVisible(ped)
    
    SetEntityVisible(ped, not isVisible, false)
    
    TriggerEvent('ox_lib:notify', {
        title = "Invisibilidade",
        description = not isVisible and "Invisível" or "Visível",
        type = "info",
        duration = 2000
    })
end

-- ============================================
-- CLIMA
-- ============================================

function OpenWeatherMenu()
    local options = {
        {
            title = "☀️ Ensolarado",
            description = "EXTRASUNNY",
            icon = 'fa-solid fa-sun',
            onSelect = function()
                SetWeather("EXTRASUNNY")
            end
        },
        {
            title = "🌤️ Limpo",
            description = "CLEAR",
            icon = 'fa-solid fa-cloud-sun',
            onSelect = function()
                SetWeather("CLEAR")
            end
        },
        {
            title = "⛅ Neutro",
            description = "NEUTRAL",
            icon = 'fa-solid fa-cloud',
            onSelect = function()
                SetWeather("NEUTRAL")
            end
        },
        {
            title = "💨 Smog",
            description = "SMOG",
            icon = 'fa-solid fa-smog',
            onSelect = function()
                SetWeather("SMOG")
            end
        },
        {
            title = "🌫️ Neblina",
            description = "FOGGY",
            icon = 'fa-solid fa-fog',
            onSelect = function()
                SetWeather("FOGGY")
            end
        },
        {
            title = "☁️ Nublado",
            description = "OVERCAST",
            icon = 'fa-solid fa-cloud',
            onSelect = function()
                SetWeather("OVERCAST")
            end
        },
        {
            title = "🌧️ Chuva",
            description = "RAIN",
            icon = 'fa-solid fa-cloud-rain',
            onSelect = function()
                SetWeather("RAIN")
            end
        },
        {
            title = "⛈️ Tempestade",
            description = "THUNDER",
            icon = 'fa-solid fa-bolt',
            onSelect = function()
                SetWeather("THUNDER")
            end
        },
        {
            title = "❄️ Neve",
            description = "SNOW",
            icon = 'fa-solid fa-snowflake',
            onSelect = function()
                SetWeather("SNOW")
            end
        },
        {
            title = "❄️ Blizzard",
            description = "BLIZZARD",
            icon = 'fa-solid fa-snowflake',
            onSelect = function()
                SetWeather("BLIZZARD")
            end
        },
        {
            title = "🎄 Natal",
            description = "XMAS",
            icon = 'fa-solid fa-tree',
            onSelect = function()
                SetWeather("XMAS")
            end
        },
        {
            title = "🎃 Halloween",
            description = "HALLOWEEN",
            icon = 'fa-solid fa-ghost',
            onSelect = function()
                SetWeather("HALLOWEEN")
            end
        },
        {
            title = "← Voltar",
            description = "Voltar ao menu anterior",
            icon = 'fa-solid fa-arrow-left',
            onSelect = function()
                OpenAdminMenu()
            end
        }
    }
    
    exports.ox_lib:registerContext({
        id = 'admin_weather_menu',
        title = "🌤️ Clima",
        options = options
    })
    
    exports.ox_lib:showContext('admin_weather_menu')
end

function SetWeather(weather)
    TriggerServerEvent('esx_modoadmin:setWeather', weather)
    
    TriggerEvent('ox_lib:notify', {
        title = "Clima",
        description = "Clima alterado!",
        type = "success",
        duration = 2000
    })
end

-- ============================================
-- HORA
-- ============================================

function OpenTimeMenu()
    local input = exports.ox_lib:inputDialog('Definir Hora', {
        {type = 'slider', label = 'Hora', min = 0, max = 23, default = 12},
        {type = 'slider', label = 'Minutos', min = 0, max = 59, default = 0}
    })
    
    if not input then return end
    
    local hour = input[1]
    local minute = input[2]
    
    TriggerServerEvent('esx_modoadmin:setTime', hour, minute)
    
    TriggerEvent('ox_lib:notify', {
        title = "Hora",
        description = string.format("Hora: %02d:%02d", hour, minute),
        type = "success",
        duration = 2000
    })
end

-- ============================================
-- EVENTOS DE SINCRONIZAÇÃO (vSync)
-- ============================================

RegisterNetEvent('vSync:updateWeather')
AddEventHandler('vSync:updateWeather', function(weather, blackout)
    SetWeatherTypeNow(weather)
end)

RegisterNetEvent('vSync:updateTime')
AddEventHandler('vSync:updateTime', function(base, offset, freeze)
    local hour = math.floor(((base+offset)/60)%24)
    local minute = math.floor((base+offset)%60)
    NetworkOverrideClockTime(hour, minute, 0)
end)
