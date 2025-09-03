/*
  # Enhanced Chat Room Policies with Safe Duplicate Handling

  1. Changes
    - Drop existing policies
    - Create enhanced policies for chat room access
    - Safely clean up duplicate chat rooms by first removing associated messages
    - Add unique constraint to prevent future duplicates

  2. Security
    - Maintain RLS policies
    - Ensure proper access control for all operations
    - Prevent duplicate chat rooms while preserving data integrity
*/

-- Drop existing policies
DROP POLICY IF EXISTS "view_chat_rooms" ON chat_rooms;
DROP POLICY IF EXISTS "create_chat_rooms" ON chat_rooms;
DROP POLICY IF EXISTS "update_chat_rooms" ON chat_rooms;

-- Create enhanced policies
CREATE POLICY "view_chat_rooms"
  ON chat_rooms
  FOR SELECT
  TO authenticated
  USING (
    claimer_id = auth.uid() OR
    product_id IN (
      SELECT id FROM lost_products WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "create_chat_rooms"
  ON chat_rooms
  FOR INSERT
  TO authenticated
  WITH CHECK (
    claimer_id = auth.uid() AND
    product_id IN (
      SELECT id FROM lost_products WHERE user_id != auth.uid()
    )
  );

CREATE POLICY "update_chat_rooms"
  ON chat_rooms
  FOR UPDATE
  TO authenticated
  USING (
    product_id IN (
      SELECT id FROM lost_products WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    product_id IN (
      SELECT id FROM lost_products WHERE user_id = auth.uid()
    )
  );

-- Clean up duplicate chat rooms and their messages safely
DO $$
DECLARE
    duplicate RECORD;
    keep_id UUID;
BEGIN
    FOR duplicate IN (
        SELECT DISTINCT ON (product_id, claimer_id)
            product_id,
            claimer_id,
            array_agg(id ORDER BY created_at DESC) as room_ids
        FROM chat_rooms
        GROUP BY product_id, claimer_id
        HAVING COUNT(*) > 1
    ) LOOP
        -- Get the ID of the newest chat room to keep
        keep_id := (duplicate.room_ids)[1];
        
        -- Move all messages to the chat room we're keeping
        UPDATE chat_messages
        SET room_id = keep_id
        WHERE room_id = ANY (duplicate.room_ids)
        AND room_id != keep_id;

        -- Now safely delete the duplicate chat rooms
        DELETE FROM chat_rooms
        WHERE product_id = duplicate.product_id
        AND claimer_id = duplicate.claimer_id
        AND id != keep_id;
    END LOOP;
END $$;

-- Now safely add the unique constraint
ALTER TABLE chat_rooms DROP CONSTRAINT IF EXISTS unique_product_claimer;
ALTER TABLE chat_rooms ADD CONSTRAINT unique_product_claimer UNIQUE (product_id, claimer_id);

-- Ensure RLS is enabled
ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;