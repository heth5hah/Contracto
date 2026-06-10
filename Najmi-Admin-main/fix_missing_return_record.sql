-- =============================================================================
-- ONE-TIME FIX: Ensure mobile app can create returns (RLS policies)
-- After this, you NEVER need to run SQL for returns again.
-- =============================================================================

-- Fix returns table policies
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'returns' AND policyname = 'Users can insert returns') THEN
    DROP POLICY "Users can insert returns" ON public.returns;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'returns' AND policyname = 'Users can view own returns') THEN
    DROP POLICY "Users can view own returns" ON public.returns;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'returns' AND policyname = 'Users can update own returns') THEN
    DROP POLICY "Users can update own returns" ON public.returns;
  END IF;
END $$;

-- Users can INSERT returns for their own orders
CREATE POLICY "Users can insert returns" ON public.returns
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() OR EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'));

-- Users can SELECT their own returns, admin sees all
CREATE POLICY "Users can view own returns" ON public.returns
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'));

-- Users can UPDATE their own returns, admin can update all
CREATE POLICY "Users can update own returns" ON public.returns
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid() OR EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'));

-- Fix return_items table policies
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'return_items' AND policyname = 'Users can insert return items') THEN
    DROP POLICY "Users can insert return items" ON public.return_items;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'return_items' AND policyname = 'Users can view return items') THEN
    DROP POLICY "Users can view return items" ON public.return_items;
  END IF;
END $$;

CREATE POLICY "Users can insert return items" ON public.return_items
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.returns r WHERE r.id = return_id
    AND (r.user_id = auth.uid() OR EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'))
  ));

CREATE POLICY "Users can view return items" ON public.return_items
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.returns r WHERE r.id = return_id
    AND (r.user_id = auth.uid() OR EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'))
  ));

-- Fix return_bank_details table policies
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'return_bank_details' AND policyname = 'Users can manage return bank details') THEN
    DROP POLICY "Users can manage return bank details" ON public.return_bank_details;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'return_bank_details' AND policyname = 'Users can view return bank details') THEN
    DROP POLICY "Users can view return bank details" ON public.return_bank_details;
  END IF;
END $$;

CREATE POLICY "Users can manage return bank details" ON public.return_bank_details
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.returns r WHERE r.id = return_id
    AND (r.user_id = auth.uid() OR EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'))
  ));

-- Enable RLS
ALTER TABLE public.returns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.return_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.return_bank_details ENABLE ROW LEVEL SECURITY;

-- Verify
SELECT tablename, policyname, cmd FROM pg_policies 
WHERE tablename IN ('returns', 'return_items', 'return_bank_details')
ORDER BY tablename, cmd;
