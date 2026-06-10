# Quick Razorpay Test Setup

## For Immediate Testing

### 1. Update Payment Config
Edit `lib/core/config/payment_config.dart`:
```dart
// Replace these with your actual test keys
static const String razorpayKeyId = 'rzp_test_ACTUAL_KEY_ID';
static const String razorpayKeySecret = 'ACTUAL_SECRET';
```

### 2. Deploy Edge Function
1. Go to Supabase Dashboard → Edge Functions
2. Create function: `create-razorpay-order`
3. Copy code from `supabase/functions/create-razorpay-order/index.ts`
4. Deploy

### 3. Set Environment Variables
In Supabase Dashboard → Settings → Edge Functions:
```
RAZORPAY_KEY_ID=rzp_test_ACTUAL_KEY_ID
RAZORPAY_KEY_SECRET=ACTUAL_SECRET
```

### 4. Test Cards
- **Visa**: 4111 1111 1111 1111
- **Mastercard**: 5555 5555 5555 4444
- **Expiry**: Any future date
- **CVV**: Any 3 digits
- **OTP**: 123456

## Test Flow
1. Add items to cart
2. Checkout → Online Payment
3. Click "Pay Now"
4. Use test card details
5. Complete payment

## Common Test Scenarios
- ✅ Successful payment
- ❌ Failed payment (wrong OTP)
- 🔄 Cancelled payment
- 📱 UPI payment
- 💳 Card payment
- 🏦 Net banking

## If Something Doesn't Work
1. Check Flutter console for errors
2. Verify Edge Function is deployed
3. Check Razorpay dashboard for test transactions
4. Ensure API keys are correct
