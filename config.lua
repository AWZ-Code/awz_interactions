Config = {}

-- Keyboard hashes used by fixed-key prompts.
Config.Keys = {
    A = 0x7065027D, B = 0x4CC0E2FE, C = 0x9959A6F0, D = 0xB4E465B4,
    E = 0xCEFD9220, F = 0xB2F377E8, G = 0x760A9C6F, H = 0x24978A28,
    I = 0xC1989F95, J = 0xF3830D8E, L = 0x80F28E95, M = 0xE31C6A41,
    N = 0x4BC9DABB, O = 0xF1301666, P = 0xD82E0BD2, Q = 0xDE794E3E,
    R = 0xE30CD707, S = 0xD27782E3, U = 0xD8F73058, V = 0x7F8D09B8,
    W = 0x8FD015D8, X = 0x8CC9CD42, Z = 0x26E9DC00,

    NUM1 = 0xE6F612E4, NUM2 = 0x1CE6D9EB, NUM3 = 0x4F49CC4C,
    NUM4 = 0x8F9F9E58, NUM5 = 0xAB62E997, NUM6 = 0xA1FDE2A6,
    NUM7 = 0xB03A913B, NUM8 = 0x42385422,

    F1 = 0xA8E3F467, F4 = 0x1F6D95E5, F6 = 0x3C0A40F2,

    CTRL      = 0xDB096B85,
    TAB       = 0xB238FE0B,
    SHIFT     = 0x8FFC75D6,
    SPACEBAR  = 0xD9D0E1C0,
    ENTER     = 0xC7B5340A,
    BACKSPACE = 0x156F7119,
    LALT      = 0x8AAA0AD4,
    DEL       = 0x4AF4D473,
    PGUP      = 0x446258B6,
    PGDN      = 0x3C3DD371,

    LEFTBRACKET  = 0x430593AA,
    RIGHTBRACKET = 0xA5BDCD3C,

    MOUSE1 = 0x07CE1E61,
    MOUSE2 = 0xF84FA74F,
    MOUSE3 = 0xCEE12B50,
}

-- General settings.
Config.Locale = 'it'
Config.OpenKey = Config.Keys.U
Config.StopKey = Config.Keys.BACKSPACE -- Set to false/nil to disable the quick stop key.

-- Optional hold mode for opening the picker.
Config.OpenHoldMode   = false
Config.OpenHoldTimeMs = 0

-- In-menu navigation uses RedM input actions and follows player keybinds.
Config.Controls = {
    menuUp     = `INPUT_GAME_MENU_UP`,
    menuDown   = `INPUT_GAME_MENU_DOWN`,
    menuAccept = `INPUT_GAME_MENU_ACCEPT`,
    menuCancel = `INPUT_GAME_MENU_CANCEL`,
}

-- true: return to the original position when stopping; false: stay at the interaction position.
Config.TeleportBackOnStop = true

-- Disable all interactions inside these areas.
Config.BannedAreas = {
    -- { coords = vector3(-306.482, 809.1139, 118.98), radius = 5.0 },
}

-- Marker shown on the selected target while the picker is open.
Config.Marker = {
    enabled = true,
    type    = 0x94FDAE17,
    color   = { r = 185, g = 142, b = 67, a = 150 },
}

-- Picker UI theme. Values are applied to CSS variables at runtime.
Config.Theme = {
    position           = 'right',
    width              = '18vw',
    fontFamily         = "'Chinese Rocks RG', Georgia, 'Times New Roman', serif",
    fontSize           = '0.86vw',
    titleFontSize      = '1.05vw',
    backgroundColor    = 'transparent',
    titleBackground    = 'transparent',
    textColor          = '#f5f5f5',
    selectedBackground = 'transparent',
    selectedTextColor  = '#fff6df',
    accentColor        = '#c9a96e',
    borderRadius       = '0',
    itemPadding        = '0.43vh 0.72vw',
    showCategoryDot    = true,
    maxItems           = 50,

    showLogo           = true,
    logoUrl            = 'logo.png',
    logoSize           = '5.7vw',
    showTitle          = true,
}

-- World scan interval in milliseconds.
Config.NearbyCheckInterval = 750

-- Local ghost preview shown while browsing the picker.
Config.Preview = {
    enabled                = true,
    alpha                  = 105,
    hideWeapons            = true,
    allowMouseLook         = true,
    allowZoom              = true,
    hidePlayerWhilePreview = false,
}

-- Effect callbacks. Reference these keys from interaction entries with `effect`.
Config.Effects = {
    clean = function()
        local ped = PlayerPedId()
        ClearPedEnvDirt(ped)
        ClearPedDamageDecalByZone(ped, 10, 'ALL')
        ClearPedBloodDamage(ped)
    end,
}
