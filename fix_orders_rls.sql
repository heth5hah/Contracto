-- Fix RLS policies for Admin Panel to access orders table
-- Run this in your Supabase SQL Editor

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Admin can view all orders" ON orders;
DROP POLICY IF EXISTS "Admin can update orders" ON orders;
DROP POLICY IF EXISTS "Users can create orders" ON orders;
DROP POLICY IF EXISTS "Users can view own orders" ON orders;

-- Enable RLS on orders table
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- ADMIN POLICIES (for service_role key used by Admin Panel)
CREATE POLICY "Admin can view all orders"
ON orders
FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Admin can update orders"
ON orders
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- USER POLICIES (for anon key used by Mobile App)
CREATE POLICY "Users can create orders"
ON orders
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own orders"
ON orders
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);
