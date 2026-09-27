# iOS Spotlight (system search)

GekyChat indexes chats and groups into Core Spotlight so they appear in iPhone Search
(like WhatsApp).

## Files
- `Runner/SpotlightPlugin.swift` — MethodChannel `gekychat/spotlight`
- Dart: `lib/src/services/ios_spotlight_service.dart`

## Wire into an existing iOS Runner
1. Add `SpotlightPlugin.swift` to the Xcode Runner target.
2. In `AppDelegate.swift`, after `GeneratedPluginRegistrant.register`:
   ```swift
   if let registrar = self.registrar(forPlugin: "SpotlightPlugin") {
     SpotlightPlugin.register(with: registrar)
   }
   ```
3. Forward Spotlight opens in `application(_:continue:restorationHandler:)` (see
   `AppDelegate+Spotlight.swift`).
4. Add to `Info.plist`:
   - `NSUserActivityTypes` → `com.gekychat.openChat`
   - URL scheme `gekychat`

Indexing runs after login and whenever the inbox refreshes. Logout clears the index.
