# Updating App Icons with GekyChat Logo

The app icons have been configured to use the GekyChat logo instead of the default Flutter logo.

## Setup Complete ✅

- Added `flutter_launcher_icons` package
- Configured icon paths in `pubspec.yaml`
- Copied GekyChat logo to `assets/icons/`

## Generate Icons

Run the following command to generate all required icon sizes:

```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

This will automatically:
- Generate Android launcher icons (all densities)
- Generate iOS app icons (all sizes)
- Generate Windows `.ico` file
- Generate macOS `.icns` file
- Generate Linux icons

## Manual Icon Replacement (if needed)

If you want to use a different logo file:

1. Replace `assets/icons/app_icon.png` with your 1024x1024 PNG logo
2. Replace `assets/icons/app_icon_foreground.png` with your foreground icon (if using adaptive icons)
3. Update `adaptive_icon_background` color in `pubspec.yaml` if needed
4. Run `flutter pub run flutter_launcher_icons` again

## Current Configuration

- **Source Icon**: `assets/icons/app_icon.png` (512x512 from gekychat/public/icons/)
- **Adaptive Background**: #008069 (GekyChat green)
- **Platforms**: Android, iOS, Windows, macOS, Linux

## Next Steps

After running the icon generator, rebuild your app to see the new icons:
- Windows: `flutter run -d windows`
- macOS: `flutter run -d macos`
- Linux: `flutter run -d linux`

