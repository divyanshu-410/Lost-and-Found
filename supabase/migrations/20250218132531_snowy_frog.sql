/*
  # Fix Chat RLS Policies

  1. Changes
    - Drop existing chat room policies
    - Create new comprehensive policies for chat rooms
    - Add policies for viewing and creating chat rooms
    - Add policies for updating chat room approval status

  2. Security
    - Ensure proper RLS for chat rooms
    - Allow users to view their own chats
    - Allow reporters to view chats for their items
    - Allow claimers to create new chat rooms
*/

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "View chat rooms" ON chat_rooms;
DROP POLICY IF EXISTS "Create chat rooms" ON chat_rooms;
DROP POLICY IF EXISTS "Update chat rooms" ON chat_rooms;
DROP POLICY IF EXISTS "Update chat rooms as reporter" ON chat_rooms;

-- Create new comprehensive policies
CREATE POLICY "View own chats"
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

CREATE POLICY "Create new chat"
  ON chat_rooms
  FOR INSERT
  TO authenticated
  WITH CHECK (
    claimer_id = auth.uid() AND
    NOT EXISTS (
      SELECT 1 
      FROM chat_rooms existing_chat
      WHERE existing_chat.product_id = product_id 
      AND existing_chat.claimer_id = auth.uid()
    )
  );

CREATE POLICY "Update chat as reporter"
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
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 
      FROM lost_products 
      WHERE lost_products.id = product_id 
      AND lost_products.user_id = auth.uid()
    )
  );