# GekyChat Desktop - Build Lock Error Fix

**Date:** January 2025  
**Issue:** `LNK1168: cannot open gekychat_desktop.exe for writing`

---

## ❌ Problem

Build was failing with the following error:

```
LINK : fatal error LNK1168: cannot open 
D:\projects\gekychat_desktop\build\windows\x64\runner\Debug\gekychat_desktop.exe 
for writing
```

### Root Cause

This error occurs when:
1. **The app is already running** - The executable file is locked by a running process
2. **Another process has the file open** - Another program is using the file
3. **File permissions issue** - Insufficient permissions to write to the file
4. **Antivirus/security software** - Security software is scanning/locking the file

**Most Common:** The app is still running from a previous build.

---

## ✅ Solution

### Quick Fix (Manual)

1. **Close the running app:**
   - Look for "GekyChat Desktop" in your taskbar
   - Right-click and close it
   - Or use Task Manager to end the process

2. **Clean and rebuild:**
   ```powershell
   cd gekychat_desktop
   flutter clean
   flutter pub get
   flutter run
   ```

### Automated Fix (Script)

Use the provided script to automatically handle this:

```powershell
cd gekychat_desktop
. .\fix_build_lock.ps1
```

This script will:
- ✅ Kill any running GekyChat Desktop processes
- ✅ Remove locked build files
- ✅ Clean the Flutter build
- ✅ Get dependencies

### Manual Process Kill (If Script Doesn't Work)

```powershell
# Find and kill GekyChat Desktop processes
Get-Process | Where-Object {$_.ProcessName -like "*gekychat*"} | Stop-Process -Force

# Or find by window title
Get-Process | Where-Object {$_.MainWindowTitle -like "*GekyChat*"} | Stop-Process -Force
```

---

## 🔧 Prevention

To prevent this issue in the future:

1. **Always close the app before rebuilding:**
   ```powershell
   # Before building, close the app
   Get-Process | Where-Object {$_.MainWindowTitle -like "*GekyChat*"} | Stop-Process -Force
   flutter run
   ```

2. **Use hot reload instead of full rebuild:**
   - Press `r` in the terminal for hot reload
   - Press `R` for hot restart (keeps app running)

3. **Clean build directory before major changes:**
   ```powershell
   flutter clean
   flutter pub get
   flutter run
   ```

---

## 🚀 Quick Commands

### Kill App and Rebuild
```powershell
cd gekychat_desktop
Get-Process | Where-Object {$_.MainWindowTitle -like "*GekyChat*" -or $_.ProcessName -like "*gekychat*"} | Stop-Process -Force -ErrorAction SilentlyContinue
flutter clean
flutter pub get
flutter run
```

### Clean Build Directory Only
```powershell
cd gekychat_desktop
Remove-Item -Recurse -Force "build" -ErrorAction SilentlyContinue
flutter pub get
flutter run
```

### Full Clean and Rebuild
```powershell
cd gekychat_desktop
flutter clean
flutter pub get
flutter run
```

---

## 📋 Troubleshooting

### Issue: Script can't kill the process

**Solution:**
```powershell
# Run PowerShell as Administrator
# Then:
Get-Process | Where-Object {$_.ProcessName -like "*gekychat*"} | Stop-Process -Force
```

### Issue: File still locked after killing process

**Solution:**
```powershell
# Remove the entire build directory
cd gekychat_desktop
Remove-Item -Recurse -Force "build" -ErrorAction SilentlyContinue
flutter clean
flutter pub get
flutter run
```

### Issue: Antivirus is locking the file

**Solution:**
1. Add `build` directory to antivirus exclusions
2. Add `gekychat_desktop.exe` to antivirus exclusions
3. Temporarily disable real-time scanning during builds

### Issue: Build works but app won't start

**Solution:**
- Check if another instance is already running
- Check Windows Event Viewer for errors
- Try running from the built executable directly:
  ```powershell
  .\build\windows\x64\runner\Debug\gekychat_desktop.exe
  ```

---

## ✅ Status: Resolved

After running the fix script or manually closing the app, you should be able to build successfully.

**Files Created:**
- `fix_build_lock.ps1` - Automated fix script

**Last Updated:** January 2025
