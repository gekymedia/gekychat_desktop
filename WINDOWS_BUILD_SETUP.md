# Windows Build Setup Guide

## Issue
The Flutter desktop app requires Windows SDK with ATL (Active Template Library) support for native plugins:
- `flutter_local_notifications_windows`
- `flutter_secure_storage_windows`

## Solution

### Option 1: Install Visual Studio 2022 (Recommended)

1. Download [Visual Studio 2022 Community](https://visualstudio.microsoft.com/downloads/)
2. During installation, select:
   - ✅ **Workload:** "Desktop development with C++"
   - ✅ **Individual Components:** 
     - "Windows SDK" (latest version, e.g., 10.0.22621.0)
     - "C++ ATL for latest v143 build tools (x86 & x64)"

### Option 2: Install Visual Studio Build Tools

1. Download [Visual Studio Build Tools 2022](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022)
2. Install with:
   - "Desktop development with C++" workload
   - "Windows SDK" and "C++ ATL" components

### Option 3: Add Components to Existing Installation

If you already have Visual Studio:

1. Open **Visual Studio Installer**
2. Click **Modify** on your installation
3. Go to **Individual components** tab
4. Search and check:
   - "Windows SDK" (latest version)
   - "C++ ATL for latest v143 build tools"
5. Click **Modify**

### Verify Installation

After installing, restart your terminal and run:

```powershell
flutter doctor -v
```

You should see Visual Studio listed as installed.

### Build Again

```powershell
cd gekychat_desktop
flutter clean
flutter pub get
flutter run -d windows
```

## Alternative: Temporarily Disable Native Plugins

If you can't install Visual Studio right now, you could temporarily comment out features that require native plugins, but this is **not recommended** as you'll lose notifications and secure storage functionality.

