-- Allow public/anon select access for nested quotation tables to match quote_requests
-- This ensures that joins in the admin panel don't return empty lists when using nested queries

-- Allow public read for quote_request_items
CREATE POLICY "Allow public read for quote_request_items" ON public.quote_request_items
    FOR SELECT TO public USING (true);

-- Allow public read for quotes
CREATE POLICY "Allow public read for quotes" ON public.quotes
    FOR SELECT TO public USING (true);

-- Allow public read for quote_items
CREATE POLICY "Allow public read for quote_items" ON public.quote_items
    FOR SELECT TO public USING (true);

-- Note: these are SELECT only, ensuring visibility matches the parent record
