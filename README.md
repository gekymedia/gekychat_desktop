# GekyChat Desktop

Desktop application for GekyChat built with Flutter.

## Features

- 🖥️ Desktop-optimized UI with sidebar layout
- 💬 Real-time messaging with Pusher
- 🔐 Phone-based authentication (OTP)
- 📱 WhatsApp-inspired design
- 🌙 Dark/Light theme support

## Setup

1. **Copy environment file:**
   ```bash
   cp .env.example .env
   ```

2. **Configure your `.env` file** with your API URL and Pusher credentials.

3. **Install dependencies:**
   ```bash
   flutter pub get
   ```

4. **Run the app:**
   ```bash
   flutter run -d windows    # Windows
   flutter run -d macos      # macOS
   flutter run -d linux      # Linux
   ```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── src/
│   ├── app_router.dart      # Navigation routing
│   ├── core/
│   │   ├── api_service.dart # API client
│   │   ├── providers.dart   # Riverpod providers
│   │   └── session.dart     # User session management
│   ├── features/
│   │   ├── auth/            # Authentication screens
│   │   └── chats/           # Chat screens
│   └── theme/
│       └── app_theme.dart   # Theme configuration
```

## Notes

- This desktop app shares core business logic with the mobile app
- The UI is optimized for desktop with multi-pane layouts
- Pusher client is referenced from the mobile app's `third_party` folder
