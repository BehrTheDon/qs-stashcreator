fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'Behr'
description 'QS Personal stash w/ PIN lock via OxLib & JSON persistence'
version '1.5.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

server_scripts {
    'server/server.lua'
}

client_scripts {
    'client/client.lua'
}

files {
    'stash_codes.json',
    'locales/en.json'
}
