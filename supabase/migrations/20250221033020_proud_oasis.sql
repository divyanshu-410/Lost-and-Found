/*
  # Fix Chat System Issues

  1. Changes
    - Add is_system_message column to chat_messages
    - Update chat messages policies
    - Fix chat room policies

  2. Security
    - Maintain proper access control for messages
    - Ensure users can only access their own chats and messages
*/

-- Add is_system_message column to chat_messages
ALTER TABLE chat_messages 
ADD COLUMN IF NOT EXISTS is_system_message boolean DEFAULT false;

-- Drop existing policies for chat_messages if they exist
DROP POLICY IF EXISTS "Users can view messages in their chat rooms" ON chat_messages;
DROP POLICY IF EXISTS "Users can send messages in their chat rooms" ON chat_messages;

-- Create new policies for chat_messages
CREATE POLICY "Allow viewing messages in own chats"
  ON chat_messages
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM chat_rooms
      WHERE chat_rooms.id = chat_messages.room_id
      AND (
        chat_rooms.claimer_id = auth.uid()
        OR chat_rooms.product_id IN (
          SELECT id FROM lost_products 
          WHERE user_id = auth.uid()
        )
      )
    )
  );

CREATE POLICY "Allow sending messages in own chats"
  ON chat_messages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM chat_rooms
      WHERE chat_rooms.id = room_id
      AND (
        chat_rooms.claimer_id = auth.uid()
        OR chat_rooms.product_id IN (
          SELECT id FROM lost_products 
          WHERE user_id = auth.uid()
        )
      )
    )
  );

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_chat_messages_room_id ON chat_messages(room_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender_id ON chat_messages(sender_id);

-- Ensure RLS is enabled
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;