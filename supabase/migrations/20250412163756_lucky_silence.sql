/*
  # Add expiry date and cleanup functionality

  1. Changes
    - Add expiry_date column to lost_products table
    - Create function to calculate expiry date
    - Add trigger to automatically remove expired items
    
  2. Security
    - Maintain RLS policies
    - Ensure data cleanup happens automatically
*/

-- Add expiry_date column
ALTER TABLE lost_products 
ADD COLUMN IF NOT EXISTS expiry_date timestamptz 
DEFAULT (now() + interval '45 days');

-- Create function to remove expired items
CREATE OR REPLACE FUNCTION cleanup_expired_items()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Delete chat messages for expired items
  DELETE FROM chat_messages 
  WHERE room_id IN (
    SELECT id FROM chat_rooms 
    WHERE product_id IN (
      SELECT id FROM lost_products 
      WHERE expiry_date < now()
    )
  );
  
  -- Delete chat rooms for expired items
  DELETE FROM chat_rooms 
  WHERE product_id IN (
    SELECT id FROM lost_products 
    WHERE expiry_date < now()
  );
  
  -- Delete expired items
  DELETE FROM lost_products 
  WHERE expiry_date < now();
END;
$$;

-- Create function to handle cleanup trigger
CREATE OR REPLACE FUNCTION handle_cleanup_trigger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Run cleanup if there are any expired items
  IF EXISTS (
    SELECT 1 FROM lost_products WHERE expiry_date < now()
  ) THEN
    PERFORM cleanup_expired_items();
  END IF;
  RETURN NEW;
END;
$$;

-- Create trigger to run cleanup on any lost_products table changes
DROP TRIGGER IF EXISTS cleanup_expired_items_trigger ON lost_products;
CREATE TRIGGER cleanup_expired_items_trigger
  AFTER INSERT OR UPDATE OR DELETE ON lost_products
  FOR EACH STATEMENT
  EXECUTE FUNCTION handle_cleanup_trigger();

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_lost_products_expiry_date ON lost_products(expiry_date);