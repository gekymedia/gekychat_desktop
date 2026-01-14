# Deep Link Setup for GekyChat Desktop

This guide explains how to set up the `gekychat://` protocol handler for the desktop app.

## Overview

The deep link feature allows the web version of GekyChat to prompt users to open the desktop app. When a user visits `chat.gekychat.com`, they can choose to open the desktop app instead.

## Protocol Handler Registration

### Windows

To register the protocol handler on Windows, you have two options:

#### Option 1: PowerShell Script (Recommended)

1. Run the PowerShell script as Administrator:
   ```powershell
   .\windows\register_protocol_handler.ps1 -AppPath "C:\Path\To\gekychat_desktop.exe"
   ```

2. Replace `C:\Path\To\gekychat_desktop.exe` with the actual path to your installed application.

#### Option 2: Registry File

1. Edit `windows/register_protocol_handler.reg`
2. Replace `C:\\Path\\To\\gekychat_desktop.exe` with your actual application path
3. Double-click the `.reg` file to import it into the registry

### macOS

For macOS, protocol handlers are registered in the `Info.plist` file. Add the following to your `macos/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.gekychat.desktop</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>gekychat</string>
        </array>
    </dict>
</array>
```

### Linux

For Linux, create a `.desktop` file in `~/.local/share/applications/`:

```ini
[Desktop Entry]
Name=GekyChat Desktop
Exec=/path/to/gekychat_desktop %u
Type=Application
MimeType=x-scheme-handler/gekychat;
```

Then register it:
```bash
xdg-mime default gekychat.desktop x-scheme-handler/gekychat
```

## Supported Deep Link Formats

- `gekychat://chat/{conversationId}` - Open a specific conversation
- `gekychat://group/{groupId}` - Open a specific group
- `gekychat://channel/{channelId}` - Open a specific channel
- `gekychat://settings` - Open settings
- `gekychat://calls` - Open calls screen
- `gekychat://status` - Open status screen
- `gekychat://world` - Open world feed
- `gekychat://web?url={encodedWebUrl}` - Open from web interface (automatically maps web routes to desktop routes)

## How It Works

1. **Web Interface**: When a user visits the web version, JavaScript detects if they're on a desktop and shows a prompt to open the desktop app.

2. **Protocol Link**: If the user clicks "Open GekyChat", the browser attempts to open `gekychat://web?url={currentUrl}`.

3. **Desktop App**: The desktop app receives the protocol link, parses it, and navigates to the appropriate screen.

4. **User Preference**: Users can choose to "Always allow" so the app opens automatically in the future.

## Testing

1. Register the protocol handler using one of the methods above
2. Visit `chat.gekychat.com` in your browser
3. You should see a prompt asking if you want to open GekyChat Desktop
4. Click "Open GekyChat" to test the deep link

## Troubleshooting

- **Protocol handler not working**: Make sure the registry entry points to the correct executable path
- **App doesn't open**: Check that the executable path in the registry is correct and the app is installed
- **Prompt not showing**: Clear browser cache and localStorage, or check browser console for errors
