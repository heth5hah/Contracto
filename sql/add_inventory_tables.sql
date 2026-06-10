-- Inventory tables and helper RPC for inventory management
-- Supports product variations (quality options like 1L, 5L, etc.)

-- 1. Inventory table (Updated with quality_option)
CREATE TABLE IF NOT EXISTS public.inventory (
  product_id text NOT NULL,
  quality_option text NOT NULL DEFAULT '',
  current_stock integer NOT NULL DEFAULT 0,
  low_stock_threshold integer NOT NULL DEFAULT 5,
  last_updated timestamptz DEFAULT now(),
  PRIMARY KEY (product_id, quality_option)
);

-- 2. Inventory logs (Updated with quality_option)
CREATE TABLE IF NOT EXISTS public.inventory_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id text NOT NULL,
  quality_option text NOT NULL DEFAULT '',
  change_type text NOT NULL CHECK (change_type IN ('add','reduce')),
  quantity integer NOT NULL,
  reason text,
  updated_by uuid,
  source_ref text,
  created_at timestamptz DEFAULT now()
);

-- 3. Indexes
CREATE INDEX IF NOT EXISTS idx_inventory_low_stock ON public.inventory(low_stock_threshold, current_stock);
CREATE INDEX IF NOT EXISTS idx_inventory_logs_product_id ON public.inventory_logs(product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_logs_composite ON public.inventory_logs(product_id, quality_option);

-- 4. Helper RPC: adjust_inventory (Variation-aware)
-- Drops older versions first
DROP FUNCTION IF EXISTS public.adjust_inventory(text, integer, text, text, uuid, text);
DROP FUNCTION IF EXISTS public.adjust_inventory(text, integer, text, text, text, text);
DROP FUNCTION IF EXISTS public.adjust_inventory(text, text, integer, text, text, text);

CREATE OR REPLACE FUNCTION public.adjust_inventory(
  p_product_id text,
  p_quality_option text,
  p_delta integer,
  p_change_type text,
  p_reason text,
  p_admin text,
  p_source text DEFAULT NULL
)
RETURNS TABLE(out_product_id text, out_quality_option text, out_previous_stock integer, out_new_stock integer) AS $$
DECLARE
  v_prev integer;
  v_admin_uuid uuid;
BEGIN
  -- Convert text ID to uuid if possible for foreign key compatibility
  BEGIN
    IF p_admin IS NOT NULL AND p_admin <> '' THEN
      v_admin_uuid := p_admin::uuid;
    ELSE
      v_admin_uuid := NULL;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_admin_uuid := NULL;
  END;

  -- Ensure inventory row exists for this specific variation
  INSERT INTO public.inventory(product_id, quality_option, current_stock, last_updated)
  VALUES (p_product_id, COALESCE(p_quality_option, ''), 0, now())
  ON CONFLICT (product_id, quality_option) DO NOTHING;

  -- Get previous stock with lock
  SELECT COALESCE(current_stock, 0) INTO v_prev FROM public.inventory 
  WHERE product_id = p_product_id AND quality_option = COALESCE(p_quality_option, '') 
  FOR UPDATE;

  -- Update stock
  UPDATE public.inventory
  SET current_stock = GREATEST(0, (COALESCE(current_stock, 0) + p_delta)),
      last_updated = now()
  WHERE product_id = p_product_id AND quality_option = COALESCE(p_quality_option, '')
  RETURNING product_id, quality_option, v_prev, current_stock 
  INTO out_product_id, out_quality_option, out_previous_stock, out_new_stock;

  -- Log the change
  INSERT INTO public.inventory_logs(product_id, quality_option, change_type, quantity, reason, updated_by, source_ref)
  VALUES (p_product_id, COALESCE(p_quality_option, ''), p_change_type, ABS(p_delta), p_reason, v_admin_uuid, p_source);

  RETURN NEXT;
END;
$$ LANGUAGE plpgsql;

-- 5. RLS / policies
ALTER TABLE public.inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_logs ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'inventory' AND policyname = 'Allow authenticated read') THEN
    CREATE POLICY "Allow authenticated read" ON public.inventory FOR SELECT USING (auth.uid() IS NOT NULL);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'inventory' AND policyname = 'Admins can modify inventory') THEN
    CREATE POLICY "Admins can modify inventory" ON public.inventory FOR ALL USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'inventory_logs' AND policyname = 'Allow authenticated logs') THEN
    CREATE POLICY "Allow authenticated logs" ON public.inventory_logs FOR ALL USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);
  END IF;
END $$;


-- Migration complete
