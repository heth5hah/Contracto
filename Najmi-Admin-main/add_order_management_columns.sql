-- Add Order Management Columns to Quotes Table
-- This migration adds columns needed for order status tracking

-- Add order_status column for tracking order lifecycle
ALTER TABLE quotes 
ADD COLUMN IF NOT EXISTS order_status VARCHAR(20) DEFAULT 'pending' 
CHECK (order_status IN ('pending', 'in_transport', 'delivered', 'returned'));

-- Add status_notes column for tracking status change notes
ALTER TABLE quotes 
ADD COLUMN IF NOT EXISTS status_notes TEXT;

-- Add updated_at column for tracking last status update
ALTER TABLE quotes 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Add comment to explain the order_status values
COMMENT ON COLUMN quotes.order_status IS 'Order status: pending, in_transport, delivered, returned';

COMMENT ON COLUMN quotes.status_notes IS 'Notes about status changes or order updates';

COMMENT ON COLUMN quotes.updated_at IS 'Timestamp of last status update';

-- Create index on order_status for faster filtering
CREATE INDEX IF NOT EXISTS idx_quotes_order_status ON quotes(order_status);

-- Create index on updated_at for sorting
CREATE INDEX IF NOT EXISTS idx_quotes_updated_at ON quotes(updated_at);

-- Update existing quotes to have default order_status
UPDATE quotes 
SET order_status = 'pending' 
WHERE order_status IS NULL;

-- Add trigger to automatically update updated_at column
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger if it doesn't exist
DROP TRIGGER IF EXISTS update_quotes_updated_at ON quotes;
CREATE TRIGGER update_quotes_updated_at
    BEFORE UPDATE ON quotes
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Grant necessary permissions (adjust as needed for your RLS setup)
-- These policies should already exist from previous migrations
-- If not, you may need to add them manually in Supabase dashboard
