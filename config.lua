Config = {}

-- Webhook Discord (deixe vazio ou coloque sua URL)
Config.DiscordWebhook = ""
Config.DiscordLogs = false

-- Cooldown entre comandos (em segundos)
Config.CommandCooldown = 5

-- Job padrão ao entrar em staff
Config.StaffJob = "adminmdev"

-- Distância para mostrar IDs (modo normal - players)
Config.IDDistanceNormal = 4.5

-- Distância para mostrar IDs (modo staff - todos)
Config.IDDistanceStaff = 50

-- ============================================
-- GRUPOS COM PERMISSÃO DE STAFF
-- ============================================

Config.StaffGroups = {
    ['admin'] = true,
    ['mod'] = true,
    ['superadmin'] = true,
}

-- ============================================
-- CONFIGURAÇÃO DE ROUPAS POR GÊNERO
-- ============================================

local staffClothes = {
    male = {
        ['helmet_1'] = 91, 
        ['helmet_2'] = 0, 
        ['tshirt_1'] = 15, 
        ['tshirt_2'] = 0, 
        ['torso_1'] = 178, 
        ['torso_2'] = 0,
        ['decals_1'] = 0, 
        ['decals_2'] = 0,
        ['arms'] = 1,
        ['pants_1'] = 77, 
        ['pants_2'] = 0,
        ['shoes_1'] = 55, 
        ['shoes_2'] = 0,
    }, 
    female = {
        ['helmet_1'] = 114, 
        ['helmet_2'] = 24, 
        ['tshirt_1'] = 14, 
        ['tshirt_2'] = 0, 
        ['torso_1'] = 180, 
        ['torso_2'] = 5,
        ['decals_1'] = 0, 
        ['decals_2'] = 0,
        ['arms'] = 14,
        ['pants_1'] = 79, 
        ['pants_2'] = 5,
        ['shoes_1'] = 58, 
        ['shoes_2'] = 5,
    }
}

-- ============================================
-- CONFIGURAÇÃO DE GRUPOS DE ADMIN
-- ============================================

Config.Admins = {
    ["admin"] = { 
        ped = false,
        cloth = staffClothes,
    },
    ["mod"] = { 
        ped = false,
        cloth = staffClothes,
    },
    ["superadmin"] = { 
        ped = false,
        cloth = staffClothes,
    }
}

Config.Reports = {
    MaxReportsPerPlayer = 3, -- Máximo de reports por player por sessão
    ReportCooldown = 300, -- 5 minutos cooldown entre reports
    DiscordWebhook = Config.DiscordWebhook, -- Usar o mesmo webhook
}

Config.Locations = {
    Drogas = {
        {name = "Apanha Cannabis", coords = vector3(2034.58, 4882.59, 42.88)},
        {name = "Processo Cannabis", coords = vector3(1408.75, 3667.7, 35.03)},
        {name = "Apanha Cocaina", coords = vector3(3372.5, 5469.75, 18.71)},
        {name = "Processo Cocaina", coords = vector3(1389.14, 3605.46, 38.94)},
        {name = "Apanha Opio", coords = vector3(302.21, 4304.97, 46.24)},
        {name = "Processo Opio", coords = vector3(2328.13, 2569.99, 46.68)},
    },
    Vendas = {
        {name = "Venda Ilegal", coords = vector3(-3.19, -1821.75, 28.54)},
        {name = "Venda Legal", coords = vector3(-1172.0, -1572.0, 3.66)},
    },
    Organizacoes = {
        {name = "HQ Máfia", coords = vector3(0.0, 0.0, 0.0)},
        {name = "HQ Sinaloa", coords = vector3(0.0, 0.0, 0.0)},
        {name = "HQ Cartel", coords = vector3(0.0, 0.0, 0.0)},
        {name = "HQ Yakuza", coords = vector3(0.0, 0.0, 0.0)},
    }
}

Config.Vehicles = {
    {name = "Adder", model = "adder"},
    {name = "Sultan RS", model = "sultanrs"},
    {name = "Turismo R", model = "turismor"},
    {name = "Zentorno", model = "zentorno"},
    {name = "T20", model = "t20"},
    {name = "Entity XF", model = "entityxf"},
    {name = "Tyrus", model = "tyrus"},
    {name = "Osiris", model = "osiris"},
    {name = "Cyclone", model = "cyclone"},
    {name = "Vigilante", model = "vigilante"},
    {name = "Itali GTB", model = "italigtb"},
    {name = "Itali RTB", model = "italirtb"},
    {name = "FMJ", model = "fmj"},
    {name = "XA-21", model = "xa21"},
    {name = "Pariah", model = "pariah"},
    {name = "Raiden", model = "raiden"},
    {name = "Tezeract", model = "tezeract"},
    {name = "Nero Custom", model = "nero2"},
    {name = "Deveste Eight", model = "deveste"},
    {name = "Emerus", model = "emerus"},
    {name = "Komoda", model = "komoda"},
    {name = "Imorgon", model = "imorgon"},
    {name = "Krieger", model = "krieger"},
    {name = "Jester RR", model = "jesterrr"},
    {name = "Fugitive", model = "fugitive"},
    {name = "Granger", model = "granger"},
    {name = "Dubsta 6x6", model = "dubsta3"},
    {name = "Kamacho", model = "kamacho"},
    {name = "Riata", model = "riata"},
    {name = "Baller LE", model = "ballerle"},
}

Config.CoordDisplayPosition = 'top' -- 'top', 'center', 'bottom'
