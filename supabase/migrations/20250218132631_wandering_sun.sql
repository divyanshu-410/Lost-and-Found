/*
  # Fix Chat Room Policies Recursion

  1. Changes
    - Simplify chat room policies to prevent recursion
    - Maintain security requirements for viewing and creating chats
    - Fix update policy for chat approval

  2. Security
    - Ensure proper RLS for chat rooms
    - Prevent unauthorized access
    - Allow appropriate chat creation and updates
*/

-- Drop existing policies
DROP POLICY IF EXISTS "View own chats" ON chat_rooms;
DROP POLICY IF EXISTS "Create new chat" ON chat_rooms;
DROP POLICY IF EXISTS "Update chat as reporter" ON chat_rooms;

-- Create simplified policies
CREATE POLICY "View chats"
  ON chat_rooms
  FOR SELECT
  TO authenticated
  USING (
    claimer_id = auth.uid() OR
    product_id IN (
      SELECT id 
      FROM lost_products 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Create chats"
  ON chat_rooms
  FOR INSERT
  TO authenticated
  WITH CHECK (
    claimer_id = auth.uid() AND
    product_id IN (
      SELECT id 
      FROM lost_products 
      WHERE user_id != auth.uid()
    )
  );

CREATE POLICY "Update chats"
  ON chat_rooms
  FOR UPDATE
  TO authenticated
  USING (
    product_id IN (
      SELECT id 
      FROM lost_products 
      WHERE user_id = auth.uid()
    )
  );