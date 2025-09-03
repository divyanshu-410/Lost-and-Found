/*
  # Fix chat messages policies

  1. Changes
    - Simplify chat message policies
    - Fix permission checks for sending messages
    - Ensure proper access control for both reporters and claimers

  2. Security
    - Maintain RLS security
    - Ensure proper authentication checks
    - Allow approved claimers and reporters to send messages
*/

-- Drop existing policies
DROP POLICY IF EXISTS "chat_messages_select" ON chat_messages;
DROP POLICY IF EXISTS "chat_messages_insert" ON chat_messages;

-- Create new simplified policies
CREATE POLICY "chat_messages_select"
  ON chat_messages
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM chat_rooms
      WHERE chat_rooms.id = chat_messages.room_id
      AND (
        chat_rooms.claimer_id = auth.uid() OR
        chat_rooms.product_id IN (
          SELECT id FROM lost_products WHERE user_id = auth.uid()
        )
      )
    )
  );

CREATE POLICY "chat_messages_insert"
  ON chat_messages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    sender_id = auth.uid() AND
    EXISTS (
      SELECT 1 
      FROM chat_rooms
      WHERE id = room_id
      AND (
        (claimer_id = auth.uid() AND approval_status = 'approved') OR
        chat_rooms.product_id IN (
          SELECT id FROM lost_products WHERE user_id = auth.uid()
        )
      )
    )
  );

-- Ensure RLS is enabled
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;