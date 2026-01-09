# How to Update Desktop App Icon with GekyChat Icon

The desktop app icon is configured separately for Windows and macOS.

## Windows Icon

The Windows icon file is located at:
- `windows/runner/resources/app_icon.ico`

### Steps to Update:

1. **Get the GekyChat icon** from `gekychat/public/icons/icon-512x512.png` (or any large icon from that directory)

2. **Convert PNG to ICO** with multiple sizes:
   - Use an online converter like: https://convertio.co/png-ico/
   - Or use ImageMagick (if installed):
     ```powershell
     magick convert "d:\projects\gekychat\public\icons\icon-512x512.png" -define icon:auto-resize=256,128,64,48,32,16 "d:\projects\gekychat_desktop\windows\runner\resources\app_icon.ico"
     ```

3. **Replace the file**:
   - Copy the generated `app_icon.ico` file
   - Replace `windows/runner/resources/app_icon.ico`

4. **Rebuild**:
   ```bash
   flutter clean
   flutter run -d windows
   ```

## macOS Icon

The macOS icon files are located at:
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/`

### Steps to Update:

1. **Get the GekyChat icon** from `gekychat/public/icons/icon-512x512.png`

2. **Resize to required sizes**:
   - app_icon_16.png (16x16)
   - app_icon_32.png (32x32)
   - app_icon_64.png (64x64)
   - app_icon_128.png (128x128)
   - app_icon_256.png (256x256)
   - app_icon_512.png (512x512)
   - app_icon_1024.png (1024x1024)

3. **Replace the files** in `macos/Runner/Assets.xcassets/AppIcon.appiconset/`

4. **Rebuild**:
   ```bash
   flutter clean
   flutter run -d macos
   ```

## Quick Script (Windows PowerShell)

If you have ImageMagick installed, you can use this script:

```powershell
# Update Windows icon
$sourceIcon = "d:\projects\gekychat\public\icons\icon-512x512.png"
$windowsIcon = "d:\projects\gekychat_desktop\windows\runner\resources\app_icon.ico"
magick convert $sourceIcon -define icon:auto-resize=256,128,64,48,32,16 $windowsIcon

# Update macOS icons (requires creating multiple sizes)
# For macOS, you'll need to manually resize and replace each PNG file
```

## Note

The `flutter_launcher_icons` package doesn't properly support Windows/macOS desktop icons yet. Manual replacement is required.
