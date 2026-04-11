Config = {}

-- ─────────────────────────────────────────────────────────────────────────────
--  Discord Webhooks
-- ─────────────────────────────────────────────────────────────────────────────
-- General action log (kicks, warns, weather, inventory views, etc.)
Config.DiscordWebhook = 'YOUR_DISCORD_WEBHOOK_URL'

-- Server name / bot display name shown in Discord embeds
Config.ServerName  = 'My FiveM Server'
Config.BotName     = 'Admin Bot'
Config.BotAvatar   = ''   -- optional URL to bot avatar image

-- ─────────────────────────────────────────────────────────────────────────────
--  Permissions
-- ─────────────────────────────────────────────────────────────────────────────
-- ESX groups that are allowed to open the admin menu
Config.AdminGroups = { 'admin', 'superadmin', 'mod' }

-- ─────────────────────────────────────────────────────────────────────────────
--  Player ID display
-- ─────────────────────────────────────────────────────────────────────────────
-- Maximum distance (in metres) at which player IDs are drawn overhead
Config.IDDistance = 20.0

-- ─────────────────────────────────────────────────────────────────────────────
--  Teleport locations
-- ─────────────────────────────────────────────────────────────────────────────
Config.Locations = {
    { name = 'Mission Row PD',    coords = vector3(441.3,  -982.8,  30.7)  },
    { name = 'Sandy Shores PD',   coords = vector3(1853.2, 3686.6, 34.3)  },
    { name = 'LSIA Airport',      coords = vector3(-1037.5,-2737.6, 20.2)  },
    { name = 'Maze Bank Arena',   coords = vector3(-264.1, -2056.8, 26.4)  },
    { name = 'Mount Chiliad',     coords = vector3(450.0,  5512.0, 776.0)  },
    { name = 'Prison (Bolingbroke)', coords = vector3(1635.1, 2500.8, 45.6)  },
    { name = 'Fort Zancudo',      coords = vector3(-2047.0, 3132.0, 32.8)  },
    { name = 'Vinewood Hills',    coords = vector3(-673.0, 576.0, 145.0)  },
}

-- ─────────────────────────────────────────────────────────────────────────────
--  Weather types
-- ─────────────────────────────────────────────────────────────────────────────
Config.WeatherTypes = {
    'EXTRASUNNY',
    'CLEAR',
    'CLOUDS',
    'OVERCAST',
    'RAIN',
    'THUNDER',
    'SMOG',
    'FOGGY',
    'XMAS',
    'SNOWLIGHT',
    'BLIZZARD',
    'NEUTRAL',
}

-- ─────────────────────────────────────────────────────────────────────────────
--  Vehicle spawn menu
-- ─────────────────────────────────────────────────────────────────────────────
Config.Vehicles = {
    ['Super Cars'] = {
        'adder', 'zentorno', 'turismor', 'osiris',
        't20', 'nero', 'italigtb2', 'reaper', 'fmj',
    },
    ['Sports Cars'] = {
        'jester', 'sultan', 'comet2', 'elegy2',
        'tropos', 'italigtb',
    },
    ['Emergency'] = {
        'police', 'police2', 'police3', 'sheriff',
        'ambulance', 'firetruk', 'lguard',
    },
    ['Helicopters'] = {
        'buzzard', 'maverick', 'annihilator', 'polmav',
        'frogger', 'supervolito',
    },
    ['Boats'] = {
        'dinghy', 'speeder', 'toro', 'jetmax',
    },
    ['Planes'] = {
        'lazer', 'hydra', 'besra', 'titan',
    },
}

-- ─────────────────────────────────────────────────────────────────────────────
--  Ban durations
-- ─────────────────────────────────────────────────────────────────────────────
-- `time` is in seconds; -1 means permanent
Config.BanDurations = {
    { label = '1 Hour',   time = 3600       },
    { label = '6 Hours',  time = 21600      },
    { label = '12 Hours', time = 43200      },
    { label = '1 Day',    time = 86400      },
    { label = '3 Days',   time = 259200     },
    { label = '7 Days',   time = 604800     },
    { label = '14 Days',  time = 1209600    },
    { label = '30 Days',  time = 2592000    },
    { label = 'Permanent',time = -1         },
}
