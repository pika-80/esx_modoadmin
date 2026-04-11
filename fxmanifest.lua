fx_version 'cerulean'
game 'gta5'

name        'esx_modoadmin'
description 'Admin menu with godmode, tags, bans, teleport, weather, vehicle spawn and Discord logs'
version     '1.0.0'
author      'pika-80'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'es_extended',
    'ox_lib',
    'oxmysql',
    'ox_inventory',
}
