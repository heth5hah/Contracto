-- Advanced script to fix missing images in orders
-- Run this in Supabase SQL Editor

DO $$ 
DECLARE
    order_record RECORD;
    item_element jsonb;
    new_items jsonb;
    prod_photo text;
    prod_id text;
BEGIN
    FOR order_record IN SELECT id, items FROM public.orders WHERE items IS NOT NULL AND jsonb_typeof(items) = 'array' LOOP
        new_items := '[]'::jsonb;
        
        FOR item_element IN SELECT * FROM jsonb_array_elements(order_record.items) LOOP
            -- Try to get the product photo if image_url is missing or null
            IF NOT (item_element ? 'image_url') OR item_element->>'image_url' IS NULL OR item_element->>'image_url' = '' THEN
                
                prod_id := item_element->>'product_id';
                prod_photo := NULL;

                -- If product_id exists, look it up
                IF prod_id IS NOT NULL AND prod_id != '' THEN
                    BEGIN
                        SELECT photos[1] INTO prod_photo
                        FROM public.products 
                        WHERE id = prod_id::uuid;
                    EXCEPTION WHEN OTHERS THEN
                        -- Ignore invalid UUID errors
                        prod_photo := NULL;
                    END;
                END IF;

                -- If product_id is missing, try to lookup by product_name
                IF prod_photo IS NULL AND item_element->>'product_name' IS NOT NULL THEN
                    SELECT photos[1] INTO prod_photo
                    FROM public.products
                    WHERE product_name ILIKE ('%' || (item_element->>'product_name') || '%')
                       OR (item_element->>'product_name') ILIKE ('%' || product_name || '%')
                    LIMIT 1;
                END IF;
                
                -- Add image_url to the item if found
                IF prod_photo IS NOT NULL THEN
                    item_element := jsonb_set(item_element, '{image_url}', to_jsonb(prod_photo));
                    item_element := jsonb_set(item_element, '{product_image}', to_jsonb(prod_photo));
                END IF;
            END IF;
            
            -- Rebuild the items array
            new_items := new_items || item_element;
        END LOOP;
        
        -- Update the order if items array has changed
        IF new_items != order_record.items THEN
            UPDATE public.orders SET items = new_items WHERE id = order_record.id;
        END IF;
    END LOOP;
END $$;
