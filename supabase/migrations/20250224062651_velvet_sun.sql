/*
  # Fix chat rooms policies

  1. Changes
    - Remove recursive policy conditions that were causing infinite recursion
    - Simplify policies for better performance and reliability
    - Maintain security while fixing the recursion issue

  2. Security
    - Maintain RLS security
    - Ensure proper authentication checks
    - Keep existing access control logic
*/

-- Drop existing policies to start fresh
DROP POLICY IF EXISTS "chat_rooms_select_policy" ON chat_rooms;
DROP POLICY IF EXISTS "chat_rooms_insert_policy" ON chat_rooms;
DROP POLICY IF EXISTS "chat_rooms_update_policy" ON chat_rooms;

-- Create new simplified policies without recursion
CREATE POLICY "chat_rooms_select"
  ON chat_rooms
  FOR SELECT
  TO authenticated
  USING (
    claimer_id = auth.uid() OR
    product_id IN (
      SELECT id FROM lost_products WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "chat_rooms_insert"
  ON chat_rooms
  FOR INSERT
  TO authenticated
  WITH CHECK (
    claimer_id = auth.uid() AND
    product_id IN (
      SELECT id FROM lost_products WHERE user_id != auth.uid()
    )
  );

CREATE POLICY "chat_rooms_update"
  ON chat_rooms
  FOR UPDATE
  TO authenticated
  USING (
    product_id IN (
      SELECT id FROM lost_products WHERE user_id = auth.uid()
    )
  );

-- Ensure RLS is enabled
ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;