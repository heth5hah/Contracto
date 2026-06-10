CREATE TABLE IF NOT EXISTS public.app_error_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    action VARCHAR(255) NOT NULL,
    error_message TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.app_error_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable insert for all" ON public.app_error_logs FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable select for admins" ON public.app_error_logs FOR SELECT USING (true);
