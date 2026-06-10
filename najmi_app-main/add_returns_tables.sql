-- Add returns and return_items tables for order return functionality
-- Run this migration on Supabase SQL Editor

-- 1. Add delivered_at column to orders table
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS delivered_at timestamp with time zone;

-- 2. Create returns table
CREATE TABLE IF NOT EXISTS public.returns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id),
  return_status text DEFAULT 'pending' CHECK (return_status IN ('pending', 'approved', 'rejected', 'completed', 'cancelled')),
  return_reason text,
  notes text,
  refund_amount numeric DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- 3. Create return_items table
CREATE TABLE IF NOT EXISTS public.return_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  return_id uuid NOT NULL REFERENCES public.returns(id) ON DELETE CASCADE,
  product_id text NOT NULL,
  product_name text NOT NULL,
  quantity integer NOT NULL CHECK (quantity > 0),
  unit_price numeric NOT NULL,
  total_price numeric NOT NULL,
  quality_option_name text,
  unit text,
  created_at timestamp with time zone DEFAULT now()
);

-- 4. Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_returns_order_id ON public.returns(order_id);
CREATE INDEX IF NOT EXISTS idx_returns_user_id ON public.returns(user_id);
CREATE INDEX IF NOT EXISTS idx_returns_status ON public.returns(return_status);
CREATE INDEX IF NOT EXISTS idx_return_items_return_id ON public.return_items(return_id);

-- 5. Enable Row Level Security
ALTER TABLE public.returns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.return_items ENABLE ROW LEVEL SECURITY;

-- 6. Create RLS policies for returns
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'returns' AND policyname = 'Users can view their own returns') THEN
        CREATE POLICY "Users can view their own returns" ON public.returns
            FOR SELECT USING (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'returns' AND policyname = 'Users can create their own returns') THEN
        CREATE POLICY "Users can create their own returns" ON public.returns
            FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'returns' AND policyname = 'Users can update their own pending returns') THEN
        CREATE POLICY "Users can update their own pending returns" ON public.returns
            FOR UPDATE USING (auth.uid() = user_id AND return_status = 'pending');
    END IF;
END $$;

-- 7. Create RLS policies for return_items
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'return_items' AND policyname = 'Users can view their return items') THEN
        CREATE POLICY "Users can view their return items" ON public.return_items
            FOR SELECT USING (
                EXISTS (
                    SELECT 1 FROM public.returns 
                    WHERE returns.id = return_items.return_id 
                    AND returns.user_id = auth.uid()
                )
            );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'return_items' AND policyname = 'Users can create return items') THEN
        CREATE POLICY "Users can create return items" ON public.return_items
            FOR INSERT WITH CHECK (
                EXISTS (
                    SELECT 1 FROM public.returns 
                    WHERE returns.id = return_items.return_id 
                    AND returns.user_id = auth.uid()
                )
            );
    END IF;
END $$;

-- 8. Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_returns_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 9. Create trigger for updated_at
DROP TRIGGER IF EXISTS returns_updated_at_trigger ON public.returns;
CREATE TRIGGER returns_updated_at_trigger
    BEFORE UPDATE ON public.returns
    FOR EACH ROW
    EXECUTE FUNCTION update_returns_updated_at();

-- Verification queries (optional - run these to verify)
-- SELECT * FROM public.returns LIMIT 1;
-- SELECT * FROM public.return_items LIMIT 1;
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'delivered_at';
