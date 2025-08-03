# QS‑PersonalStash

Secure, per‑player stashes with PIN protection, Discord webhook logging, localization, and flexible notification drivers—built for Quasar Inventory (QS‑Inventory) servers.

---

## 🔒 Features

- **Per‑stash PIN locks**  
  Players set a 4‑digit PIN on their personal stash.  
- **Lockout & cooldowns**  
  Configurable max wrong attempts and cooldown period.  
- **Discord webhook logging**  
  Rich embeds for:  
  - ✅ Access granted  
  - ❌ Access denied  
  - ⏰ Lockout cooldown  
  - ⛔ Lockout triggered  
  - 🔑 PIN changed  
  - 📥 Item added  - WIP
  - 📤 Item removed  - WIP
- **Localization-ready**  
  All in‑game text lives in JSON (`locales/*.json`).  
- **Flexible notifications**  
  Switch between OxLib, ESX, OKOK, QBCore, or your own driver in one config line.  
- **Version checker**  
  On start, auto‑compare your manifest version against GitHub “latest release.”  
- **Automatic PIN database backup**  
  Snapshots `stash_codes.json` → `stash_codes.json.bak` on every restart.

---

## 📦 Requirements

- [FiveM](https://fivem.net/)  
- [QS‑Inventory (Quasar)](https://www.quasar-store.com/scripts/advancedinventory)
- [OxLib](https://github.com/overextended/ox_lib)  
- [ESX](https://github.com/esx-framework/es_extended)  
- **Optional**: OKOKNotify, ESXNotify.

---

## ➕ Installation

1. **Clone** into your resources folder:  
   ```bash
   git clone https://github.com/BehrTheDon/qs-stashcreator.git
````

2. **Add** to your `server.cfg`:

   ```
   ensure qs-stashcreator
   ```
3. **Restart** or `refresh` + `restart qs-stashcreator`.

---

## ⚙️ Configuration

All settings live in `config.lua`. Highlights:

```lua
-- PIN lockout
Config.Lockout = { Enable=true, MaxAttempts=3, Duration=600 }

-- Notification driver (ox_lib | esx_notify | okok_notify | qb_notify)
Config.NotificationSystem = 'ox_lib'

-- Discord webhook
Config.Webhook = {
  URL        = 'https://discord.com/api/webhooks/…',
  Username   = 'StashLogger',
  AvatarURL  = '',
}

-- Localization
Config.Locale = 'en'   -- loads locales/en.json
```

After editing `config.lua`, restart the resource.

---

## 🌐 Localization

* All in‑game text and embed fields are in `locales/<lang>.json`.
* To add a language:

  1. Copy `locales/en.json` → `locales/xy.json`.
  2. Translate each value.
  3. Set `Config.Locale = 'xy'`.

---

## 🔔 Custom Notifications

Swap drivers by changing one line:

```lua
Config.NotificationSystem = 'qb_notify'
```

Supported out‑of‑the‑box:

* **ox\_lib** → `lib.notify({...})`
* **esx\_notify** → `ESX.ShowNotification(msg)`
* **okok\_notify** → `exports['okokNotify']:Alert(...)`
* **qb\_notify** → `QBCore.Functions.Notify(...)`

---

## 📈 Version Checker

* **fxmanifest.lua** must include `version 'X.Y.Z'`.
* On start, the script hits GitHub’s `/releases/latest` for `BehrTheDon/qs-stashcreator`.
* Console color codes:

  * 🟢 Green → up‑to‑date
  * 🔴 Red   → update available
* To disable, set `Config.VersionChecker.Enable = false`.

---

## 🗄️ PIN Database Backup

On every restart, your `stash_codes.json` is backed up to `stash_codes.json.bak`. No commands needed—just check the root folder.

---

## 🛠️ Usage & Commands

* **Open stash**: Approach marker, press **E**, enter PIN.
* **Admin bypass**: Listed under “Admin Open” in the same menu (requires license in `Config.AdminLicenses`).
* **Change PIN**: Option appears after correct entry (or first time).

*No chat commands required—everything is menu‑driven.*

---

## 🤝 Contributing

1. Fork the repo & create a branch.
2. Implement your feature or fix.
3. Submit a pull request—maintain code style and add localization keys as needed.

---

## 📄 License

**MIT License** — see [LICENSE](LICENSE) for details. Copy, modify, distribute—do whatever you want!

---

*Enjoy, and thanks for using QS‑PersonalStash!*

```
