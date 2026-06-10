-- Fix RLS policies for Admin Panel to access quote_requests table
-- Run this in your Supabase SQL Editor
-- This version drops existing policies first to avoid conflicts

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Admin can view all quote requests" ON quote_requests;
DROP POLICY IF EXISTS "Admin can update quote requests" ON quote_requests;
DROP POLICY IF EXISTS "Admin can view all quote request items" ON quote_request_items;
DROP POLICY IF EXISTS "Admin can update quote request items" ON quote_request_items;
DROP POLICY IF EXISTS "Users can create quote requests" ON quote_requests;
DROP POLICY IF EXISTS "Users can view own quote requests" ON quote_requests;
DROP POLICY IF EXISTS "Users can create quote request items" ON quote_request_items;
DROP POLICY IF EXISTS "Users can view own quote request items" ON quote_request_items;

-- Enable RLS on tables
ALTER TABLE quote_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE quote_request_items ENABLE ROW LEVEL SECURITY;

-- ADMIN POLICIES (for service_role key used by Admin Panel)
-- These use 'true' to allow all access for authenticated admin users

CREATE POLICY "Admin can view all quote requests"
ON quote_requests
FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Admin can update quote requests"
ON quote_requests
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Admin can view all quote request items"
ON quote_request_items
FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Admin can update quote request items"
ON quote_request_items
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- USER POLICIES (for anon key used by Mobile App)
-- These restrict users to only see their own data

CREATE POLICY "Users can create quote requests"
ON quote_requests
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own quote requests"
ON quote_requests
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Users can create quote request items"
ON quote_request_items
FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "Users can view own quote request items"
ON quote_request_items
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM quote_requests
    WHERE quote_requests.id = quote_request_items.quote_request_id
    AND quote_requests.user_id = auth.uid()
  )
);
