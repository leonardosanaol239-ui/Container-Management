# Notification System Implementation

## Overview
The notification system has been fully implemented with persistent storage and real-time updates.

## Features Implemented

### 1. **Persistent Notification Storage**
- Notifications are stored using `SharedPreferences`
- Read/unread status persists across app restarts
- Seen notification IDs are tracked to prevent duplicates
- Maximum of 50 notifications stored (older ones are automatically removed)

### 2. **Real-Time Updates**
- Notifications poll every 10 seconds for new movements and move-outs
- Badge indicator updates in real-time when new notifications arrive
- Unread count is automatically calculated and displayed

### 3. **Sidebar Badge Indicator**
- Red circular badge appears on the "Notifications" nav item when there are unread notifications
- Shows the count of unread notifications (displays "99+" if more than 99)
- Badge has a glowing effect to draw attention
- Badge disappears when all notifications are marked as read
- Works in both collapsed and expanded sidebar states

### 4. **Notification Panel Access**
- Click on "Notifications" in the sidebar to open the notification panel
- Panel shows all notifications with filtering options (All, Movements, Move Out)
- Mark individual notifications as read by clicking on them
- "Mark read" button to mark all as read at once
- "Clear" button to remove all notifications

### 5. **Port Management**
- Moved to the "Ports" nav item in the sidebar (index 1)
- Opens the Port Selection Dialog when clicked

## Storage Keys

The following keys are used in SharedPreferences:

- `app_notifications_v1` - Stores the notification list with read/unread status
- `seen_movement_ids_v1` - Tracks which movement notifications have been created
- `seen_moveout_ids_v1` - Tracks which move-out notifications have been created

## Notification Types

1. **Movement Notifications**
   - Triggered when a container movement is confirmed
   - Shows container number, port, and location details
   - Includes metadata: Block, Bay, Row, Tier, Type, Confirmed date, etc.

2. **Move-Out Notifications**
   - Triggered when a container is moved out
   - Shows container number, origin port, and destination
   - Includes metadata: From Port, Bound To, Type, Moved Out date, etc.

## User Experience Flow

### First Login
1. User logs in
2. Notification service initializes and loads any existing notifications from storage
3. System polls for new movements/move-outs every 10 seconds
4. If new notifications are detected, badge appears on sidebar

### Viewing Notifications
1. User sees red badge on "Notifications" nav item
2. User clicks on "Notifications"
3. Notification panel opens showing all unread notifications
4. User can filter by type or view all
5. Clicking a notification marks it as read and shows details

### Marking as Read
1. User clicks "Mark read" button to mark all as read
2. Or clicks individual notifications to mark them as read
3. Badge disappears when unread count reaches 0
4. Read status is saved to SharedPreferences

### App Restart
1. User closes the app
2. User reopens the app and logs in
3. Previously read notifications remain marked as read
4. Only new notifications (not seen before) will appear as unread
5. Badge only shows if there are new unread notifications

## Technical Details

### NotificationService Class
- Singleton pattern for global access
- Implements `ChangeNotifier` for reactive updates
- Automatic polling every 10 seconds
- Persistent storage using `shared_preferences` package
- Tracks seen notification IDs to prevent duplicates

### Badge Implementation
- Located in `_NavItem` widget
- Listens to `NotificationService` for changes
- Updates automatically when unread count changes
- Positioned absolutely over the nav item
- Red color with glow effect for visibility

### Files Modified
1. `lib/screens/dashboard_screen.dart`
   - Added badge support to `_Sidebar` widget
   - Updated `_NavItem` to show badge and listen to notifications
   - Moved port management to "Ports" nav item
   - Moved notifications to "Notifications" nav item
   - Removed notification bell from top nav

2. `lib/widgets/notification_panel.dart`
   - Added `NotificationPanel` wrapper widget for dialog use

3. `lib/services/notification_service.dart`
   - Already had full persistence implementation
   - No changes needed

## Testing Checklist

- [x] Badge appears when there are unread notifications
- [x] Badge shows correct unread count
- [x] Badge disappears when all notifications are marked as read
- [x] Clicking "Notifications" opens the panel
- [x] Notifications persist across app restarts
- [x] Read status persists across app restarts
- [x] New notifications appear in real-time (10-second polling)
- [x] Duplicate notifications are prevented
- [x] Badge works in both collapsed and expanded sidebar
- [x] "Ports" nav item opens port management dialog

## Future Enhancements (Optional)

1. Push notifications for instant alerts
2. Sound/vibration when new notifications arrive
3. Notification categories with different colors
4. Export notifications to CSV/PDF
5. Notification search functionality
6. Custom notification retention period
7. Notification priority levels
