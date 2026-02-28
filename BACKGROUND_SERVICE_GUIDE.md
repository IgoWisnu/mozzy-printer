# Mozzy Print Service — Background Service Guide

This guide explains how the background print service works and what you need to do (and avoid) to keep it running reliably.

---

## How It Works

The app runs a **foreground service** on Android that keeps a persistent Socket.IO connection to your POS backend. When a print job arrives, the service connects to the mapped Bluetooth/USB printer and prints automatically — even if the app UI is closed or the screen is off.

You'll see a small **persistent notification** in your notification bar showing the current connection status.

---

## ✅ DO's

### 1. Keep the notification visible
The persistent notification ("Mozzy Print Service") is **required** by Android to keep the service running. **Do not dismiss or hide it.** If it disappears, the service has stopped.

### 2. Disable battery optimization for this app
This is the **most important step**.  Android aggressively kills background apps to save battery.

**How to disable:**
1. Go to **Settings → Apps → Mozzy Print Service**
2. Tap **Battery** (or **Battery usage**)
3. Select **"Unrestricted"** or **"No restrictions"**

> On Xiaomi/MIUI: Also go to **Settings → Battery & Performance → App battery saver → Mozzy Print Service → No restrictions**

### 3. Lock the app in Recents
On most Android phones, you can "lock" the app so it won't be killed when you clear recent apps:
1. Open **Recent Apps** (swipe up or tap the square button)
2. Find **Mozzy Print Service**
3. Tap the **lock icon** 🔒 (or long-press and select "Lock")

### 4. Enable Auto-start (Xiaomi/MIUI, OPPO, Vivo, Huawei)
Some manufacturers require explicit auto-start permission:
- **Xiaomi/MIUI:** Settings → Apps → Manage Apps → Mozzy Print Service → Autostart → Enable
- **OPPO/ColorOS:** Settings → App Management → App List → Mozzy Print Service → Allow Auto-start
- **Vivo/Funtouch:** Settings → Battery → Background Power Consumption → Mozzy Print Service → Allow
- **Huawei/EMUI:** Settings → Battery → App Launch → Mozzy Print Service → Manage Manually → Enable all

### 5. Keep Bluetooth ON
The printer connection relies on Bluetooth. Make sure:
- Bluetooth is always **enabled**
- The thermal printer is powered on and within range
- The printer is paired with your device

### 6. Ensure stable WiFi/Network
The Socket.IO connection to the POS backend needs a stable network. Use a **dedicated WiFi network** for the print service device if possible.

---

## ❌ DON'Ts

### 1. Don't Force Stop the app
**Never** go to Settings → Apps → Mozzy Print Service → **Force Stop**. This kills the background service completely. You'll need to re-open the app to restart it.

### 2. Don't clear app data
Clearing data will erase your server URL, API key, printer configurations, and print area mappings. You'll need to set everything up again.

### 3. Don't use "Clean all" in task manager
When clearing recent apps, make sure Mozzy Print Service is **locked** first (see DO #3). Otherwise, the system may kill the background service.

### 4. Don't enable "Adaptive Battery" restrictions
If Android suggests restricting this app's battery use, **decline**. Adaptive battery will put the app to sleep and stop the print service.

### 5. Don't turn off Bluetooth between orders
Even if there are no active print jobs, keep Bluetooth on. The background service caches the printer connection, and turning Bluetooth off will break it.

---

## Troubleshooting

| Problem | Solution |
|---|---|
| Notification disappeared | Open the app to restart the service |
| "Disconnected" in notification | Check WiFi/network and server status |
| Prints stopped working | Check Bluetooth is ON and printer is powered |
| Service keeps getting killed | Disable battery optimization (DO #2) and lock in recents (DO #3) |
| Jobs received but not printing | Check printer mapping in Printer Management — ensure the correct `printArea` is assigned |

---

## Quick Setup Checklist

- [ ] App installed and opened at least once
- [ ] Server URL and API Key configured in **Settings**
- [ ] Print areas selected (kitchen, cashier, etc.)
- [ ] At least one printer added and mapped to a print area
- [ ] Battery optimization **disabled** for this app
- [ ] App **locked** in recent apps
- [ ] Auto-start **enabled** (if Xiaomi/OPPO/Vivo/Huawei)
- [ ] Bluetooth **ON**
- [ ] Persistent notification visible in notification bar
