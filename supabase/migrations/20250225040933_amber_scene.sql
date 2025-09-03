/*
  # Fix chat room policies

  1. Changes
    - Simplify chat room policies
    - Fix permission issues for chat room creation
    - Ensure proper access control

  2. Security
    - Maintain RLS
    - Keep authentication checks
    - Preserve data integrity
*/

-- Drop existing policies
DROP POLICY IF EXISTS "chat_rooms_select" ON chat_rooms;
DROP POLICY IF EXISTS "chat_rooms_insert" ON chat_rooms;
DROP POLICY IF EXISTS "chat_rooms_update" ON chat_rooms;

-- Create simplified policies
CREATE POLICY "chat_rooms_select"
  ON chat_rooms
  FOR SELECT
  TO authenticated
  USING (true);  -- Allow all authenticated users to view chat rooms

CREATE POLICY "chat_rooms_insert"
  ON chat_rooms
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = claimer_id AND
    EXISTS (
      SELECT 1 FROM lost_products
      WHERE id = product_id
    )
  );

CREATE POLICY "chat_rooms_update"
  ON chat_rooms
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM lost_products
      WHERE id = product_id
      AND user_id = auth.uid()
    )
  );

-- Ensure RLS is enabled
ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;