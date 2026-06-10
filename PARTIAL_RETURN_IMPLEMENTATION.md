# Partial Return Order Feature - Implementation Summary

## ✅ Implementation Complete

This document summarizes the complete implementation of the Partial Return Order feature that allows customers to return specific items or partial quantities from delivered orders within a configurable return window.

---

## 🔹 Features Implemented

### 1. Return Eligibility Rules ✅

- **Return button appears ONLY if:**
  - Order status = `Delivered`
  - Current date ≤ Delivery Date + Return Window (default 7 days)
  - Returns are enabled in admin settings
  - Items are available for return (not fully returned)

- **Return button is hidden/disabled if:**
  - Return window expired
  - All items already fully returned
  - Returns are disabled globally

- **Expiry message shown:**
  - "Return period has expired. Returns are allowed within X days from delivery."

### 2. Admin Panel – Return Policy Configuration ✅

**Location:** Admin Panel → Settings → Return Policy

**Features:**
- **Return Window (in days)** - Input field (number, default: 7)
- **Enable/Disable Returns** - Toggle switch
- Settings stored in `settings` table with key `return_policy`
- Changes apply to new deliveries only (does not affect already expired orders)

**Files:**
- `Najmi-Admin-main/lib/features/settings/return_policy_settings_screen.dart`
- `Najmi-Admin-main/lib/features/settings/return_policy_provider.dart`

### 3. Mobile App – UI Changes ✅

**Order Details Screen:**
- Shows "Return Items" button for delivered orders
- Displays remaining days counter: "Return available for X more days"
- Shows expiry message when return window expired
- Displays return status badges for existing returns
- Button disabled with tooltip when not eligible

**Return Selection Screen:**
- Lists delivered items with:
  - Item name & image
  - Delivered quantity
  - Already returned quantity (if any)
  - Remaining returnable quantity
- Quantity selector (1 → remaining qty)
- Auto-selects item when quantity > 0
- Mandatory return reason dropdown
- Optional comment box
- Confirm Return CTA with validation

**Files:**
- `najmi_app-main/lib/features/orders/presentation/screens/order_details_screen.dart`
- `najmi_app-main/lib/features/orders/presentation/screens/return_request_screen.dart`

### 4. Backend Logic Updates ✅

**Return Service (`return_service.dart`):**
- Validates order delivery date
- Validates return request date ≤ delivery_date + return_window_days
- Rejects request if expired
- Validates item quantities (prevents over-returning)
- Validates returns are enabled
- Timezone-safe date calculations

**Return Request Structure:**
```json
{
  "order_id": "",
  "user_id": "",
  "return_status": "pending",
  "return_reason": "Damaged",
  "notes": "",
  "refund_amount": 0.0,
  "items": [
    {
      "product_id": "",
      "product_name": "",
      "quantity": 2,
      "unit_price": 0.0,
      "total_price": 0.0,
      "quality_option_name": "",
      "unit": ""
    }
  ]
}
```

**Files:**
- `najmi_app-main/lib/features/orders/data/services/return_service.dart`
- `najmi_app-main/lib/features/orders/data/models/return_model.dart`

### 5. Database Schema ✅

**Tables Created:**
1. **`returns`** - Stores return requests
   - `id`, `order_id`, `user_id`, `return_status`, `return_reason`, `notes`, `refund_amount`, `created_at`, `updated_at`

2. **`return_items`** - Stores items in each return
   - `id`, `return_id`, `product_id`, `product_name`, `quantity`, `unit_price`, `total_price`, `quality_option_name`, `unit`, `created_at`

3. **`settings`** - Stores return policy configuration
   - `key: 'return_policy'`, `value: {"returns_enabled": true, "return_window_days": 7}`

**Database Functions:**
- `validate_return_request()` - Validates return eligibility at database level
- `validate_return_before_insert()` - Trigger function for validation

**Files:**
- `add_returns_tables.sql`
- `add_return_policy_settings.sql`
- `return_validation_function.sql`

### 6. Order & Item Status Handling ✅

- Order status remains `Delivered` (not changed)
- Item-level status shows:
  - Returned quantity
  - Remaining returnable quantity
  - Return status badges: "Partial Return Requested", "Return Window Expired"
- Multiple return requests allowed within window
- Prevents over-returning same item

### 7. Edge Case Handling ✅

- ✅ Multiple return requests allowed within window
- ✅ Prevents over-returning same item (backend validation)
- ✅ Return window countdown is timezone-safe (UTC calculations)
- ✅ Disables return instantly after expiry
- ✅ Validates quantities before submission
- ✅ Handles missing delivery dates gracefully
- ✅ Validates returns are enabled before allowing requests

### 8. Quality & Safety Requirements ✅

- ✅ No impact on Cancel / Refund / Delivery logic
- ✅ Fully backend-validated (not UI-only)
- ✅ Clean UI aligned with existing delivery screen
- ✅ No breaking changes to existing APIs
- ✅ Database-level validation via triggers
- ✅ Service-level validation before submission

---

## 📁 File Structure

### Mobile App (Flutter)
```
najmi_app-main/
├── lib/features/orders/
│   ├── data/
│   │   ├── models/
│   │   │   ├── return_model.dart
│   │   │   └── order_model.dart
│   │   └── services/
│   │       └── return_service.dart
│   └── presentation/screens/
│       ├── order_details_screen.dart
│       └── return_request_screen.dart
```

### Admin Panel (Flutter)
```
Najmi-Admin-main/
├── lib/features/
│   ├── settings/
│   │   ├── return_policy_settings_screen.dart
│   │   └── return_policy_provider.dart
│   └── returns/
│       └── returns_management_screen.dart
```

### Database Migrations
```
admin+app/
├── add_returns_tables.sql
├── add_return_policy_settings.sql
└── return_validation_function.sql
```

---

## 🚀 Setup Instructions

### 1. Database Setup

Run these SQL files in Supabase SQL Editor (in order):

1. **`add_return_policy_settings.sql`** - Creates settings table and default return policy
2. **`add_returns_tables.sql`** - Creates returns and return_items tables
3. **`return_validation_function.sql`** - Creates validation functions and triggers

### 2. Verify Settings

Check that return policy settings exist:
```sql
SELECT * FROM settings WHERE key = 'return_policy';
```

Should return:
```json
{
  "returns_enabled": true,
  "return_window_days": 7
}
```

### 3. Test Return Flow

1. Mark an order as "Delivered" (sets `delivered_at` timestamp)
2. Navigate to Order Details in mobile app
3. Verify "Return Items" button appears
4. Click button and select items/quantities
5. Submit return request
6. Verify return appears in admin panel

---

## 🔍 Validation Flow

### Client-Side (Mobile App)
1. Check order status = "delivered"
2. Check return window not expired
3. Check returns enabled
4. Check items available for return
5. Validate quantities before submission

### Service-Level (ReturnService)
1. Fetch order and validate delivery date
2. Check return policy settings
3. Validate return window (timezone-safe)
4. Validate item quantities
5. Prevent over-returning

### Database-Level (PostgreSQL)
1. Trigger fires before INSERT on `returns` table
2. Calls `validate_return_request()` function
3. Validates order status, delivery date, return window
4. Raises exception if validation fails
5. Prevents invalid return requests at database level

---

## 📊 Return Status Flow

1. **Pending** - Customer submits return request
2. **Approved** - Admin approves return
3. **Rejected** - Admin rejects return
4. **Completed** - Return processed and refunded
5. **Cancelled** - Customer cancels pending return

---

## 🎯 Key Features

✅ **Configurable Return Window** - Admin can set return window (default 7 days)
✅ **Global Toggle** - Admin can enable/disable returns globally
✅ **Partial Returns** - Customers can return specific items and quantities
✅ **Multiple Returns** - Multiple return requests allowed within window
✅ **Backend Validation** - Multi-layer validation (UI, Service, Database)
✅ **Timezone-Safe** - All date calculations use UTC
✅ **Quantity Validation** - Prevents over-returning items
✅ **Clean UI** - Integrated seamlessly with existing order details screen
✅ **Status Badges** - Clear visual indicators for return status
✅ **Expiry Awareness** - Real-time countdown and expiry messages

---

## 🔐 Security

- Row Level Security (RLS) enabled on all tables
- Users can only view/create their own returns
- Admin-only access to return policy settings
- Database-level validation prevents bypassing client checks
- Timezone-safe calculations prevent date manipulation

---

## 📝 Notes

- Return policy changes apply to **new deliveries only**
- Already expired orders are not affected by policy changes
- Return window is calculated from `delivered_at` timestamp
- All date calculations use UTC for consistency
- Multiple partial returns can be made within the return window
- Return status does not affect order status (order remains "Delivered")

---

## ✅ Testing Checklist

- [x] Return button appears for delivered orders within window
- [x] Return button disabled when window expired
- [x] Return button disabled when all items returned
- [x] Return selection screen shows correct quantities
- [x] Quantity validation prevents over-returning
- [x] Backend validation rejects expired returns
- [x] Database trigger prevents invalid returns
- [x] Admin can configure return window
- [x] Admin can enable/disable returns
- [x] Multiple partial returns work correctly
- [x] Return status badges display correctly
- [x] Expiry messages show correctly
- [x] Timezone calculations are accurate

---

## 🎉 Implementation Complete!

All requirements have been implemented and tested. The Partial Return Order feature is fully functional and ready for use.

