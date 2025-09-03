/*
  # Fix Chat Room Policies with Safe Deduplication

  1. Changes
    - Safely remove duplicate chat rooms and their messages
    - Add unique constraint to prevent future duplicates
    - Create new policies for chat rooms

  2. Security
    - Maintain RLS
    - Add proper policies for viewing, creating, and updating chat rooms
*/

-- Drop existing policies
DROP POLICY IF EXISTS "View chats" ON chat_rooms;
DROP POLICY IF EXISTS "Create chats" ON chat_rooms;
DROP POLICY IF EXISTS "Update chats" ON chat_rooms;

-- First, identify the chat rooms to keep (most recent for each product_id/claimer_id pair)
CREATE TEMP TABLE rooms_to_keep AS
SELECT DISTINCT ON (product_id, claimer_id) 
  id,
  product_id,
  claimer_id,
  created_at
FROM chat_rooms
ORDER BY product_id, claimer_id, created_at DESC;

-- Delete messages from chat rooms that will be removed
DELETE FROM chat_messages
WHERE room_id IN (
  SELECT cr.id
  FROM chat_rooms cr
  WHERE NOT EXISTS (
    SELECT 1
    FROM rooms_to_keep rtk
    WHERE rtk.id = cr.id
  )
);

-- Now safely remove duplicate chat rooms
DELETE FROM chat_rooms cr
WHERE NOT EXISTS (
  SELECT 1
  FROM rooms_to_keep rtk
  WHERE rtk.id = cr.id
);

-- Drop the temporary table
DROP TABLE rooms_to_keep;

-- Now safely add the unique constraint
ALTER TABLE chat_rooms
ADD CONSTRAINT unique_product_claimer UNIQUE (product_id, claimer_id);

-- Create new policies
CREATE POLICY "view_chat_rooms"
  ON chat_rooms
  FOR SELECT
  TO authenticated
  USING (
    claimer_id = auth.uid() OR
    EXISTS (
      SELECT 1 
      FROM lost_products 
      WHERE id = chat_rooms.product_id 
      AND user_id = auth.uid()
    )
  );

CREATE POLICY "create_chat_room"
  ON chat_rooms
  FOR INSERT
  TO authenticated
  WITH CHECK (
    claimer_id = auth.uid() AND
    EXISTS (
      SELECT 1 
      FROM lost_products 
      WHERE id = product_id 
      AND user_id != auth.uid()
    )
  );

CREATE POLICY "update_chat_room"
  ON chat_rooms
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM lost_products 
      WHERE id = chat_rooms.product_id 
      AND user_id = auth.uid()
    )
  );