-- Create a function to backfill missing images in the orders table
CREATE OR REPLACE FUNCTION backfill_order_images()
RETURNS void AS $$
DECLARE
    order_record RECORD;
    item_element jsonb;
    new_items jsonb;
    prod_photo text;
BEGIN
    FOR order_record IN SELECT id, items FROM orders WHERE items IS NOT NULL AND jsonb_typeof(items) = 'array' LOOP
        new_items := '[]'::jsonb;
        
        FOR item_element IN SELECT * FROM jsonb_array_elements(order_record.items) LOOP
            -- Only update if image_url is missing or null
            IF NOT (item_element ? 'image_url') OR item_element->>'image_url' IS NULL THEN
                -- Fetch the first photo from the products table
                SELECT photos->>0 INTO prod_photo
                FROM products 
                WHERE id = (item_element->>'product_id')::uuid;
                
                -- Add image_url to the item
                IF prod_photo IS NOT NULL THEN
                    item_element := jsonb_set(item_element, '{image_url}', to_jsonb(prod_photo));
                END IF;
            END IF;
            
            -- Rebuild the items array
            new_items := new_items || item_element;
        END LOOP;
        
        -- Update the order if items array has changed
        IF new_items != order_record.items THEN
            UPDATE orders SET items = new_items WHERE id = order_record.id;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Execute the function to update all historical orders
SELECT backfill_order_images();

-- Optionally, drop the function after it's done
DROP FUNCTION backfill_order_images();
