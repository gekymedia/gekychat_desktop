# Skeleton Loaders Implementation Guide

## Overview

Skeleton loaders (also called shimmer loaders) provide a modern, polished loading experience that shows users the structure of content before it loads. This creates a perception of faster load times and reduces perceived lag.

**Benefits:**
- Better UX than spinning indicators
- Shows content structure immediately
- Reduces perceived wait time
- Modern, professional appearance
- Matches WhatsApp/Telegram/Discord patterns

---

## Implementation

### Files Created

1. **`lib/src/widgets/skeleton_loader.dart`** - Complete skeleton loader library with:
   - Base `SkeletonLoader` widget with shimmer animation
   - Specialized components for different UI elements
   - Pre-built patterns for common layouts

### Files Modified

1. **`lib/src/features/chats/desktop_chat_screen.dart`**
   - Chat/group list loading states
   - Channel list loading states

2. **`lib/src/features/contacts/contacts_screen.dart`**
   - Contact list loading states

3. **`lib/src/features/chats/widgets/chat_view.dart`**
   - Message list loading states (1-on-1 chats)

4. **`lib/src/features/chats/widgets/group_chat_view.dart`**
   - Message list loading states (group chats)

---

## Available Skeleton Components

### 1. Base Components

#### `SkeletonLoader`
Generic rectangular skeleton with shimmer effect.

```dart
SkeletonLoader(
  width: 200,
  height: 16,
  borderRadius: BorderRadius.circular(4),
)
```

**Parameters:**
- `width`: Width of the skeleton
- `height`: Height of the skeleton
- `borderRadius`: Border radius (optional)
- `baseColor`: Base gray color (optional, auto dark/light)
- `highlightColor`: Shimmer highlight color (optional)

#### `SkeletonCircle`
Circular skeleton for avatars.

```dart
SkeletonCircle(size: 50)
```

---

### 2. Pre-built Patterns

#### `SkeletonConversationItem`
Complete skeleton for a chat list item (matches WhatsApp/Telegram style).

```dart
const SkeletonConversationItem()
```

**Includes:**
- Circle avatar (50px)
- Name line (full width)
- Message preview line (60% width)
- Timestamp (40px)
- Unread badge circle (20px)

#### `SkeletonMessageBubble`
Skeleton for individual messages in chat view.

```dart
SkeletonMessageBubble(isMe: false)
```

**Parameters:**
- `isMe`: If true, aligns right like sent messages

**Includes:**
- Sender avatar and name (for received messages)
- Message bubble (60px height, varying width)

#### `SkeletonContactItem`
Skeleton for contact list entries.

```dart
const SkeletonContactItem()
```

**Includes:**
- Circle avatar (48px)
- Name line (full width)
- Phone/email line (40% width)

#### `SkeletonStatusItem`
Skeleton for status/story circles (Instagram/WhatsApp style).

```dart
const SkeletonStatusItem()
```

**Includes:**
- Story ring with avatar (66px)
- Name label (60px wide)

---

### 3. Layout Helpers

#### `SkeletonList`
Shows multiple skeleton items in a scrollable list.

```dart
SkeletonList(
  skeletonItem: const SkeletonConversationItem(),
  itemCount: 8,
  padding: EdgeInsets.all(16),
)
```

**Use case:** Loading state for chat lists, contact lists, etc.

#### `SkeletonGrid`
Shows skeleton items in a grid layout.

```dart
SkeletonGrid(
  skeletonItem: const SkeletonStatusItem(),
  itemCount: 8,
  crossAxisCount: 4,
)
```

**Use case:** Status/story grids, photo galleries

---

## Usage Examples

### Example 1: Chat List Loading

**Before:**
```dart
child: conversations.isEmpty && isLoading
    ? const Center(child: CircularProgressIndicator())
    : ListView.builder(...)
```

**After:**
```dart
child: conversations.isEmpty && isLoading
    ? const SkeletonList(
        skeletonItem: SkeletonConversationItem(),
        itemCount: 8,
      )
    : ListView.builder(...)
```

---

### Example 2: Contact List Loading

**Before:**
```dart
if (_allContacts.isEmpty && _isLoading) {
  return const Center(child: CircularProgressIndicator());
}
```

**After:**
```dart
if (_allContacts.isEmpty && _isLoading) {
  return const SkeletonList(
    skeletonItem: SkeletonContactItem(),
    itemCount: 10,
  );
}
```

---

### Example 3: Message List Loading

**Before:**
```dart
child: _isLoading
    ? const Center(child: CircularProgressIndicator())
    : _messages.isEmpty
        ? EmptyState()
        : MessageList()
```

**After:**
```dart
child: _isLoading
    ? ListView.builder(
        itemCount: 8,
        itemBuilder: (context, index) => SkeletonMessageBubble(
          isMe: index % 3 == 0, // Mix sent/received
        ),
      )
    : _messages.isEmpty
        ? EmptyState()
        : MessageList()
```

---

### Example 4: Custom Skeleton Pattern

For unique layouts, build with base components:

```dart
Widget buildCustomSkeleton() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        // Avatar
        const SkeletonCircle(size: 40),
        const SizedBox(width: 12),
        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              SkeletonLoader(
                width: double.infinity,
                height: 18,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 6),
              // Subtitle
              SkeletonLoader(
                width: 200,
                height: 14,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
```

---

## Animation Details

The shimmer animation:
- **Duration:** 1500ms
- **Curve:** `Curves.easeInOutSine` (smooth wave)
- **Pattern:** Left-to-right gradient sweep
- **Repeat:** Infinite loop
- **Colors:** Auto-adapts to light/dark theme

**Dark Mode:**
- Base: `#2A2A2A`
- Highlight: `#3A3A3A`

**Light Mode:**
- Base: `#E0E0E0`
- Highlight: `#F5F5F5`

---

## Best Practices

### 1. Item Count
Show enough skeletons to fill the viewport (typically 6-10 items).

```dart
// Good
SkeletonList(itemCount: 8)

// Too few - shows awkward empty space
SkeletonList(itemCount: 2)
```

### 2. Realistic Patterns
Mix patterns for realism in message lists:

```dart
ListView.builder(
  itemCount: 8,
  itemBuilder: (context, index) => SkeletonMessageBubble(
    isMe: index % 3 == 0, // Every 3rd message is from me
  ),
)
```

### 3. Consistent Sizes
Match skeleton sizes to actual content:

```dart
// Avatar size matches actual avatar
const SkeletonCircle(size: 50) // Same as real avatar
```

### 4. Replace, Don't Add
Use skeletons **instead of** loading indicators, not in addition:

```dart
// Good
isLoading ? SkeletonList(...) : ActualList(...)

// Bad - shows both
Column([
  if (isLoading) SkeletonList(...),
  ActualList(...),
])
```

### 5. Quick Transitions
Keep skeleton loading time to when there's no cached data:

```dart
// Good - show data immediately if cached
return data.isEmpty && isLoading
    ? SkeletonList(...)
    : DataList(data)

// Bad - always shows skeleton first
return isLoading
    ? SkeletonList(...)
    : DataList(data)
```

---

## Performance Considerations

### Lightweight Animation
Each skeleton uses a single `AnimationController` shared by gradient:
- Memory: ~100 bytes per skeleton
- CPU: Minimal (only gradient updates)
- GPU: Hardware-accelerated gradient rendering

### Disposal
Controllers are automatically disposed via `SingleTickerProviderStateMixin`:
```dart
@override
void dispose() {
  _controller.dispose(); // Automatic cleanup
  super.dispose();
}
```

### ListView Optimization
Use `ListView.builder` for skeletons to only render visible items:

```dart
// Good - only renders visible skeletons
ListView.builder(
  itemCount: 8,
  itemBuilder: (context, index) => SkeletonConversationItem(),
)

// Bad - renders all at once
Column(
  children: List.generate(8, (_) => SkeletonConversationItem()),
)
```

---

## Testing

### Manual Testing Checklist

- [ ] Skeleton appears immediately on first load
- [ ] Shimmer animation is smooth (no jank)
- [ ] Skeleton disappears when data loads
- [ ] Correct item count for viewport size
- [ ] Dark/light theme colors look good
- [ ] Transitions smoothly to real content
- [ ] No skeleton shown when data is cached

### Visual Verification

1. **Alignment**: Skeleton items match real item positions
2. **Sizing**: Skeleton dimensions match real content
3. **Animation**: Shimmer moves smoothly left-to-right
4. **Theme**: Colors appropriate for light/dark mode

### Performance Testing

```dart
// Test with slow network
await Future.delayed(Duration(seconds: 3)); // Simulate slow load
// Skeleton should show for 3 seconds, then load smoothly
```

---

## Comparison: Before vs After

### Before (Circular Progress Indicator)
```
[Empty white screen]
        ⭕ (spinning)
[Empty white screen]
```

**Issues:**
- No context for what's loading
- Boring, generic appearance
- Feels slow even when fast
- Abrupt content appearance

### After (Skeleton Loaders)
```
┌─────────────────────────────┐
│ ⚪ ▬▬▬▬▬▬▬▬▬▬▬      ▬▬ ⚪ │ ← shimmer
│ ⚪ ▬▬▬▬▬▬▬▬▬▬▬▬     ▬▬ ⚪ │   animation
│ ⚪ ▬▬▬▬▬▬▬▬▬▬       ▬▬ ⚪ │   sweeps
└─────────────────────────────┘   across
```

**Benefits:**
- Shows structure immediately
- Professional appearance
- Feels faster
- Smooth content transition

---

## Customization

### Custom Colors

```dart
SkeletonLoader(
  width: 100,
  height: 20,
  baseColor: Colors.blue[100],
  highlightColor: Colors.blue[200],
)
```

### Custom Animation Speed

Modify in `skeleton_loader.dart`:

```dart
_controller = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 1000), // Faster
)..repeat();
```

### Custom Gradient Pattern

Modify stops in `build()`:

```dart
stops: [
  _animation.value - 0.3, // Narrower highlight
  _animation.value,
  _animation.value + 0.3,
].map((e) => e.clamp(0.0, 1.0)).toList(),
```

---

## Troubleshooting

### Issue: Skeleton doesn't animate

**Cause:** Parent widget doesn't have `SingleTickerProviderStateMixin`

**Solution:** Use stateless parent:
```dart
// Good
return SkeletonList(...);

// Bad - StatefulWidget needs TickerProvider
class MyWidget extends StatefulWidget {
  // Missing: with SingleTickerProviderStateMixin
}
```

### Issue: Skeleton flickers

**Cause:** Multiple rebuilds during loading

**Solution:** Cache loading state:
```dart
bool _isLoading = true; // Stable state
```

### Issue: Wrong colors in dark mode

**Cause:** Hard-coded colors

**Solution:** Use auto-detecting colors:
```dart
SkeletonLoader(...) // Auto-detects theme
```

---

## Future Enhancements

Possible improvements:
- [ ] Pulse animation option (fade in/out)
- [ ] Skeleton for grid items
- [ ] Skeleton for cards/tiles
- [ ] Facebook-style wave pattern
- [ ] Configurable shimmer direction

---

## References

- **WhatsApp Web**: Uses skeleton loaders for chat list
- **Telegram Desktop**: Uses skeleton loaders for messages
- **Discord**: Uses skeleton loaders for channels/servers
- **Material Design**: Recommends skeleton screens over spinners

---

*Last Updated: February 21, 2026*
*Version: 1.0.0*
