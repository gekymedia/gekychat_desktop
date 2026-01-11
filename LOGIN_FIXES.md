# GekyChat Desktop - Login Issues Fixed

**Date:** January 2025  
**Issues Fixed:**
1. Invalid GUID format for Windows notifications
2. API route 404 error on login

---

## ✅ Fix 1: Invalid GUID Format for Notifications

### Problem
```
❌ Failed to initialize desktop notifications: Invalid argument (GUID): Invalid GUID. 
Please use xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx format.
```

The Windows notification settings used an invalid GUID format: `'gekychat-desktop-app'` instead of a proper UUID format.

### Solution
Changed the GUID to a valid UUID format: `'a1b2c3d4-e5f6-7890-abcd-ef1234567890'`

### File Modified
- `lib/src/features/notifications/desktop_notification_service.dart`

### Code Change
```dart
// Before:
guid: 'gekychat-desktop-app',

// After:
guid: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', // Valid GUID format for Windows notifications
```

---

## ✅ Fix 2: API Route 404 Error on Login

### Problem
```
❌ API Error 404: /auth/phone
Response: {message: The route api/v1/auth/phone could not be found.}
```

The desktop app was calling `/auth/phone`, but the Laravel backend expects `/api/v1/auth/phone`. The base URL didn't include the `/api/v1` prefix.

### Solution
Updated the `ApiService` constructor to automatically append `/api/v1` to the base URL if it's not already present.

### File Modified
- `lib/src/core/api_service.dart`

### Code Change
```dart
// Ensure base URL ends with /api/v1 for proper routing
// Laravel routes in api_user.php use Route::prefix('v1'), 
// so full path is /api/v1/auth/phone
var cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

if (!cleanBaseUrl.toLowerCase().endsWith('/api/v1')) {
  if (cleanBaseUrl.endsWith('/api')) {
    cleanBaseUrl = '$cleanBaseUrl/v1';
  } else if (cleanBaseUrl.endsWith('/v1')) {
    // Handle /v1 without /api
    final segments = cleanBaseUrl.split('/');
    if (segments.length >= 2 && segments[segments.length - 2] != 'api') {
      segments[segments.length - 1] = 'api';
      segments.add('v1');
      cleanBaseUrl = segments.join('/');
    }
  } else {
    cleanBaseUrl = '$cleanBaseUrl/api/v1';
  }
}
```

### How It Works

**Base URL Examples:**
- `https://chat.gekychat.com` → `https://chat.gekychat.com/api/v1` ✅
- `https://chat.gekychat.com/api` → `https://chat.gekychat.com/api/v1` ✅
- `https://chat.gekychat.com/api/v1` → `https://chat.gekychat.com/api/v1` ✅ (no change)
- `https://chat.gekychat.com/v1` → `https://chat.gekychat.com/api/v1` ✅

**Route Calls:**
- `post('/auth/phone')` → Full URL: `https://chat.gekychat.com/api/v1/auth/phone` ✅
- `post('/auth/verify')` → Full URL: `https://chat.gekychat.com/api/v1/auth/verify` ✅

---

## 🧪 Testing

### To Test the Fixes:

1. **Clean and rebuild:**
   ```bash
   cd gekychat_desktop
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Check console output:**
   - Should see: `🔗 API Base URL configured: https://your-domain.com/api/v1`
   - Should NOT see: `Invalid GUID` errors
   - Should NOT see: `404` errors for `/auth/phone`

3. **Test login:**
   - Enter phone number on login page
   - Should successfully request OTP
   - No 404 errors should appear

### Expected Behavior:

✅ **Notifications:**
- Should initialize without GUID errors
- Console should show: `✅ Desktop notifications initialized successfully`

✅ **Login:**
- Phone number submission should work
- Should successfully call `/api/v1/auth/phone`
- OTP should be sent to phone number

---

## 📋 Environment Configuration

Make sure your `.env` file in `gekychat_desktop` has:

```env
API_BASE_URL=https://chat.gekychat.com
# OR
API_BASE_URL=https://chat.gekychat.com/api/v1
# OR  
API_BASE_URL=https://chat.gekychat.com/api
# OR
API_BASE_URL=https://chat.gekychat.com/v1
```

All of the above will be automatically normalized to: `https://chat.gekychat.com/api/v1`

---

## 🔍 Verification

### Check API Base URL:
The app will print the configured base URL on startup:
```
🔗 API Base URL configured: https://chat.gekychat.com/api/v1
```

### Verify Routes:
- Login page: Phone input should work
- OTP verification: Should work after receiving OTP
- No 404 errors in console

---

## ✅ Status: Fixed

Both issues have been resolved:
- ✅ Notifications initialize with valid GUID
- ✅ API routes correctly include `/api/v1` prefix
- ✅ Login should work without 404 errors

**Last Updated:** January 2025
