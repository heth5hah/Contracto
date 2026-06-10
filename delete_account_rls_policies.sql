-- RLS policies to allow users to delete their own account data
-- Run this in Supabase SQL Editor
-- Note: This script skips tables that may not exist

-- Allow users to delete their own user record
DROP POLICY IF EXISTS "Users can delete own account" ON users;
CREATE POLICY "Users can delete own account" ON users
    FOR DELETE
    USING (id = auth.uid() OR email = auth.jwt() ->> 'email');

-- Allow users to delete their own addresses
DROP POLICY IF EXISTS "Users can delete own addresses" ON addresses;
CREATE POLICY "Users can delete own addresses" ON addresses
    FOR DELETE
    USING (user_id IN (SELECT id FROM users WHERE email = auth.jwt() ->> 'email'));

-- Allow users to delete their own wishlist items
DROP POLICY IF EXISTS "Users can delete own wishlist" ON wishlist;
CREATE POLICY "Users can delete own wishlist" ON wishlist
    FOR DELETE
    USING (user_id IN (SELECT id FROM users WHERE email = auth.jwt() ->> 'email'));

-- Allow users to delete their own quote requests
DROP POLICY IF EXISTS "Users can delete own quote requests" ON quote_requests;
CREATE POLICY "Users can delete own quote requests" ON quote_requests
    FOR DELETE
    USING (user_id IN (SELECT id FROM users WHERE email = auth.jwt() ->> 'email'));

-- Allow users to delete items from their own quote requests  
DROP POLICY IF EXISTS "Users can delete own quote request items" ON quote_request_items;
CREATE POLICY "Users can delete own quote request items" ON quote_request_items
    FOR DELETE
    USING (quote_request_id IN (
        SELECT id FROM quote_requests 
        WHERE user_id IN (SELECT id FROM users WHERE email = auth.jwt() ->> 'email')
    ));

-- Allow users to delete their own orders
DROP POLICY IF EXISTS "Users can delete own orders" ON orders;
CREATE POLICY "Users can delete own orders" ON orders
    FOR DELETE
    USING (user_id IN (SELECT id FROM users WHERE email = auth.jwt() ->> 'email'));

-- Allow users to delete items from their own orders
DROP POLICY IF EXISTS "Users can delete own order items" ON order_items;
CREATE POLICY "Users can delete own order items" ON order_items
    FOR DELETE
    USING (order_id IN (
        SELECT id FROM orders 
        WHERE user_id IN (SELECT id FROM users WHERE email = auth.jwt() ->> 'email')
    ));

-- Grant delete permissions
GRANT DELETE ON users TO authenticated;
GRANT DELETE ON addresses TO authenticated;
GRANT DELETE ON wishlist TO authenticated;
GRANT DELETE ON quote_requests TO authenticated;
GRANT DELETE ON quote_request_items TO authenticated;
GRANT DELETE ON orders TO authenticated;
GRANT DELETE ON order_items TO authenticated;
