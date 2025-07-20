-- server/server.lua
-- Version check once on start, backup on start, plus PIN lockouts, JSON persistence, localization & webhook logging

local CodeFile = Config.CodeFile
local DEBUG    = Config.Debug
local LOCK     = Config.Lockout
local Webhook  = Config.Webhook

-- ─── Backup Thread ─────────────────────────────────────────────────────────
Citizen.CreateThread(function()
    Citizen.Wait(1000)  -- wait for files to mount

    local fileData = LoadResourceFile(GetCurrentResourceName(), CodeFile)
    if fileData then
        local bakName = CodeFile .. ".bak"
        local ok      = SaveResourceFile(GetCurrentResourceName(), bakName, fileData, -1)
        if DEBUG then
            print(("[stash] backup %s → %s: %s"):format(CodeFile, bakName, tostring(ok)))
        end
    elseif DEBUG then
        print(("[stash] no %s to back up"):format(CodeFile))
    end
end)

-- ─── Version‑Check Thread ──────────────────────────────────────────────────
local function isNewerVersion(a, b)
    local function split(v)
        local t = {}
        for num in v:gmatch("(%d+)") do table.insert(t, tonumber(num)) end
        return t
    end
    local ta, tb = split(a), split(b)
    for i = 1, math.max(#ta, #tb) do
        local na, nb = ta[i] or 0, tb[i] or 0
        if na > nb then return true
        elseif na < nb then return false
        end
    end
    return false
end

local function checkVersion()
    if not Config.VersionChecker.Enable then return end

    local localVer = GetResourceMetadata(GetCurrentResourceName(), "version", 0) or "0.0.0"

    PerformHttpRequest(
        "https://api.github.com/repos/BehrTheDon/qs-stashcreator/releases/latest",
        function(statusCode, responseBody)
            if statusCode == 200 then
                local ok, release = pcall(json.decode, responseBody)
                if ok and release.tag_name then
                    local latest = release.tag_name:gsub("^v", "")
                    if isNewerVersion(latest, localVer) then
                        -- RED if outdated
                        print(("^1[stash] Update available: %s (current %s)"):format(latest, localVer))
                        if Webhook.URL ~= "" then
                            PerformHttpRequest(Webhook.URL, function() end, "POST",
                                json.encode({
                                    username   = Webhook.Username,
                                    avatar_url = Webhook.AvatarURL,
                                    embeds     = {{
                                        title  = "📦 New Version Available",
                                        color  = 0xFF0000,  -- red embed
                                        fields = {
                                            { name="Current", value=localVer, inline=true },
                                            { name="Latest",  value=latest,   inline=true },
                                        },
                                        footer = { text = os.date("%c") }
                                    }}
                                }),
                                { ["Content-Type"] = "application/json" }
                            )
                        end
                    else
                        -- GREEN if up‑to‑date
                        print(("^2[stash] You are on latest version (%s)"):format(localVer))
                    end
                elseif DEBUG then
                    print("[stash] Failed to parse GitHub response")
                end
            elseif DEBUG then
                print("[stash] Version check HTTP error: " .. tostring(statusCode))
            end
        end,
        "GET", "", { ["User-Agent"]="FiveM" }
    )
end

Citizen.CreateThread(function()
    Citizen.Wait(2000)  -- give backup a moment
    checkVersion()
end)

-- ─── JSON utilities ────────────────────────────────────────────────────────
local function loadCodes()
    local raw = LoadResourceFile(GetCurrentResourceName(), CodeFile) or "{}"
    local ok, tbl = pcall(json.decode, raw)
    if not ok then
        print(("[stash][ERROR] failed to parse %s"):format(CodeFile))
        return {}
    end
    return tbl
end

local function saveCodes(tbl)
    local data = json.encode(tbl, { indent=true })
    local ok   = SaveResourceFile(GetCurrentResourceName(), CodeFile, data, -1)
    if DEBUG then print(("[stash] saveCodes → %s"):format(tostring(ok))) end
    return ok
end

-- ─── License normalization ─────────────────────────────────────────────────
local function normalizeLicense(arg)
    if type(arg) == "table" then
        if arg.license then return arg.license end
        if arg[1]       then return arg[1]       end
        return tostring(arg)
    end
    return tostring(arg)
end

-- ─── Discord embed sender ──────────────────────────────────────────────────
local function sendLogWebhook(title, fields)
    if Webhook.URL == "" then return end
    local footer = os.date("%a %b %d %H:%M:%S %Y (Server Time)")
    local embed  = { title=title, color=0x3498DB, fields=fields, footer={text=footer} }
    PerformHttpRequest(Webhook.URL, function() end, "POST",
        json.encode({ username=Webhook.Username, avatar_url=Webhook.AvatarURL, embeds={embed} }),
        { ["Content-Type"] = "application/json" }
    )
end

-- ─── Event Handlers ────────────────────────────────────────────────────────

-- 1) Return player's license
RegisterNetEvent("qs-personalstash:requestLicense")
AddEventHandler("qs-personalstash:requestLicense", function()
    local src, lic = source, nil
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:match("^license:") then lic = id break end
    end
    if DEBUG then print(("[stash] requestLicense → %s"):format(lic)) end
    TriggerClientEvent("qs-personalstash:receiveLicense", src, lic)
end)

-- 2) Check if PIN exists (migrate legacy)
RegisterNetEvent("qs-personalstash:checkHasCode")
AddEventHandler("qs-personalstash:checkHasCode", function(rawLicense)
    local src          = source
    local stashLicense = normalizeLicense(rawLicense)
    local codes, entry  = loadCodes(), nil
    local rawEntry     = codes[stashLicense]

    if type(rawEntry) == "string" then
        entry = { pin=rawEntry, failedAttempts={}, lockedUntil={} }
        codes[stashLicense] = entry
        saveCodes(codes)
    else
        entry = rawEntry or { failedAttempts={}, lockedUntil={} }
    end

    local exists = entry.pin ~= nil
    if DEBUG then
        print(("[stash] checkHasCode[%s] → %s")
            :format(stashLicense, tostring(exists)))
    end
    TriggerClientEvent("qs-personalstash:hasCodeResponse", src, stashLicense, exists)
end)

-- 3) Verify PIN & handle lockouts
RegisterNetEvent("qs-personalstash:verifyCode")
AddEventHandler("qs-personalstash:verifyCode", function(rawLicense, attempt)
    local src          = source
    local stashLicense = normalizeLicense(rawLicense)

    -- determine player's own license
    local playerLic = nil
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:match("^license:") then playerLic = id break end
    end

    local codes        = loadCodes()
    local rawEntry     = codes[stashLicense]
    local entry        = (type(rawEntry)=="string")
                         and { pin=rawEntry, failedAttempts={}, lockedUntil={} }
                         or (rawEntry or { failedAttempts={}, lockedUntil={} })

    entry.failedAttempts = entry.failedAttempts or {}
    entry.lockedUntil    = entry.lockedUntil    or {}
    codes[stashLicense]  = entry

    local now      = os.time()
    local tries    = entry.failedAttempts[playerLic] or 0
    local unlockTs = entry.lockedUntil[playerLic]    or 0

    -- still locked?
    if LOCK.Enable and unlockTs > now then
        sendLogWebhook(
            Translate("embeds.locked_cooldown"),
            {
              { name=Translate("embeds.field.player"),        value=GetPlayerName(src), inline=true },
              { name=Translate("embeds.field.stash_license"), value=stashLicense,       inline=true },
              { name=Translate("embeds.field.until"),         value=os.date("%H:%M:%S",unlockTs), inline=true },
            }
        )
        return TriggerClientEvent("qs-personalstash:codeLocked", src, stashLicense, unlockTs)
    end

    -- correct PIN?
    if entry.pin and tostring(attempt)==tostring(entry.pin) then
        entry.failedAttempts[playerLic] = 0
        entry.lockedUntil[playerLic]    = nil
        saveCodes(codes)

        sendLogWebhook(
            Translate("embeds.access_granted"),
            {
              { name=Translate("embeds.field.player"),        value=GetPlayerName(src), inline=true },
              { name=Translate("embeds.field.stash_license"), value=stashLicense,       inline=true },
            }
        )
        return TriggerClientEvent("qs-personalstash:codeAccepted", src, stashLicense)
    end

    -- wrong PIN
    tries = tries + 1
    entry.failedAttempts[playerLic] = tries

    if LOCK.Enable and tries >= LOCK.MaxAttempts then
        local newUnlock = now + LOCK.Duration
        entry.lockedUntil[playerLic] = newUnlock
        saveCodes(codes)

        sendLogWebhook(
            Translate("embeds.lockout_triggered"),
            {
              { name=Translate("embeds.field.player"),        value=GetPlayerName(src),      inline=true },
              { name=Translate("embeds.field.stash_license"), value=stashLicense,           inline=true },
              { name=Translate("embeds.field.max_attempts"),  value=tostring(LOCK.MaxAttempts), inline=true },
            }
        )
        return TriggerClientEvent("qs-personalstash:codeLocked", src, stashLicense, newUnlock)
    end

    saveCodes(codes)
    sendLogWebhook(
        Translate("embeds.access_denied"),
        {
          { name=Translate("embeds.field.player"),        value=GetPlayerName(src), inline=true },
          { name=Translate("embeds.field.stash_license"), value=stashLicense,       inline=true },
          { name=Translate("embeds.field.attempt"),       value=tostring(attempt),  inline=true },
        }
    )
    TriggerClientEvent("qs-personalstash:codeRejected", src)
end)

-- 4) Check lockout status
RegisterNetEvent("qs-personalstash:checkLockout")
AddEventHandler("qs-personalstash:checkLockout", function(rawLicense)
    local src          = source
    local stashLicense = normalizeLicense(rawLicense)
    local codes        = loadCodes()
    local entry        = codes[stashLicense] or { lockedUntil={} }
    entry.lockedUntil  = entry.lockedUntil or {}

    local playerLic = nil
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:match("^license:") then playerLic = id break end
    end

    local now      = os.time()
    local unlockTs = entry.lockedUntil[playerLic] or 0
    local isLocked = LOCK.Enable and unlockTs > now

    if DEBUG then
        print(("[stash] checkLockout[%s] → locked=%s until=%s")
            :format(stashLicense, tostring(isLocked), tostring(unlockTs)))
    end
    TriggerClientEvent("qs-personalstash:lockoutStatus", src, stashLicense, isLocked, unlockTs)
end)

-- 5) Set or change PIN
RegisterNetEvent("qs-personalstash:setNewCode")
AddEventHandler("qs-personalstash:setNewCode", function(rawLicense, newCode)
    local src          = source
    local stashLicense = normalizeLicense(rawLicense)
    local codes        = loadCodes()
    local rawEntry     = codes[stashLicense]
    local entry        = (type(rawEntry)=="string")
                         and { pin=tostring(newCode), failedAttempts={}, lockedUntil={} }
                         or (rawEntry or { failedAttempts={}, lockedUntil={} })

    entry.pin = tostring(newCode)
    codes[stashLicense] = entry
    local ok = saveCodes(codes)
    if ok then
        sendLogWebhook(
            Translate("embeds.pin_changed"),
            {
              { name=Translate("embeds.field.player"),        value=GetPlayerName(src),     inline=true },
              { name=Translate("embeds.field.stash_license"), value=stashLicense,          inline=true },
              { name=Translate("embeds.field.new_pin"),       value=tostring(newCode),     inline=true },
            }
        )
        TriggerClientEvent("qs-personalstash:codeSet", src, stashLicense)
    else
        TriggerClientEvent("qs-personalstash:codeRejected", src)
    end
end)

-- 6) Log stash opens
RegisterNetEvent("qs-personalstash:logAction")
AddEventHandler("qs-personalstash:logAction", function(rawLicense, actionType)
    local src          = source
    local stashLicense = normalizeLicense(rawLicense)
    local embedTitle   = Translate("embeds."..actionType)
    sendLogWebhook(embedTitle, {
      { name=Translate("embeds.field.player"),        value=GetPlayerName(src),    inline=true },
      { name=Translate("embeds.field.stash_license"), value=stashLicense,         inline=true },
      { name=Translate("embeds.field.action"),        value=actionType,           inline=true },
    })
end)

-- 7) Item add/remove hooks
RegisterNetEvent("qs-inventory:server:AddToStash")
AddEventHandler("qs-inventory:server:AddToStash", function(stashId, item, count)
    local src = source
    sendLogWebhook(
        Translate("embeds.item_added"),
        {
          { name=Translate("embeds.field.player"),        value=GetPlayerName(src),    inline=true },
          { name=Translate("embeds.field.stash_license"), value=stashId,             inline=true },
          { name=Translate("embeds.field.item"),          value=item.name or item,    inline=true },
          { name=Translate("embeds.field.count"),         value=tostring(count),      inline=true },
        }
    )
end)

RegisterNetEvent("qs-inventory:server:RemoveFromStash")
AddEventHandler("qs-inventory:server:RemoveFromStash", function(stashId, item, count)
    local src = source
    sendLogWebhook(
        Translate("embeds.item_removed"),
        {
          { name=Translate("embeds.field.player"),        value=GetPlayerName(src),    inline=true },
          { name=Translate("embeds.field.stash_license"), value=stashId,             inline=true },
          { name=Translate("embeds.field.item"),          value=item.name or item,    inline=true },
          { name=Translate("embeds.field.count"),         value=tostring(count),      inline=true },
        }
    )
end)
