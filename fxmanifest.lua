fx_version 'cerulean'
game 'gta5'

author 'pika80'
discord 'https://discord.gg/4Xq6AZ3nM4'
description 'ModoAdmin'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

dependencies {
    'es_extended',
    'ox_lib',
    'oxmysql'
}