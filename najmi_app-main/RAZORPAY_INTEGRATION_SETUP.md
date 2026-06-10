# Razorpay Integration Setup Guide

## Overview
This guide explains how to set up Razorpay payment gateway integration in your Najmi app.

## Prerequisites
1. Razorpay account (https://razorpay.com)
2. Supabase project with Edge Functions enabled
3. Flutter app with `razorpay_flutter` dependency

## Step 1: Get Razorpay API Keys

### 1.1 Create Razorpay Account
1. Go to [Razorpay Dashboard](https://dashboard.razorpay.com)
2. Sign up or log in to your account
3. Complete KYC verification if required

### 1.2 Get API Keys
1. In your Razorpay dashboard, go to **Settings** → **API Keys**
2. Generate a new key pair
3. Copy the **Key ID** and **Key Secret**
4. **Important**: Use test keys for development, live keys for production

## Step 2: Configure Supabase Edge Function

### 2.1 Deploy Edge Function
1. In your Supabase dashboard, go to **Edge Functions**
2. Create a new function called `create-razorpay-order`
3. Copy the code from `supabase/functions/create-razorpay-order/index.ts`
4. Deploy the function

### 2.2 Set Environment Variables
1. In your Supabase dashboard, go to **Settings** → **Edge Functions**
2. Add these environment variables:
   ```
   RAZORPAY_KEY_ID=rzp_test_YOUR_TEST_KEY_ID
   RAZORPAY_KEY_SECRET=YOUR_TEST_SECRET
   ```

## Step 3: Update Flutter App Configuration

### 3.1 Update Payment Config
1. Open `lib/core/config/payment_config.dart`
2. Replace the placeholder values with your actual Razorpay keys:
   ```dart
   static const String razorpayKeyId = 'rzp_test_ACTUAL_KEY_ID';
   static const String razorpayKeySecret = 'ACTUAL_SECRET';
   ```

### 3.2 Test vs Production Keys
- **Development**: Use test keys (`rzp_test_...`)
- **Production**: Use live keys (`rzp_live_...`)
- Change `isTestMode` to `false` for production

## Step 4: Test the Integration

### 4.1 Test Payment Flow
1. Add items to cart
2. Go to checkout
3. Select "Online Payment"
4. Click "Pay Now"
5. Complete test payment using Razorpay test cards

### 4.2 Test Cards
Use these test card numbers:
- **Visa**: 4111 1111 1111 1111
- **Mastercard**: 5555 5555 5555 4444
- **Expiry**: Any future date
- **CVV**: Any 3 digits
- **OTP**: 123456

## Step 5: Handle Payment Responses

### 5.1 Success Response
- Payment ID is captured
- Order is created in database
- User is redirected to success screen

### 5.2 Failure Response
- Error message is displayed
- User can retry payment
- No order is created

### 5.3 External Wallet
- UPI apps, wallets, etc.
- Payment flow continues normally

## Step 6: Production Deployment

### 6.1 Update Keys
1. Change `isTestMode` to `false`
2. Update to live Razorpay keys
3. Update Supabase environment variables

### 6.2 Security Considerations
- Never commit API keys to version control
- Use environment variables
- Enable webhook verification
- Implement proper error handling

## Troubleshooting

### Common Issues

#### 1. "Payment Failed" Error
- Check Razorpay API keys
- Verify Edge Function is deployed
- Check network connectivity

#### 2. "Order Creation Failed"
- Verify orders table exists
- Check RLS policies
- Verify user authentication

#### 3. Payment Gateway Not Loading
- Check Razorpay key format
- Verify app permissions
- Check device compatibility

### Debug Steps
1. Check Flutter console for errors
2. Verify Supabase Edge Function logs
3. Test with Razorpay test dashboard
4. Check network requests in browser dev tools

## API Reference

### Cart Service Methods
- `processOnlinePayment()`: Initiates Razorpay payment
- `createOrderAfterPayment()`: Creates order after successful payment

### Razorpay Service Methods
- `initialize()`: Sets up payment callbacks
- `createPaymentOrder()`: Creates payment order on backend
- `startPayment()`: Opens Razorpay payment UI

### Payment Result
```dart
class PaymentResult {
  final bool success;
  final String message;
  final String? paymentId;
  final String? orderId;
  final String? errorCode;
  final String? errorDescription;
}
```

## Support

### Razorpay Support
- [Documentation](https://razorpay.com/docs/)
- [Support Portal](https://razorpay.com/support/)
- [API Reference](https://razorpay.com/docs/api/)

### App Support
- Check Flutter logs
- Verify Supabase configuration
- Test with minimal setup first

## Security Best Practices

1. **Never expose API secrets** in client-side code
2. **Use HTTPS** for all API calls
3. **Verify payment signatures** on backend
4. **Implement proper error handling**
5. **Log payment events** for audit trail
6. **Use webhooks** for payment status updates
7. **Implement retry logic** for failed payments
8. **Validate all input data** before processing

## Next Steps

After successful integration:
1. Add payment analytics
2. Implement webhook handling
3. Add payment retry logic
4. Implement refund functionality
5. Add payment history
6. Implement subscription payments (if needed)
