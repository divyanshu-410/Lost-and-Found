/*
  # Fix Chat Room Policies

  1. Changes
    - Refine chat room policies to fix permission issues
    - Add additional checks for chat creation
    - Ensure proper access control

  2. Security
    - Maintain RLS for chat rooms
    - Prevent duplicate chats
    - Allow appropriate access for reporters and claimers
*/

-- Drop existing policies
DROP POLICY IF EXISTS "View chats" ON chat_rooms;
DROP POLICY IF EXISTS "Create chats" ON chat_rooms;
DROP POLICY IF EXISTS "Update chats" ON chat_rooms;

-- Create refined policies
CREATE POLICY "View chats"
  ON chat_rooms
  FOR SELECT
  TO authenticated
  USING (
    claimer_id = auth.uid() OR
    EXISTS (
      SELECT 1 
      FROM lost_products 
      WHERE lost_products.id = chat_rooms.product_id 
      AND lost_products.user_id = auth.uid()
    )
  );

CREATE POLICY "Create chats"
  ON chat_rooms
  FOR INSERT
  TO authenticated
  WITH CHECK (
    claimer_id = auth.uid() AND
    EXISTS (
      SELECT 1 
      FROM lost_products 
      WHERE lost_products.id = product_id 
      AND lost_products.user_id != auth.uid()
    ) AND
    NOT EXISTS (
      SELECT 1 
      FROM chat_rooms existing_chat
      WHERE existing_chat.product_id = product_id 
      AND existing_chat.claimer_id = auth.uid()
    )
  );

CREATE POLICY "Update chats"
  ON chat_rooms
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM lost_products 
      WHERE lost_products.id = chat_rooms.product_id 
      AND lost_products.user_id = auth.uid()
    )
  );