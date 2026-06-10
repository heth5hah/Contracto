-- Comprehensive Notification System (Safe Migration)
-- Handles existing tables and adds missing columns

-- ====================================================
-- 1. CREATE NOTIFICATIONS TABLE (if not exists)
-- ====================================================
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source text NOT NULL CHECK (source IN ('admin', 'app', 'system')),
  target text NOT NULL CHECK (target IN ('admin', 'user')),
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  message text NOT NULL,
  type text NOT NULL CHECK (type IN ('order', 'quotation', 'return', 'refund', 'payment', 'system', 'other')),
  reference_id uuid, -- order_id, quotation_id, return_id, etc.
  is_read boolean DEFAULT false,
  sound_played boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  metadata jsonb -- Additional data like order details, amounts, etc.
);

-- ====================================================
-- 2. ADD MISSING COLUMNS (if table already exists)
-- ====================================================
DO $$
BEGIN
    -- Add source column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' AND column_name = 'source'
    ) THEN
        ALTER TABLE public.notifications ADD COLUMN source text;
        ALTER TABLE public.notifications ADD CONSTRAINT notifications_source_check 
            CHECK (source IN ('admin', 'app', 'system'));
        UPDATE public.notifications SET source = 'system' WHERE source IS NULL;
        ALTER TABLE public.notifications ALTER COLUMN source SET NOT NULL;
        RAISE NOTICE 'Added source column';
    END IF;

    -- Add target column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' AND column_name = 'target'
    ) THEN
        ALTER TABLE public.notifications ADD COLUMN target text;
        ALTER TABLE public.notifications ADD CONSTRAINT notifications_target_check 
            CHECK (target IN ('admin', 'user'));
        -- Set default based on existing data (if any)
        UPDATE public.notifications SET target = 'user' WHERE target IS NULL;
        ALTER TABLE public.notifications ALTER COLUMN target SET NOT NULL;
        RAISE NOTICE 'Added target column';
    END IF;

    -- Add user_id column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' AND column_name = 'user_id'
    ) THEN
        ALTER TABLE public.notifications ADD COLUMN user_id uuid REFERENCES public.users(id) ON DELETE CASCADE;
        RAISE NOTICE 'Added user_id column';
    END IF;

    -- Add type column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' AND column_name = 'type'
    ) THEN
        ALTER TABLE public.notifications ADD COLUMN type text;
        ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check 
            CHECK (type IN ('order', 'quotation', 'return', 'refund', 'payment', 'system', 'other'));
        UPDATE public.notifications SET type = 'other' WHERE type IS NULL;
        ALTER TABLE public.notifications ALTER COLUMN type SET NOT NULL;
        RAISE NOTICE 'Added type column';
    END IF;

    -- Add reference_id column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' AND column_name = 'reference_id'
    ) THEN
        ALTER TABLE public.notifications ADD COLUMN reference_id uuid;
        RAISE NOTICE 'Added reference_id column';
    END IF;

    -- Add is_read column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' AND column_name = 'is_read'
    ) THEN
        ALTER TABLE public.notifications ADD COLUMN is_read boolean DEFAULT false;
        RAISE NOTICE 'Added is_read column';
    END IF;

    -- Add sound_played column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' AND column_name = 'sound_played'
    ) THEN
        ALTER TABLE public.notifications ADD COLUMN sound_played boolean DEFAULT false;
        RAISE NOTICE 'Added sound_played column';
    END IF;

    -- Add metadata column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' AND column_name = 'metadata'
    ) THEN
        ALTER TABLE public.notifications ADD COLUMN metadata jsonb;
        RAISE NOTICE 'Added metadata column';
    END IF;

    -- Ensure title and message exist (they should, but just in case)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' AND column_name = 'title'
    ) THEN
        ALTER TABLE public.notifications ADD COLUMN title text NOT NULL DEFAULT '';
        RAISE NOTICE 'Added title column';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' AND column_name = 'message'
    ) THEN
        ALTER TABLE public.notifications ADD COLUMN message text NOT NULL DEFAULT '';
        RAISE NOTICE 'Added message column';
    END IF;

    -- Ensure created_at and updated_at exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' AND column_name = 'created_at'
    ) THEN
        ALTER TABLE public.notifications ADD COLUMN created_at timestamp with time zone DEFAULT now();
        RAISE NOTICE 'Added created_at column';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE public.notifications ADD COLUMN updated_at timestamp with time zone DEFAULT now();
        RAISE NOTICE 'Added updated_at column';
    END IF;
END $$;

-- ====================================================
-- 3. CREATE INDEXES
-- ====================================================
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_notifications_target ON public.notifications(target);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON public.notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON public.notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON public.notifications(target, is_read) WHERE is_read = false;

-- ====================================================
-- 4. ENABLE RLS
-- ====================================================
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- ====================================================
-- 5. DROP EXISTING POLICIES (to recreate them)
-- ====================================================
DROP POLICY IF EXISTS "Admins can view all notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can view their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "System can create notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Admins can update all notifications" ON public.notifications;

-- ====================================================
-- 6. CREATE RLS POLICIES
-- ====================================================
-- Admins can see all notifications
CREATE POLICY "Admins can view all notifications" ON public.notifications
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users 
      WHERE users.id = auth.uid() 
      AND users.role IN ('admin', 'ops')
    )
    OR target = 'admin'
  );

-- Users can see only their own notifications
CREATE POLICY "Users can view their own notifications" ON public.notifications
  FOR SELECT
  TO authenticated
  USING (
    target = 'user' AND user_id = auth.uid()
  );

-- System can insert notifications (via service role or triggers)
CREATE POLICY "System can create notifications" ON public.notifications
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Users can update their own notifications (mark as read)
CREATE POLICY "Users can update their own notifications" ON public.notifications
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid() OR target = 'admin')
  WITH CHECK (user_id = auth.uid() OR target = 'admin');

-- Admins can update all notifications
CREATE POLICY "Admins can update all notifications" ON public.notifications
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users 
      WHERE users.id = auth.uid() 
      AND users.role IN ('admin', 'ops')
    )
  );

-- ====================================================
-- 7. UPDATE TIMESTAMP TRIGGER
-- ====================================================
CREATE OR REPLACE FUNCTION update_notifications_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS notifications_updated_at_trigger ON public.notifications;
CREATE TRIGGER notifications_updated_at_trigger
    BEFORE UPDATE ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION update_notifications_updated_at();

-- ====================================================
-- 8. FUNCTION: CREATE NOTIFICATION
-- ====================================================
CREATE OR REPLACE FUNCTION create_notification(
  p_source text,
  p_target text,
  p_title text,
  p_message text,
  p_type text,
  p_user_id uuid DEFAULT NULL,
  p_reference_id uuid DEFAULT NULL,
  p_metadata jsonb DEFAULT NULL
)
RETURNS uuid AS $$
DECLARE
  v_notification_id uuid;
BEGIN
  INSERT INTO public.notifications (
    source,
    target,
    user_id,
    title,
    message,
    type,
    reference_id,
    metadata
  ) VALUES (
    p_source,
    p_target,
    p_user_id,
    p_title,
    p_message,
    p_type,
    p_reference_id,
    p_metadata
  )
  RETURNING id INTO v_notification_id;
  
  RETURN v_notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ====================================================
-- 9. TRIGGERS FOR AUTOMATIC NOTIFICATIONS
-- ====================================================

-- Trigger: New Order → Notify Admin
CREATE OR REPLACE FUNCTION notify_admin_new_order()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM create_notification(
    'app',
    'admin',
    NULL, -- Admin notifications don't need user_id
    'New Order Received',
    'Order #' || SUBSTRING(NEW.id::text, 1, 8) || ' has been placed by ' || COALESCE(NEW.customer_name, 'Customer'),
    'order',
    NEW.id,
    jsonb_build_object(
      'order_id', NEW.id,
      'customer_name', NEW.customer_name,
      'total_amount', NEW.total_amount,
      'order_status', NEW.order_status
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_notify_admin_new_order ON public.orders;
CREATE TRIGGER trigger_notify_admin_new_order
  AFTER INSERT ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_admin_new_order();

-- Trigger: New Quotation Request → Notify Admin
CREATE OR REPLACE FUNCTION notify_admin_new_quotation()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM create_notification(
    'app',
    'admin',
    NULL,
    'New Quotation Request',
    'Quotation request #' || SUBSTRING(NEW.id::text, 1, 8) || ' received',
    'quotation',
    NEW.id,
    jsonb_build_object(
      'quotation_id', NEW.id,
      'product_name', NEW.product_name,
      'status', NEW.status
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_notify_admin_new_quotation ON public.quote_requests;
CREATE TRIGGER trigger_notify_admin_new_quotation
  AFTER INSERT ON public.quote_requests
  FOR EACH ROW
  EXECUTE FUNCTION notify_admin_new_quotation();

-- Trigger: New Return Request → Notify Admin
CREATE OR REPLACE FUNCTION notify_admin_new_return()
RETURNS TRIGGER AS $$
DECLARE
  v_order_id uuid;
  v_customer_name text;
BEGIN
  v_order_id := NEW.order_id;
  
  -- Get customer name from order
  SELECT customer_name INTO v_customer_name
  FROM public.orders
  WHERE id = v_order_id;
  
  PERFORM create_notification(
    'app',
    'admin',
    NULL,
    'New Return Request',
    'Return request for Order #' || SUBSTRING(v_order_id::text, 1, 8) || COALESCE(' from ' || v_customer_name, ''),
    'return',
    NEW.id,
    jsonb_build_object(
      'return_id', NEW.id,
      'order_id', v_order_id,
      'return_status', NEW.return_status,
      'refund_amount', NEW.refund_amount
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_notify_admin_new_return ON public.returns;
CREATE TRIGGER trigger_notify_admin_new_return
  AFTER INSERT ON public.returns
  FOR EACH ROW
  EXECUTE FUNCTION notify_admin_new_return();

-- Trigger: Order Status Changed → Notify User
CREATE OR REPLACE FUNCTION notify_user_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Only notify on status changes (not initial insert)
  IF OLD.order_status IS DISTINCT FROM NEW.order_status THEN
    PERFORM create_notification(
      'admin',
      'user',
      NEW.user_id,
      CASE NEW.order_status
        WHEN 'confirmed' THEN 'Order Confirmed'
        WHEN 'processing' THEN 'Order Processing'
        WHEN 'shipped' THEN 'Order Shipped'
        WHEN 'out_for_delivery' THEN 'Out for Delivery'
        WHEN 'delivered' THEN 'Order Delivered'
        WHEN 'cancelled' THEN 'Order Cancelled'
        ELSE 'Order Status Updated'
      END,
      CASE NEW.order_status
        WHEN 'confirmed' THEN 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' has been confirmed'
        WHEN 'processing' THEN 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' is being processed'
        WHEN 'shipped' THEN 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' has been shipped'
        WHEN 'out_for_delivery' THEN 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' is out for delivery'
        WHEN 'delivered' THEN 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' has been delivered'
        WHEN 'cancelled' THEN 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' has been cancelled'
        ELSE 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' status has been updated'
      END,
      'order',
      NEW.id,
      jsonb_build_object(
        'order_id', NEW.id,
        'order_status', NEW.order_status,
        'total_amount', NEW.total_amount
      )
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_notify_user_order_status_change ON public.orders;
CREATE TRIGGER trigger_notify_user_order_status_change
  AFTER UPDATE ON public.orders
  FOR EACH ROW
  WHEN (OLD.order_status IS DISTINCT FROM NEW.order_status)
  EXECUTE FUNCTION notify_user_order_status_change();

-- Trigger: Quotation Status Changed → Notify User
CREATE OR REPLACE FUNCTION notify_user_quotation_status_change()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    PERFORM create_notification(
      'admin',
      'user',
      NEW.user_id,
      CASE NEW.status
        WHEN 'approved' THEN 'Quotation Approved'
        WHEN 'rejected' THEN 'Quotation Rejected'
        ELSE 'Quotation Status Updated'
      END,
      CASE NEW.status
        WHEN 'approved' THEN 'Your quotation request has been approved'
        WHEN 'rejected' THEN 'Your quotation request has been rejected'
        ELSE 'Your quotation request status has been updated'
      END,
      'quotation',
      NEW.id,
      jsonb_build_object(
        'quotation_id', NEW.id,
        'status', NEW.status
      )
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_notify_user_quotation_status_change ON public.quote_requests;
CREATE TRIGGER trigger_notify_user_quotation_status_change
  AFTER UPDATE ON public.quote_requests
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION notify_user_quotation_status_change();

-- Trigger: Return Status Changed → Notify User
CREATE OR REPLACE FUNCTION notify_user_return_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_order_id uuid;
BEGIN
  v_order_id := NEW.order_id;
  
  IF OLD.return_status IS DISTINCT FROM NEW.return_status THEN
    PERFORM create_notification(
      'admin',
      'user',
      NEW.user_id,
      CASE NEW.return_status
        WHEN 'approved' THEN 'Return Approved'
        WHEN 'rejected' THEN 'Return Rejected'
        WHEN 'completed' THEN 'Return Completed'
        ELSE 'Return Status Updated'
      END,
      CASE NEW.return_status
        WHEN 'approved' THEN 'Your return request for Order #' || SUBSTRING(v_order_id::text, 1, 8) || ' has been approved'
        WHEN 'rejected' THEN 'Your return request for Order #' || SUBSTRING(v_order_id::text, 1, 8) || ' has been rejected'
        WHEN 'completed' THEN 'Your return for Order #' || SUBSTRING(v_order_id::text, 1, 8) || ' has been completed'
        ELSE 'Your return request status has been updated'
      END,
      'return',
      NEW.id,
      jsonb_build_object(
        'return_id', NEW.id,
        'order_id', v_order_id,
        'return_status', NEW.return_status,
        'refund_amount', NEW.refund_amount
      )
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_notify_user_return_status_change ON public.returns;
CREATE TRIGGER trigger_notify_user_return_status_change
  AFTER UPDATE ON public.returns
  FOR EACH ROW
  WHEN (OLD.return_status IS DISTINCT FROM NEW.return_status)
  EXECUTE FUNCTION notify_user_return_status_change();

-- ====================================================
-- 10. VERIFICATION QUERIES
-- ====================================================
-- Check table structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'notifications'
ORDER BY ordinal_position;

-- Check triggers
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE event_object_table IN ('orders', 'quote_requests', 'returns')
ORDER BY event_object_table, trigger_name;

-- Check RLS policies
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE tablename = 'notifications'
ORDER BY policyname;

