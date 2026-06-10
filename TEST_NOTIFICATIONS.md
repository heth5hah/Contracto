# Testing the Notification System

## Step 1: Verify Database Setup ✅

The SQL migration should have completed successfully. Verify with:

```sql
-- Check if notifications table exists with all columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'notifications' 
ORDER BY ordinal_position;

-- Should show: id, source, target, user_id, title, message, type, reference_id, is_read, sound_played, created_at, updated_at, metadata
```

## Step 2: Test Admin Notifications

### Test 1: Create a Test Notification
Run this in Supabase SQL Editor to create a test notification:

```sql
SELECT create_notification(
  'app',           -- source
  'admin',         -- target
  'Test Notification',  -- title
  'This is a test notification to verify the system works',  -- message
  'system',         -- type
  NULL,             -- user_id (optional)
  NULL,             -- reference_id (optional)
  NULL              -- metadata (optional)
);
```

### Test 2: Check Admin Panel
1. Open Admin Panel in browser
2. Look for the 🔔 notification bell icon in the top header
3. You should see a badge with count "1" (or the number of unread notifications)
4. Click the bell icon
5. You should see the test notification in the dropdown

## Step 3: Test Real-Time Notifications

### Test 3: Submit Order from Mobile App
1. Open mobile app
2. Place a new order
3. **Expected Result:**
   - Admin panel should show a toast notification
   - Notification bell badge should increment
   - Sound/haptic feedback should play
   - New notification appears in dropdown

### Test 4: Submit Quotation from Mobile App
1. Submit a quotation request from mobile app
2. **Expected Result:**
   - Admin receives notification instantly
   - Badge count updates

### Test 5: Submit Return Request from Mobile App
1. Submit a return request from mobile app
2. **Expected Result:**
   - Admin receives notification instantly
   - Badge count updates

## Step 4: Test User Notifications

### Test 6: Change Order Status (Admin → User)
1. In Admin Panel, go to Orders
2. Change an order status (e.g., from "pending" to "confirmed")
3. **Expected Result:**
   - Mobile app user should receive notification
   - Notification appears in mobile app notifications screen

### Test 7: Approve/Reject Quotation (Admin → User)
1. In Admin Panel, approve or reject a quotation
2. **Expected Result:**
   - Mobile app user receives notification

### Test 8: Approve/Reject Return (Admin → User)
1. In Admin Panel, approve or reject a return request
2. **Expected Result:**
   - Mobile app user receives notification

## Step 5: Verify Features

### ✅ Checklist:
- [ ] Notification bell appears in admin header
- [ ] Badge shows unread count
- [ ] Clicking bell opens dropdown
- [ ] Notifications list shows in dropdown
- [ ] Toast appears when new notification arrives
- [ ] Sound/haptic feedback plays
- [ ] Mark as read works
- [ ] Mark all as read works
- [ ] Navigation to related pages works
- [ ] Real-time updates work (no refresh needed)

## Troubleshooting

### Notifications not appearing?
1. **Check Supabase Realtime:**
   - Go to Supabase Dashboard → Database → Replication
   - Ensure `notifications` table has replication enabled

2. **Check RLS Policies:**
   ```sql
   SELECT * FROM pg_policies WHERE tablename = 'notifications';
   ```

3. **Check Triggers:**
   ```sql
   SELECT trigger_name, event_manipulation, event_object_table
   FROM information_schema.triggers
   WHERE event_object_table IN ('orders', 'quote_requests', 'returns');
   ```

4. **Check Browser Console:**
   - Open browser DevTools (F12)
   - Look for errors in Console tab
   - Check Network tab for failed requests

### Badge count not updating?
1. Refresh the page
2. Check if real-time subscription is active:
   - Look for "Subscribed to notifications" in console
3. Manually refresh count:
   - The service should auto-refresh, but you can check logs

### Sound not playing?
- Currently uses haptic feedback (vibration)
- For custom sounds, need to add audio files (see implementation guide)

## Next Steps After Testing

Once everything works:

1. **Customize Notification Messages** (Optional)
   - Edit trigger functions to customize message text
   - Add more notification types if needed

2. **Add Custom Sounds** (Optional)
   - Add audio files to `assets/sounds/`
   - Update `notification_bell_widget.dart` to use audio_player

3. **Setup Push Notifications** (Optional)
   - Configure Firebase Cloud Messaging
   - Add FCM token storage
   - Setup backend service for sending push notifications

4. **Add Notification Badge to Mobile App** (Recommended)
   - Add notification icon to mobile app header
   - Show unread count badge
   - Link to notifications screen

## Quick Test Commands

### Create Test Notifications:
```sql
-- Admin notification
SELECT create_notification('app', 'admin', 'Test Admin Notification', 'This is a test', 'system');

-- User notification (replace USER_ID with actual user ID)
SELECT create_notification('admin', 'user', 'Test User Notification', 'This is a test', 'system', 'USER_ID_HERE');
```

### Check Notification Count:
```sql
-- Admin unread count
SELECT COUNT(*) FROM notifications WHERE target = 'admin' AND is_read = false;

-- User unread count (replace USER_ID)
SELECT COUNT(*) FROM notifications WHERE target = 'user' AND user_id = 'USER_ID_HERE' AND is_read = false;
```

### View Recent Notifications:
```sql
-- Recent admin notifications
SELECT id, title, message, type, created_at, is_read 
FROM notifications 
WHERE target = 'admin' 
ORDER BY created_at DESC 
LIMIT 10;

-- Recent user notifications (replace USER_ID)
SELECT id, title, message, type, created_at, is_read 
FROM notifications 
WHERE target = 'user' AND user_id = 'USER_ID_HERE'
ORDER BY created_at DESC 
LIMIT 10;
```




