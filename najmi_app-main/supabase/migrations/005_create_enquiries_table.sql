-- Migration: Create enquiries table
-- Description: Creates table for product enquiries when products are not found

-- Create enquiries table
CREATE TABLE IF NOT EXISTS enquiries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  product_name TEXT NOT NULL,
  category TEXT,
  message TEXT NOT NULL,
  contact_email TEXT,
  contact_phone TEXT,
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'contacted', 'resolved', 'closed')),
  admin_notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_enquiries_user ON enquiries(user_id);
CREATE INDEX IF NOT EXISTS idx_enquiries_status ON enquiries(status);
CREATE INDEX IF NOT EXISTS idx_enquiries_created ON enquiries(created_at DESC);

-- Add RLS policies
ALTER TABLE enquiries ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own enquiries
CREATE POLICY "Users can read own enquiries"
  ON enquiries FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Users can create enquiries
CREATE POLICY "Users can create enquiries"
  ON enquiries FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: Admins can read all enquiries
CREATE POLICY "Admins can read all enquiries"
  ON enquiries FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role = 'admin'
    )
  );

-- Policy: Admins can update enquiries
CREATE POLICY "Admins can update enquiries"
  ON enquiries FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role = 'admin'
    )
  );

-- Add trigger for updated_at
CREATE OR REPLACE FUNCTION update_enquiries_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER enquiries_updated_at
  BEFORE UPDATE ON enquiries
  FOR EACH ROW
  EXECUTE FUNCTION update_enquiries_updated_at();

-- Add comments
COMMENT ON TABLE enquiries IS 'Product enquiries submitted by users when products are not found';
COMMENT ON COLUMN enquiries.status IS 'Status of enquiry: pending, contacted, resolved, or closed';
COMMENT ON COLUMN enquiries.admin_notes IS 'Internal notes by admin for tracking';
