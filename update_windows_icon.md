# Update Windows Desktop Icon

The Windows app icon is located at: `windows/runner/resources/app_icon.ico`

## Quick Update Instructions

1. **Convert PNG to ICO:**
   - Use an online converter (e.g., https://convertio.co/png-ico/)
   - Or use ImageMagick: `magick assets/icons/app_icon.png -define icon:auto-resize=256,128,64,48,32,16 windows/runner/resources/app_icon.ico`

2. **Manual Replacement:**
   - Copy your converted `.ico` file
   - Replace `windows/runner/resources/app_icon.ico`
   - Rebuild: `flutter clean && flutter run -d windows`

## Alternative: Use PowerShell with ImageMagick

If you have ImageMagick installed:
```powershell
magick convert assets/icons/app_icon.png -define icon:auto-resize=256,128,64,48,32,16 windows/runner/resources/app_icon.ico
```

## Note

The icon file must be in `.ico` format with multiple sizes (256x256, 128x128, 64x64, 48x48, 32x32, 16x16) for best display quality on Windows.

