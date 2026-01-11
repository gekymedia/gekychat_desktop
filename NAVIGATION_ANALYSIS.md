# Navigation Flow Analysis: Why It Feels Like Opening a New Window

## Problem

When clicking on a chat/conversation in GekyChat Desktop, it feels like opening a new window rather than smoothly transitioning like WhatsApp Desktop or Telegram Desktop.

## Root Cause

The issue is in `lib/src/features/chats/desktop_chat_screen.dart` at lines 1162-1186:

```dart
onTap: () {
  // Switch to chats route if not already there
  final router = GoRouter.of(context);
  if (router.routerDelegate.currentConfiguration.uri.path != '/chats') {
    context.go('/chats');  // ⚠️ This causes full widget rebuild
    // Wait for route change then select conversation
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _selectedConversation = conversation;
          _selectedConversationId = conversation.id;
          _selectedGroup = null;
          _selectedGroupId = null;
        });
      }
    });
  } else {
    setState(() {
      _selectedConversation = conversation;
      _selectedConversationId = conversation.id;
      _selectedGroup = null;
      _selectedGroupId = null;
    });
  }
},
```

### Why This Feels Like a New Window

1. **Route Navigation Triggers Full Rebuild**: When `context.go('/chats')` is called, GoRouter rebuilds the entire `DesktopChatScreen` widget from scratch (see `app_router.dart` line 85: `builder: (context, state) => const DesktopChatScreen()`).

2. **No Page Transitions Configuration**: GoRouter by default uses standard Material page transitions, which can feel abrupt in desktop applications.

3. **State Loss**: Even though the widget rebuilds with the same state, there's a visual "flash" or rebuild that makes it feel like a new window is opening.

## How WhatsApp/Telegram Desktop Handle This

WhatsApp Desktop and Telegram Desktop use a **single persistent widget tree** approach:

- The chat list and chat view are in the same widget tree
- Clicking a chat only updates the **selected state** (using setState or state management)
- **No route navigation** happens for internal chat selection
- Smooth animations/transitions between chats
- The entire screen persists, only the chat content area changes

## Solution

### Primary Fix: Remove Unnecessary Route Navigation

Since `DesktopChatScreen` manages its own state for selected conversations, we should:

1. **Remove the route check entirely** - just use `setState` directly
2. **Only use route navigation** when actually navigating between different sections (like going from settings to chats)

### Additional Improvements

1. **Add NoTransitionPage** for routes that should not animate (if we need route-based navigation at all for chat selection)
2. **Use AnimatedSwitcher** or similar for smooth transitions between chat views
3. **Consider state preservation** if the widget does need to rebuild

## Code Changes Needed

1. Simplify the `onTap` handler to just use `setState` (remove the route check)
2. Ensure route navigation is only used for actual section changes (settings, profile, etc.), not for selecting chats within the same screen
