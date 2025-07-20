Config = {}

-- Debug toggle
Config.Debug = false

-- Enable or disable automatic version checks (uses version in fxmanifest)
Config.VersionChecker = {
    Enable   = true,
}

-- Admin licenses allowed to bypass codes
Config.AdminLicenses = {
    "license:abcd1234wxyz",
    -- add more...
}

-- JSON file storing stash PINs and lockout data
Config.CodeFile = 'stash_codes.json'

-- Lockout configuration
Config.Lockout = {
    Enable      = true,
    MaxAttempts = 3,
    Duration    = 600, -- seconds
}

-- Defaults for stash interaction
Config.Defaults = {
    stashSlots          = 200,
    stashWeight         = 100000,
    markerDrawDistance  = 30.0,
    showMarker          = true,
    markerType          = 1,
    markerScale         = vector3(1.0,1.0,1.0),
    markerColor         = { r=255, g=255, b=255 },
    showText            = true,
    interactionDistance = 1.5,
    interactionKey      = 38, -- E
}

-- ─── Localization Settings ────────────────────────────────────────────────
-- Current locale code
Config.Locale = 'en'

-- Table to hold loaded translations
Translations = {}

-- Load the JSON for the chosen locale
do
    local path = ('locales/%s.json'):format(Config.Locale)
    local raw  = LoadResourceFile(GetCurrentResourceName(), path)
    if raw then
        local ok, tbl = pcall(json.decode, raw)
        if ok then
            Translations = tbl
        else
            print('[stash][ERROR] Invalid JSON in ' .. path)
        end
    else
        print('[stash][WARN] Locale file not found: ' .. path)
    end
end

-- Helper to fetch & format a translation by dotted key
function Translate(key, ...)
    local val = Translations
    for part in key:gmatch('([^.]+)') do
        val = val[part]
        if not val then
            return key -- fallback to key if missing
        end
    end
    if select('#', ...) > 0 then
        return val:format(...)
    end
    return val
end

-- ─── Notification Abstraction ─────────────────────────────────────────────
-- Drivers: "ox_lib", "esx_notify", "okok_notify", "qb_notify", etc.
Config.NotificationSystem = 'ox_lib'

Config.NotifyDefaults = {
    position = 'topright',
    duration = 5000,
}

-- Unified notify(level, translationKey, ...)
Config.Notify = function(level, key, ...)
    local message = Translate(key, ...)
    local defs    = Config.NotifyDefaults

    if Config.NotificationSystem == 'ox_lib' then
        lib.notify({
            type        = level,
            description = message,
            position    = defs.position,
            timeout     = defs.duration
        })

    elseif Config.NotificationSystem == 'esx_notify' then
        ESX.ShowNotification(message)

    elseif Config.NotificationSystem == 'okok_notify' then
        exports['okokNotify']:Alert(level, message, defs.duration)

    elseif Config.NotificationSystem == 'qb_notify' then
        QBCore.Functions.Notify(message, level, defs.duration)

    else
        -- fallback
        lib.notify({
            type        = level,
            description = message,
            position    = defs.position,
            timeout     = defs.duration
        })
    end
end

-- ─── Discord Webhook Settings ─────────────────────────────────────────────
Config.Webhook = {
    URL        = '',            -- paste your webhook here
    Username   = 'StashLogger',
    AvatarURL  = '',
}

-- ─── Stash Definitions ─────────────────────────────────────────────────────
Config.Stashes = {
    {
        license            = "license:abcd1234wxyz", --stash owner license (1 per player)
        coords             = vector3(301.3171, -883.3045, 29.2809),
    },
    -- add more stashes here
}
