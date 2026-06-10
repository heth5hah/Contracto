# 🚀 Quick Start Guide - Running Both Apps

## ✅ Both Apps Are Starting!

### 📱 **Mobile App** (Android Device: RMX3371)
- **Location**: `admin+app/najmi_app-main/`
- **Running on**: Your connected Android device
- **Status**: Starting in background...

### 💻 **Admin Panel** (Windows Desktop)
- **Location**: `admin+app/Najmi-Admin-main/`
- **Running on**: Windows desktop window
- **Status**: Starting in background...

---

## 📋 What to Expect

### Mobile App (Android)
1. App will install on your device
2. Splash screen will appear
3. Login screen will show
4. You can test the return feature:
   - Navigate to Orders
   - Open a delivered order
   - Click "Return Items" button
   - Test return flow

### Admin Panel (Windows)
1. Admin panel window will open
2. Login screen will appear
3. After login, you can:
   - Go to **Settings → Return Policy**
   - Configure return window (default: 7 days)
   - Toggle returns on/off
   - View return requests in **Returns** section

---

## 🔧 Manual Commands (If Needed)

### Start Admin Panel Manually:
```bash
cd "C:\Paid Project\admin_app_final\admin+app\Najmi-Admin-main"
flutter run -d windows
```

### Start Mobile App Manually:
```bash
cd "C:\Paid Project\admin_app_final\admin+app\najmi_app-main"
flutter run -d 124c1f12
```

### Check Connected Devices:
```bash
flutter devices
```

---

## 🧪 Testing Return Feature

### Step 1: Configure Return Policy (Admin Panel)
1. Login to admin panel
2. Go to **Settings → Return Policy**
3. Set return window (e.g., 7 days)
4. Enable returns
5. Save settings

### Step 2: Mark Order as Delivered (Admin Panel)
1. Go to **Orders** section
2. Find an order
3. Change status to **"Delivered"**
4. This sets the `delivered_at` timestamp

### Step 3: Test Return (Mobile App)
1. Open the mobile app
2. Navigate to **Orders**
3. Open the delivered order
4. You should see:
   - "Return Items" button
   - Remaining days counter
   - Return eligibility status
5. Click "Return Items"
6. Select items and quantities
7. Submit return request

### Step 4: View Return Request (Admin Panel)
1. Go to **Returns** section
2. You should see the pending return request
3. Approve/Reject as needed

---

## 🐛 Troubleshooting

### App Not Starting?
- Check Flutter is installed: `flutter --version`
- Check devices: `flutter devices`
- Get dependencies: `flutter pub get`

### Mobile Device Not Detected?
- Enable USB debugging on your Android device
- Connect device via USB
- Run: `flutter devices` to verify

### Admin Panel Not Opening?
- Make sure Windows desktop support is enabled
- Check: `flutter devices` should show "Windows (desktop)"

### Return Button Not Showing?
- Make sure order status is "Delivered"
- Check `delivered_at` is set (run SQL migration if not done)
- Verify return window hasn't expired
- Check returns are enabled in admin settings

---

## 📝 Next Steps

1. ✅ **Run Database Migrations** (if not done)
   - Open Supabase SQL Editor
   - Run: `run_all_return_migrations.sql`

2. ✅ **Test Return Flow**
   - Configure return policy
   - Mark order as delivered
   - Test return in mobile app
   - Approve return in admin panel

3. ✅ **Verify Everything Works**
   - Return button appears for delivered orders
   - Return window countdown works
   - Return submission works
   - Admin can see return requests

---

## 🎉 Success!

Both apps should now be running:
- **Admin Panel**: Windows desktop window
- **Mobile App**: Your Android device

Happy testing! 🚀

