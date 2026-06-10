# Orders Table Setup

## Problem
The app was getting a 404 error when trying to submit orders because the `orders` table didn't exist in the database.

## Solution
Run the `create_orders_table_complete.sql` script in your Supabase database to create the necessary tables.

## Steps to Fix

### 1. Run the Database Migration
Execute the following SQL script in your Supabase SQL Editor:

```sql
-- Copy and paste the contents of create_orders_table_complete.sql
```

### 2. What the Script Creates

The script creates:
- **`orders` table**: Main table for storing order information
- **`order_items` table**: Optional table for storing individual order items (for better normalization)
- **Indexes**: For better query performance
- **RLS policies**: Row Level Security policies for user data protection
- **Triggers**: Automatic timestamp updates

### 3. Table Structure

The `orders` table includes:
- Customer information (name, email, phone, address)
- Payment details (method, status)
- Order details (status, notes, GST info)
- Financial information (subtotal, GST amount, delivery charge, total)
- Items as JSON array
- Timestamps

### 4. After Running the Script

Once the tables are created:
1. The checkout process should work without errors
2. Orders will be stored in the database
3. Users can view their order history
4. Cash on Delivery orders will be processed successfully

### 5. Testing

To test if it's working:
1. Add items to cart
2. Go to checkout
3. Fill in customer details
4. Select "Cash on Delivery"
5. Place order

The order should be created successfully without the 404 error.

## Notes

- Online payments are temporarily disabled (showing "Coming Soon")
- The app currently supports Cash on Delivery only
- GST calculation is automatic (18% if GST number is provided)
- Delivery charge is fixed at ₹50
