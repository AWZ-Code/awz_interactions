fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

lua54 'yes'

author 'AWZ Code @AxeelWarZ - Original version: @kibook: https://github.com/kibook/redm-interactions'
description 'Interactions resource for RedM - sit on chairs, benches, beds, take baths, play piano, and more.'
version '1.0.0'

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js',
    'ui/logo.png',
    'ui/bgPanel.png',
    'ui/selection_box_badge_red.png',
    'ui/blip_ambient_ped_small.png',
    'ui/font.ttf'
}

client_scripts {
    'config.lua',
    'config_custom_models.lua',
    'config_custom_locations.lua',
    'locales/*.lua',
    'client/utils.lua',
    'shared/objects.lua',
    'shared/interactions.lua',
    'shared/custom_models.lua',
    'shared/custom_locations.lua',
    'client/main.lua'
}