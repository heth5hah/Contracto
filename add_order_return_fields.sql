-- Add return-related fields to orders table
-- This allows orders to be marked as having returns without changing order_status

-- 1. Add has_return boolean column
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS has_return boolean DEFAULT false;

-- 2. Add return_status column (separate from order_status)
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS return_status text;

-- 3. Add return_requested_at timestamp
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS return_requested_at timestamp with time zone;

-- 4. Create index for faster queries on has_return
CREATE INDEX IF NOT EXISTS idx_orders_has_return ON public.orders(has_return) WHERE has_return = true;

-- 5. Create index for return_status
CREATE INDEX IF NOT EXISTS idx_orders_return_status ON public.orders(return_status) WHERE return_status IS NOT NULL;

-- 6. Create function to automatically update order when return is created
CREATE OR REPLACE FUNCTION update_order_on_return_create()
RETURNS TRIGGER AS $$
BEGIN
    -- Update the order when a return is created
    UPDATE public.orders
    SET 
        has_return = true,
        return_status = CASE 
            WHEN NEW.return_status = 'pending' THEN 'Pending Review'
            WHEN NEW.return_status = 'approved' THEN 'Approved'
            WHEN NEW.return_status = 'rejected' THEN 'Rejected'
            WHEN NEW.return_status = 'completed' THEN 'Completed'
            ELSE 'Pending Review'
        END,
        return_requested_at = NEW.created_at,
        updated_at = now()
    WHERE id = NEW.order_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 7. Create trigger to update order when return is created
DROP TRIGGER IF EXISTS trigger_update_order_on_return_create ON public.returns;
CREATE TRIGGER trigger_update_order_on_return_create
    AFTER INSERT ON public.returns
    FOR EACH ROW
    EXECUTE FUNCTION update_order_on_return_create();

-- 8. Create function to update order when return status changes
CREATE OR REPLACE FUNCTION update_order_on_return_status_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Update the order when return status changes
    UPDATE public.orders
    SET 
        return_status = CASE 
            WHEN NEW.return_status = 'pending' THEN 'Pending Review'
            WHEN NEW.return_status = 'approved' THEN 'Approved'
            WHEN NEW.return_status = 'rejected' THEN 'Rejected'
            WHEN NEW.return_status = 'completed' THEN 'Completed'
            WHEN NEW.return_status = 'cancelled' THEN NULL
            ELSE return_status
        END,
        updated_at = now()
    WHERE id = NEW.order_id;
    
    -- If return is cancelled, check if there are other pending returns
    IF NEW.return_status = 'cancelled' THEN
        -- Check if there are other non-cancelled returns for this order
        IF NOT EXISTS (
            SELECT 1 FROM public.returns 
            WHERE order_id = NEW.order_id 
            AND return_status != 'cancelled'
        ) THEN
            -- No other returns, clear the return flags
            UPDATE public.orders
            SET 
                has_return = false,
                return_status = NULL,
                return_requested_at = NULL,
                updated_at = now()
            WHERE id = NEW.order_id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 9. Create trigger to update order when return status changes
DROP TRIGGER IF EXISTS trigger_update_order_on_return_status_change ON public.returns;
CREATE TRIGGER trigger_update_order_on_return_status_change
    AFTER UPDATE ON public.returns
    FOR EACH ROW
    WHEN (OLD.return_status IS DISTINCT FROM NEW.return_status)
    EXECUTE FUNCTION update_order_on_return_status_change();

-- Verification query (optional - run to verify)
-- SELECT column_name, data_type, column_default 
-- FROM information_schema.columns 
-- WHERE table_name = 'orders' 
-- AND column_name IN ('has_return', 'return_status', 'return_requested_at');




