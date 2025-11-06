shared_script '@WaveShield/resource/include.lua'

fx_version 'cerulean'
games {"gta5", "rdr3"}
author "Opod"
title "Report System"
version '1.0.0'
lua54 'yes'
shared_scripts {
  '@ox_lib/init.lua',
  '@es_extended/imports.lua',
  './shared/*.lua',
}
server_scripts {
  '@oxmysql/lib/MySQL.lua',
  './modules/**/server/*.lua',
  './server.lua',
}
client_scripts {
  './modules/**/client/*.lua',
  './client.lua'
}
ui_page 'web/build/index.html'
files {
  'web/build/index.html',
  'web/build/**/*'
}
