-- Create wishlist table for storing user's saved products
-- Run this in Supabase SQL Editor

CREATE TABLE IF NOT EXISTS wishlist (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, product_id)
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_wishlist_user_id ON wishlist(user_id);
CREATE INDEX IF NOT EXISTS idx_wishlist_product_id ON wishlist(product_id);

-- Enable Row Level Security
ALTER TABLE wishlist ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own wishlist items
CREATE POLICY "Users can view own wishlist" ON wishlist
    FOR SELECT
    USING (
        user_id IN (
            SELECT id FROM users WHERE email = auth.jwt() ->> 'email'
        )
    );

-- Policy: Users can insert into their own wishlist
CREATE POLICY "Users can add to own wishlist" ON wishlist
    FOR INSERT
    WITH CHECK (
        user_id IN (
            SELECT id FROM users WHERE email = auth.jwt() ->> 'email'
        )
    );

-- Policy: Users can delete from their own wishlist
CREATE POLICY "Users can remove from own wishlist" ON wishlist
    FOR DELETE
    USING (
        user_id IN (
            SELECT id FROM users WHERE email = auth.jwt() ->> 'email'
        )
    );

-- Grant permissions
GRANT SELECT, INSERT, DELETE ON wishlist TO authenticated;
GRANT SELECT, INSERT, DELETE ON wishlist TO anon;
