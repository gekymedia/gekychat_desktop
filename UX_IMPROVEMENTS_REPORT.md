# GekyChat Desktop - UX Improvements Report

## Date: 2026-02-21

### 1. ✅ FIXED: Links in Message Bubbles Not Clickable
**Issue**: URLs in message text were not detected or clickable
**Impact**: High - Users couldn't click links shared in messages
**Fix**: Added URL detection regex and click handler to `message_bubble.dart`
- Detects http://, https://, and www. URLs
- Opens links in external browser
- Preserves text formatting while making links clickable
- Works alongside existing phone number detection

---

## Additional UX Improvements Identified

### 2. Empty State Improvements
**Current State**: Many screens lack helpful empty states
**Recommended Improvements**:
- Add helpful illustrations/icons for empty conversations list
- Add actionable text (e.g., "No contacts yet. Tap + to invite someone!")
- Add quick action buttons in empty states

**Priority**: Medium
**Effort**: Low

---

### 3. Loading State Improvements
**Current State**: Some screens use basic CircularProgressIndicator
**Recommended Improvements**:
- Add skeleton loaders for chat lists (shimmer effect)
- Add inline loading indicators that don't block UI
- Add progress indicators for file uploads/downloads
- Use determinate progress bars where possible

**Priority**: Medium
**Effort**: Medium

---

### 4. Snackbar Consistency
**Current State**: Snackbars vary in duration and style
**Recommended Improvements**:
- Standardize error snackbars (red background, 4s duration)
- Standardize success snackbars (green background, 2s duration)
- Add action buttons where relevant (e.g., "Undo", "Retry")
- Use consistent positioning

**Priority**: Low
**Effort**: Low

---

### 5. Search Experience
**Current State**: Basic text search in contacts and chats
**Recommended Improvements**:
- Add search history/suggestions
- Add search filters (by date, type, sender)
- Add "no results" state with suggestions
- Add keyboard shortcuts for search (Ctrl+F)
- Clear button (X) in search field

**Priority**: Medium
**Effort**: Medium

---

### 6. Input Field Enhancements
**Current State**: Text fields lack some polish
**Recommended Improvements**:
- Add character count for limited fields
- Add input validation with helpful error messages
- Add clear button (X) for text inputs
- Add placeholder text improvements
- Add autofocus on important fields

**Priority**: Low
**Effort**: Low

---

### 7. Confirmation Dialogs
**Current State**: Some destructive actions lack confirmation
**Recommended Improvements**:
- Add confirmation for delete actions
- Add "Don't ask again" option where appropriate
- Use clear action button labels ("Delete Chat" vs "OK")
- Add warning icons for destructive actions

**Priority**: High
**Effort**: Low

---

### 8. Keyboard Shortcuts
**Current State**: Limited keyboard shortcut support
**Recommended Improvements**:
- Add shortcuts overlay (Ctrl+?) to show all shortcuts
- Add shortcuts for common actions:
  - Ctrl+N: New chat
  - Ctrl+F: Search
  - Ctrl+W: Close current chat
  - Esc: Cancel/Close
  - Ctrl+Enter: Send message

**Priority**: Medium
**Effort**: Medium

---

### 9. Context Menu Improvements
**Current State**: Right-click menus work but could be enhanced
**Recommended Improvements**:
- Add more contextual actions
- Add icons to menu items
- Add keyboard shortcuts shown in menu
- Add separator lines for grouping

**Priority**: Low
**Effort**: Low

---

### 10. Message Status Indicators
**Current State**: Basic checkmarks for sent/delivered/read
**Recommended Improvements**:
- Add tooltip on hover explaining status
- Add pending/retry state for failed messages
- Add "Sending..." text for outgoing messages
- Add timestamp on hover

**Priority**: Medium
**Effort**: Low

---

### 11. Drag & Drop Enhancement
**Current State**: Drag & drop exists but visual feedback could improve
**Recommended Improvements**:
- Add overlay with "Drop files here" text
- Show file preview before sending
- Add multi-file drag support indicator
- Add animation when dropping

**Priority**: Low
**Effort**: Low

---

### 12. Settings Organization
**Current State**: Settings screen has duplicate "Account" section
**Bug**: Two "Account" sections in settings (lines 42 and 134)
**Fix**: Merge or rename one section

**Priority**: High (Bug Fix)
**Effort**: Very Low

---

### 13. Notification Improvements
**Current State**: Basic notifications
**Recommended Improvements**:
- Add notification sound preferences
- Add do-not-disturb mode
- Add custom notification rules per chat
- Add notification grouping

**Priority**: Low
**Effort**: Medium

---

### 14. Accessibility
**Current State**: Limited accessibility features
**Recommended Improvements**:
- Add screen reader labels
- Add high contrast mode
- Add text scaling support
- Add keyboard navigation indicators

**Priority**: Medium
**Effort**: High

---

### 15. Error Messages
**Current State**: Technical error messages shown to users
**Recommended Improvements**:
- Use user-friendly error messages
- Add error codes for support reference
- Add "Report Problem" action
- Add retry mechanisms

**Priority**: Medium
**Effort**: Medium

---

## Quick Wins (Easy to implement, high impact)

1. ✅ **Fix clickable links** - COMPLETED
2. **Fix duplicate Account section in Settings** - 1 line change
3. **Add clear (X) button to search fields** - Simple widget addition
4. **Add confirmation dialogs for destructive actions** - Wrap existing actions
5. **Improve empty state messages** - Text changes mostly

---

## Implementation Priority

### Phase 1 (Immediate - This Session)
- [x] Fix clickable links in messages
- [ ] Fix duplicate Account section
- [ ] Add clear button to search fields
- [ ] Add confirmation dialogs for delete actions
- [ ] Improve empty state messages

### Phase 2 (Next Update)
- [ ] Add skeleton loaders
- [ ] Improve loading states
- [ ] Add keyboard shortcuts guide
- [ ] Improve message status tooltips

### Phase 3 (Future)
- [ ] Add search filters
- [ ] Add notification preferences
- [ ] Accessibility improvements
- [ ] Advanced keyboard shortcuts
