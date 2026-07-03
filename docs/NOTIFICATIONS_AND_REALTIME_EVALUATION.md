# GekyChat: Notifications & Real-Time Evaluation

Evaluation of why notifications are not instant, messages are not delivered instantly, and why the desktop chat UI appears to "reload" or "shake" during conversation — with comparison to WhatsApp/Telegram and recommended fixes.

---

## 1. Executive summary

| Issue | Root cause | Where |
|-------|------------|--------|
| **Notifications not instant** | Message broadcast is **queued** (job), not sent inline; queue worker delay + optional push pipeline | Laravel (gekychat) |
| **Messages not instant (desktop)** | On Windows, **Pusher is disabled** and replaced by **3-second polling** | gekychat_desktop |
| **UI shaking / “reloading every second”** | (1) **ListView builds the full message list N+1 times** per rebuild; (2) **Recording timer** calls `setState` every 1s and rebuilds the whole chat; (3) **No stable keys** on message items | gekychat_desktop `chat_view.dart` |

---

## 2. Backend (Laravel – gekychat)

### 2.1 How message delivery and broadcast work

- When a 1:1 message is stored, the controller dispatches **`BroadcastMessageSentJob::dispatch($msg->id)`** ([MessageController.php](d:/projects/gekychat/app/Http/Controllers/Api/V1/MessageController.php) ~453, ~1551, ~1624).
- The **broadcast is not sent in the same request**. It runs inside a **queued job**. So delivery is delayed by:
  - **Queue driver**: default is `database` ([config/queue.php](d:/projects/gekychat/config/queue.php)).
  - **Worker**: a process must run `php artisan queue:work` (or similar). If the worker is slow or not running, broadcasts are delayed.
- The event `MessageSent` implements **`ShouldBroadcastNow`**, so when the **job** runs it broadcasts immediately; the “now” applies to the job execution, not to the HTTP response. So from the user’s perspective, delivery is **not** instant.

**Comparison (WhatsApp/Telegram):**  
They push over a **persistent connection** (WebSocket/long-poll) and send the message event on the same logical path as storage (or with minimal, in-process fan-out). There is no separate queue step for the main real-time delivery.

**Recommendation:**

- For **truly instant** in-app delivery, **broadcast in the same request** after saving the message (e.g. `broadcast(new MessageSent($message))->toOthers();`) and keep the job only for retries or secondary channels (push, search index, etc.), **or**
- Ensure **queue worker is always running** and use a **fast queue driver** (e.g. Redis) with a dedicated worker so delay is minimal.

### 2.2 Push notifications (FCM / APNs)

- This evaluation did not trace the full path from “message saved” to “push notification”. If push is also done via a job (or a separate service), the same queue/worker and any extra network hop add latency.
- For “instant” notifications like WhatsApp/Telegram, the server typically sends the push (or triggers the push provider) immediately after persisting the message, often in the same process or via a very fast queue.

### 2.3 Reverb / Pusher

- [config/broadcasting.php](d:/projects/gekychat/config/broadcasting.php) supports **reverb** (self-hosted) and **pusher**. As long as the broadcast is sent (inline or from the job) and the WebSocket server is running and reachable, clients that use WebSockets will get events as soon as the server sends them. The main latency on “not instant” is the **queued broadcast**, not Reverb/Pusher themselves.

---

## 3. Desktop app (gekychat_desktop)

### 3.1 Real-time: WebSocket vs polling

- [pusher_service.dart](d:/projects/gekychat_desktop/lib/src/features/realtime/pusher_service.dart) **detects Windows** and **disables Pusher** (WebSocket), falling back to **polling**:
  - “Windows detected - using polling fallback instead of Pusher”
  - Message polling: **every 3 seconds** ([pusher_service.dart](d:/projects/gekychat_desktop/lib/src/features/realtime/pusher_service.dart) ~326: `Timer.periodic(const Duration(seconds: 3), ...)`).
- So on **Windows**, new messages can appear only when the next poll runs (up to **3 seconds** delay). That explains “messages aren’t delivered instantly” on desktop when running on Windows.

**Recommendation:**  
Re-enable WebSocket (Pusher/Reverb) on Windows if the underlying `pusher_client` (or alternative) supports it; or use a Windows-capable WebSocket client (e.g. for Reverb) so desktop gets events in real time instead of every 3 seconds.

### 3.2 UI “reloading” / “shaking” – root causes

The chat screen uses a single `ListView` and local state `_messages`. Three issues cause excessive rebuilds and the feeling that the list “reloads” or “shakes”:

#### A. Building the message list N+1 times per rebuild

In [chat_view.dart](d:/projects/gekychat_desktop/lib/src/features/chats/widgets/chat_view.dart):

- `itemCount: _buildMessageList().length`
- `itemBuilder: (context, index) => _buildMessageList()[index]`

So **every rebuild**:

- `_buildMessageList()` is called **once** for `itemCount` and **once per index** in `itemBuilder` → **N+1** full list builds (N = number of message + date items). This is expensive and amplifies any other `setState` (e.g. from recording or status updates).

**Recommendation:**  
Build the list **once** (e.g. cache in a field, or build a list of “slot” data and in `itemBuilder` build only the widget for that index from `_messages`). Do not call `_buildMessageList()` in both `itemCount` and `itemBuilder`.

#### B. Recording duration timer – setState every second

- [chat_view.dart](d:/projects/gekychat_desktop/lib/src/features/chats/widgets/chat_view.dart) ~1059–1069: `_updateRecordingDuration()` uses `Future.delayed(const Duration(seconds: 1), ...)` and then **`setState`** to update `_recordingDuration`.
- That **setState** runs on the **whole** `ChatView`. So **every second while recording**, the entire widget (including the message list) is rebuilt. Combined with (A), the list is rebuilt N+1 times every second → visible “reloading” / shaking.

**Recommendation:**  
Isolate the recording UI (duration, wave, etc.) in a **separate widget** (e.g. `RecordingBar`) that holds its own state or receives a stream/value and calls `setState` only inside that widget. The main chat body and message list should not rebuild every second.

#### C. No stable keys on list items

- The message list is built from `_messages` and date dividers but **no `key`** is set on the list items. Flutter cannot reliably match old and new widgets, so it may rebuild or repaint more than needed when the list updates.

**Recommendation:**  
Use a **stable key** per item, e.g. `ValueKey(message.id)` for message bubbles and something stable for date dividers (e.g. `ValueKey('date-${date.toIso8601String()}')`), so Flutter can update only what changed and avoid unnecessary layout/paint.

### 3.3 Other observations

- After `_loadMessages()` and after marking as read, the code calls **`ref.invalidate(optimizedConversationsProvider)`**. That refetches the conversation list and can cause the parent (and thus the chat area) to rebuild. It does not by itself explain a **periodic** “every second” reload, but it can add extra rebuilds when opening a chat or marking read. Keeping invalidation scoped to when the conversation list really needs to refresh will reduce unnecessary rebuilds.
- New messages and status updates are correctly applied via **setState** with list updates (add/update in place); the main problem is the **cost** of each setState (full list built N+1 times, no keys) and the **1-second timer** when recording.

---

## 4. Mobile app (gekychat_mobile)

- Uses **Pusher** (WebSocket) and does **not** force a polling fallback by platform. Real-time events (e.g. `MessageSent`) are subscribed per conversation/group and drive **upsertMessageAndConversationFromPusher** and local state updates.
- No equivalent of the desktop’s “build message list N+1 times” or “setState every second for recording” was identified in the same way. If mobile also “shakes,” it would be worth checking for similar patterns (periodic setState, building full list repeatedly, missing keys).

---

## 5. Comparison with WhatsApp / Telegram

| Aspect | WhatsApp / Telegram (typical) | GekyChat (current) |
|--------|------------------------------|----------------------|
| **New message delivery** | Push over persistent connection (WebSocket / long-poll); often same process or very fast path from DB to socket | Broadcast via **queued job**; desktop on Windows uses **3s polling** |
| **In-app list updates** | Append/update single item; list not fully rebuilt; stable item identity | Full rebuild of list; list built **N+1 times** per rebuild; **no keys**; **1s setState** when recording |
| **Push notifications** | Triggered immediately (or very fast) after message save | Not verified; if via queue, same delay as above |

---

## 6. Recommended fix order

1. **Desktop – UI stability (high impact, no backend change)**  
   - Build the message list **once per rebuild** (single list of “slots,” build only the widget for `index` in `itemBuilder`).  
   - Add **stable keys** (e.g. `ValueKey(message.id)`) to message and date items.  
   - Move **recording duration (and related UI)** into a **child widget** with its own state so its 1-second `setState` does not rebuild the whole chat and message list.

2. **Backend – instant broadcast (high impact)**  
   - **Broadcast inline** after storing the message: `broadcast(new MessageSent($message))->toOthers();` and keep `BroadcastMessageSentJob` only for retries or non-real-time side effects (e.g. search index, push).  
   - Or keep the job but ensure **queue worker is always running** and use a **fast driver** (e.g. Redis).

3. **Desktop – real-time on Windows (medium impact)**  
   - Enable WebSocket (Pusher/Reverb) on Windows, or use a Windows-compatible WebSocket client, so desktop does not rely on 3-second polling.

4. **Optional**  
   - Reduce or scope **`ref.invalidate(optimizedConversationsProvider)`** so it does not trigger unnecessary parent rebuilds when not needed.

After these changes, notifications and in-app message delivery should feel instant (or limited only by network and WebSocket latency), and the desktop chat should refresh **silently** with new messages appended without the list “reloading” or “shaking.”
