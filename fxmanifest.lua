fx_version "cerulean"
game "gta5"
author "Pickle Mods"
description "The Hitman System for FiveM"
version "v1.0.2"

ui_page "nui/index.html"

data_file 'DLC_ITYP_REQUEST' 'stream/*.ytyp'

files {
	"nui/index.html",
	"nui/images/*.*",
	"nui/assets/**/*.*",
	"nui/debug.js",
}

shared_scripts {
	"@ox_lib/init.lua",
	"config.lua",
	"locales/locale.lua",
    "locales/translations/*.lua",
	"modules/**/shared.lua",
    "core/shared.lua"
}

client_scripts {
	"bridge/**/**/client.lua",
	"modules/**/client.lua",
    "core/client.lua"
}

server_scripts {
	"@mysql-async/lib/MySQL.lua",
	"bridge/**/**/server.lua",
	"modules/**/server.lua",
}

lua54 'yes'

escrow_ignore {
	"config.lua",
	"__INSTALL/**/*.*",
	"bridge/**/**/*.*",
	"bridge/**/*.*",
    "locales/locale.lua",
    "locales/translations/*.lua",
}