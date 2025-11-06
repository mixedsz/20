fx_version 'cerulean'
games {"gta5"}
author "Opod"
description "Report System"
version '1.0.0'
lua54 'yes'

shared_scripts {
  '@ox_lib/init.lua',
  '@es_extended/imports.lua',
  './shared/*.lua',
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  './server.lua',
}

client_scripts {
  './client.lua'
}

ui_page 'web/build/index.html'

files {
  'web/build/index.html',
  'web/build/**/*'
}