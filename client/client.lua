-- client.lua
-- Personal stash client with OxLib contexts, localized text, lockouts & webhook logging

local Stashes  = Config.Stashes
local Defaults = Config.Defaults
local DEBUG    = Config.Debug

local myLicense = nil
local isAdmin   = false
local hasCode   = {}  -- stashLicense → bool

-- ─── Helpers ───────────────────────────────────────────────────────────────

local function Notify(level, key, ...)
    Config.Notify(level, key, ...)
end

local function normalizeLicense(arg)
    if type(arg) == 'table' then
        if arg.license and type(arg.license)=='string' then return arg.license end
        if arg[1] and type(arg[1])=='string' then return arg[1] end
        return tostring(arg)
    end
    return tostring(arg)
end

local function DrawText3D(coords, text)
    local onScreen, sx, sy = World3dToScreen2d(coords.x, coords.y, coords.z+0.2)
    if not onScreen then return end
    SetTextScale(0.35,0.35); SetTextFont(4); SetTextCentre(true)
    SetTextColour(255,255,255,215); SetTextEntry('STRING')
    AddTextComponentString(text); DrawText(sx, sy)
    local factor = (#text)/370
    DrawRect(sx, sy+0.0125, 0.015+factor, 0.03, 0,0,0,120)
end

local function GetDistance(coords)
    local px,py,pz = table.unpack(GetEntityCoords(PlayerPedId()))
    return Vdist(px,py,pz, coords.x,coords.y,coords.z)
end

-- Build the locked‑stash menu
local function ShowEnterCodeMenu(rawLicense)
    local lic       = normalizeLicense(rawLicense)
    local sanitized = lic:gsub(':','_')
    local owner     = (lic == myLicense)
    local codeSet   = hasCode[lic]

    if DEBUG then
        print(('[stash] ShowEnterCodeMenu | owner=%s codeSet=%s isAdmin=%s')
            :format(tostring(owner), tostring(codeSet), tostring(isAdmin)))
    end

    local opts = {}

    if isAdmin then
        opts[#opts+1] = {
            title       = Translate('menus.admin_open'),
            description = Translate('menus.admin_open_desc'),
            event       = 'qs-personalstash:openStash',
            args        = { lic }
        }
    end

    if owner and not codeSet then
        opts[#opts+1] = {
            title       = Translate('menus.change_code'),
            description = Translate('menus.change_code_desc'),
            event       = 'qs-personalstash:promptNewCode',
            args        = { lic }
        }
    else
        opts[#opts+1] = {
            title       = Translate('menus.enter_code'),
            description = Translate('menus.enter_code_desc'),
            event       = 'qs-personalstash:promptCode',
            args        = { lic }
        }
    end

    lib.registerContext({
        id      = ('stash_locked_%s'):format(sanitized),
        title   = Translate('menus.stash_locked'),
        options = opts
    })
    lib.showContext(('stash_locked_%s'):format(sanitized))
end

-- Always check lockout first
local function TryOpenMenu(rawLicense)
    TriggerServerEvent('qs-personalstash:checkLockout', normalizeLicense(rawLicense))
end

-- ─── Events ────────────────────────────────────────────────────────────────

RegisterNetEvent('qs-personalstash:receiveLicense')
AddEventHandler('qs-personalstash:receiveLicense', function(id)
    myLicense = normalizeLicense(id)
    isAdmin   = false
    for _, lic in ipairs(Config.AdminLicenses) do
        if normalizeLicense(lic) == myLicense then
            isAdmin = true; break
        end
    end
    if DEBUG then
        print(('[stash] My license: %s | isAdmin: %s')
            :format(myLicense, tostring(isAdmin)))
    end
    TriggerServerEvent('qs-personalstash:checkHasCode', myLicense)
end)

RegisterNetEvent('qs-personalstash:hasCodeResponse')
AddEventHandler('qs-personalstash:hasCodeResponse', function(rawLicense, exists)
    hasCode[normalizeLicense(rawLicense)] = exists
end)

RegisterNetEvent('qs-personalstash:lockoutStatus')
AddEventHandler('qs-personalstash:lockoutStatus', function(rawLicense, isLocked, unlockTs)
    if DEBUG then
        print(('[stash] lockoutStatus | stash=%s locked=%s until=%s')
            :format(rawLicense, tostring(isLocked), tostring(unlockTs)))
    end

    if isLocked then
        local now     = os.time()
        local waitSec = math.max(0, (unlockTs or now) - now)
        Notify('error', 'notifs.locked', waitSec)
    else
        ShowEnterCodeMenu(rawLicense)
    end
end)

RegisterNetEvent('qs-personalstash:codeLocked')
AddEventHandler('qs-personalstash:codeLocked', function(rawLicense, unlockTs)
    if DEBUG then
        print(('[stash] codeLocked | stash=%s until=%s')
            :format(rawLicense, tostring(unlockTs)))
    end

    local now     = os.time()
    local waitSec = math.max(0, (unlockTs or now) - now)
    Notify('error', 'notifs.lockout_cooldown', waitSec)
end)

RegisterNetEvent('qs-personalstash:promptCode')
AddEventHandler('qs-personalstash:promptCode', function(rawLicense)
    local lic = normalizeLicense(rawLicense)
    local res = lib.inputDialog(
        Translate('dialogs.prompt_pin'),
        {{
            type        = 'input',
            label       = Translate('dialogs.label_pin'),
            icon        = 'key',
            description = Translate('dialogs.prompt_pin')
        }}
    )
    if res then
        TriggerServerEvent('qs-personalstash:verifyCode', lic, res[1])
    end
end)

RegisterNetEvent('qs-personalstash:codeAccepted')
AddEventHandler('qs-personalstash:codeAccepted', function(rawLicense)
    local lic    = normalizeLicense(rawLicense)
    hasCode[lic] = true
    local sanitized = lic:gsub(':','_')

    local opts = {{
        title       = Translate('menus.open_stash'),
        description = Translate('menus.open_stash_desc'),
        event       = 'qs-personalstash:openStash',
        args        = { lic }
    }}
    if lic == myLicense then
        table.insert(opts, {
            title       = Translate('menus.change_code'),
            description = Translate('menus.change_code_desc'),
            event       = 'qs-personalstash:promptNewCode',
            args        = { lic }
        })
    end

    lib.registerContext({
        id      = ('stash_open_%s'):format(sanitized),
        title   = Translate('menus.access_granted'),
        options = opts
    })
    lib.showContext(('stash_open_%s'):format(sanitized))
end)

RegisterNetEvent('qs-personalstash:codeRejected')
AddEventHandler('qs-personalstash:codeRejected', function()
    Notify('error', 'notifs.incorrect')
end)

RegisterNetEvent('qs-personalstash:promptNewCode')
AddEventHandler('qs-personalstash:promptNewCode', function(rawLicense)
    local lic = normalizeLicense(rawLicense)
    local res = lib.inputDialog(
        Translate('dialogs.prompt_new_pin'),
        {{
            type        = 'input',
            label       = Translate('dialogs.label_new_pin'),
            icon        = 'key',
            description = Translate('dialogs.prompt_new_pin')
        }}
    )
    if res then
        TriggerServerEvent('qs-personalstash:setNewCode', lic, res[1])
    end
end)

RegisterNetEvent('qs-personalstash:codeSet')
AddEventHandler('qs-personalstash:codeSet', function(rawLicense)
    hasCode[normalizeLicense(rawLicense)] = true
    Notify('success', 'notifs.code_updated')
end)

RegisterNetEvent('qs-personalstash:openStash')
AddEventHandler('qs-personalstash:openStash', function(rawLicense)
    -- log then open
    TriggerServerEvent(
      'qs-personalstash:logAction',
      normalizeLicense(rawLicense),
      isAdmin and 'admin_open' or 'player_open'
    )

    local lic = normalizeLicense(rawLicense)
    local sc
    for _, stash in ipairs(Stashes) do
        if normalizeLicense(stash.license) == lic then sc = stash; break end
    end
    local slots  = (sc and sc.stashSlots)  or Defaults.stashSlots
    local weight = (sc and sc.stashWeight) or Defaults.stashWeight
    exports['qs-inventory']:RegisterStash(lic, slots, weight)
end)

-- Draw markers & hint
Citizen.CreateThread(function()
    TriggerServerEvent('qs-personalstash:requestLicense')
end)

Citizen.CreateThread(function()
    while true do
        local sleep = 200
        for _, stash in ipairs(Stashes) do
            local coords   = stash.coords
            local drawDist = stash.markerDrawDistance or Defaults.markerDrawDistance
            local dist     = GetDistance(coords)

            if dist <= drawDist then
                sleep = 0

                local showM  = stash.showMarker ~= nil and stash.showMarker or Defaults.showMarker
                local showT  = stash.showText   ~= nil and stash.showText   or Defaults.showText
                local mType  = stash.markerType  or Defaults.markerType
                local mScl   = stash.markerScale or Defaults.markerScale
                local mCol   = stash.markerColor or Defaults.markerColor
                local iDist  = stash.interactionDistance or Defaults.interactionDistance
                local iKey   = stash.interactionKey      or Defaults.interactionKey

                if showM then
                    DrawMarker(
                        mType,
                        coords.x, coords.y, coords.z,
                        0,0,0, 0,0,0,
                        mScl.x, mScl.y, mScl.z,
                        mCol.r, mCol.g, mCol.b, 100,
                        false,false,2,false,nil,nil,false
                    )
                end

                if showT and dist <= (iDist + 1.0) then
                    DrawText3D(coords, Translate('menus.open_hint'))
                end

                if dist <= iDist and IsControlJustReleased(0, iKey) then
                    TryOpenMenu(stash.license)
                end
            end
        end
        Citizen.Wait(sleep)
    end
end)
