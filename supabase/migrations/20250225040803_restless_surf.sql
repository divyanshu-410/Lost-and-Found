/*
  # Enable infinite chat messaging

  1. Changes
    - Remove restrictions on message sending
    - Allow both reporters and claimers to chat freely
    - Maintain basic security checks

  2. Security
    - Keep RLS enabled
    - Ensure proper authentication
    - Maintain user role validation
*/

-- Drop existing policies
DROP POLICY IF EXISTS "chat_messages_select" ON chat_messages;
DROP POLICY IF EXISTS "chat_messages_insert" ON chat_messages;

-- Create new policies that allow infinite messaging
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
        claimer_id = auth.uid() OR
        chat_rooms.product_id IN (
          SELECT id FROM lost_products WHERE user_id = auth.uid()
        )
      )
    )
  );

-- Ensure RLS is enabled
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;