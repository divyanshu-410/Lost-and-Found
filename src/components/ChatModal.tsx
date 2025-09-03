import React, { useState, useEffect, useRef } from 'react';
import { X, Send, Check, X as XIcon, AlertCircle } from 'lucide-react';
import { supabase } from '../lib/supabase';

interface ChatModalProps {
  isOpen: boolean;
  onClose: () => void;
  productId: string;
  productName: string;
}

interface Message {
  id: string;
  sender_id: string;
  message: string;
  created_at: string;
  is_system_message?: boolean;
  isPending?: boolean;
}

interface ChatRoom {
  id: string;
  status: string;
  approval_status: string;
}

interface Product {
  contact_info: string;
}

export default function ChatModal({ isOpen, onClose, productId, productName }: ChatModalProps) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [chatRoom, setChatRoom] = useState<ChatRoom | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const [user, setUser] = useState<any>(null);
  const [isReporter, setIsReporter] = useState(false);
  const [allChatRooms, setAllChatRooms] = useState<ChatRoom[]>([]);
  const [selectedRoomId, setSelectedRoomId] = useState<string | null>(null);
  const channelRef = useRef<any>(null);
  const [retryCount, setRetryCount] = useState(0);
  const maxRetries = 3;
  const [productInfo, setProductInfo] = useState<Product | null>(null);
  const [pendingMessageId, setPendingMessageId] = useState(0);

  useEffect(() => {
    const getUser = async () => {
      try {
        const { data: { user }, error: userError } = await supabase.auth.getUser();
        if (userError) throw userError;
        setUser(user);

        if (user) {
          const { data, error: productError } = await supabase
            .from('lost_products')
            .select('user_id, contact_info')
            .eq('id', productId)
            .single();
          
          if (productError) throw productError;
          
          if (data) {
            setIsReporter(data.user_id === user.id);
            setProductInfo(data);
          }
        }
      } catch (err) {
        console.error('Error fetching user or product:', err);
        setError('Failed to initialize chat. Please try again.');
      }
    };
    getUser();
  }, [productId]);

  useEffect(() => {
    if (isOpen && user) {
      initializeChat();
    }
    
    return () => {
      if (channelRef.current) {
        channelRef.current.unsubscribe();
      }
    };
  }, [isOpen, user, productId, isReporter]);

  const initializeChat = async () => {
    try {
      setLoading(true);
      setError('');
      
      if (isReporter) {
        const { data: rooms, error: fetchError } = await supabase
          .from('chat_rooms')
          .select('*')
          .eq('product_id', productId);

        if (fetchError) throw fetchError;
        
        if (rooms && rooms.length > 0) {
          setAllChatRooms(rooms);
          setSelectedRoomId(rooms[0].id);
          setChatRoom(rooms[0]);
          await fetchMessages(rooms[0].id);
          subscribeToRoom(rooms[0].id);
        }
      } else {
        // First check if a chat room already exists
        const { data: existingRoom, error: fetchError } = await supabase
          .from('chat_rooms')
          .select('*')
          .eq('product_id', productId)
          .eq('claimer_id', user.id)
          .maybeSingle();

        if (fetchError) throw fetchError;

        if (existingRoom) {
          setChatRoom(existingRoom);
          setAllChatRooms([existingRoom]);
          setSelectedRoomId(existingRoom.id);
          await fetchMessages(existingRoom.id);
          subscribeToRoom(existingRoom.id);
        } else {
          // Create new chat room with retry mechanism
          await createChatRoom();
        }
      }
    } catch (err) {
      console.error('Chat initialization error:', err);
      setError('Failed to initialize chat. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const createChatRoom = async () => {
    try {
      const { data: newRoom, error: createError } = await supabase
        .from('chat_rooms')
        .insert({
          product_id: productId,
          claimer_id: user.id,
          status: 'pending',
          approval_status: 'pending'
        })
        .select()
        .single();

      if (createError) {
        if (retryCount < maxRetries) {
          setRetryCount(prev => prev + 1);
          setTimeout(() => createChatRoom(), 1000 * (retryCount + 1));
          return;
        }
        throw createError;
      }

      if (newRoom) {
        setAllChatRooms([newRoom]);
        setSelectedRoomId(newRoom.id);
        setChatRoom(newRoom);
        await sendSystemMessage(newRoom.id, "👋 Chat room created! Waiting for reporter's approval.");
        subscribeToRoom(newRoom.id);
      }
    } catch (err) {
      console.error('Error creating chat room:', err);
      setError('Failed to create chat room. Please try again.');
    }
  };

  const handleApproval = async () => {
    if (!chatRoom) return;

    try {
      const { error: updateError } = await supabase
        .from('chat_rooms')
        .update({ approval_status: 'approved' })
        .eq('id', chatRoom.id);

      if (updateError) throw updateError;

      setChatRoom({ ...chatRoom, approval_status: 'approved' });
      await sendSystemMessage(chatRoom.id, "✅ Chat approved! You can now communicate with each other.");
    } catch (err) {
      console.error('Error approving chat:', err);
      setError('Failed to approve chat. Please try again.');
    }
  };

  const subscribeToRoom = (roomId: string) => {
    if (channelRef.current) {
      channelRef.current.unsubscribe();
    }

    const channel = supabase.channel(`room:${roomId}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'chat_messages',
          filter: `room_id=eq.${roomId}`
        },
        (payload) => {
          const newMessage = payload.new as Message;
          
          // Replace any pending message with the actual message from the server
          setMessages(prev => {
            const updatedMessages = prev.filter(msg => 
              !msg.isPending || msg.message !== newMessage.message
            );
            return [...updatedMessages, newMessage];
          });
          
          scrollToBottom();
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'chat_rooms',
          filter: `id=eq.${roomId}`
        },
        (payload) => {
          const updatedRoom = payload.new as ChatRoom;
          setChatRoom(updatedRoom);
        }
      )
      .subscribe();

    channelRef.current = channel;
  };

  const sendSystemMessage = async (roomId: string, message: string) => {
    try {
      await supabase
        .from('chat_messages')
        .insert([{
          room_id: roomId,
          sender_id: user.id,
          message,
          is_system_message: true
        }]);
    } catch (err) {
      console.error('Error sending system message:', err);
    }
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  const fetchMessages = async (roomId: string) => {
    try {
      const { data, error } = await supabase
        .from('chat_messages')
        .select('*')
        .eq('room_id', roomId)
        .order('created_at', { ascending: true });

      if (error) throw error;
      setMessages(data || []);
    } catch (err) {
      console.error('Error fetching messages:', err);
      setError('Failed to load messages. Please try refreshing.');
    }
  };

  const sendMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newMessage.trim() || !chatRoom) return;
    
    const messageText = newMessage.trim();
    setNewMessage('');
    
    // Create a temporary pending message to show immediately
    const tempId = `pending-${pendingMessageId}`;
    setPendingMessageId(prev => prev + 1);
    
    const pendingMessage: Message = {
      id: tempId,
      sender_id: user.id,
      message: messageText,
      created_at: new Date().toISOString(),
      isPending: true
    };
    
    // Add the pending message to the messages array
    setMessages(prev => [...prev, pendingMessage]);
    
    // Scroll to the bottom to show the new message
    setTimeout(scrollToBottom, 50);

    try {
      const { error } = await supabase
        .from('chat_messages')
        .insert([{
          room_id: chatRoom.id,
          sender_id: user.id,
          message: messageText
        }]);

      if (error) {
        // If there's an error, remove the pending message and show error
        setMessages(prev => prev.filter(msg => msg.id !== tempId));
        throw error;
      }
      
      // The real message will be added via the subscription
    } catch (err) {
      console.error('Error sending message:', err);
      setError('Failed to send message. Please try again.');
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-lg shadow-xl w-full max-w-2xl">
        <div className="p-4 border-b flex justify-between items-center">
          <h3 className="text-lg font-semibold text-[#2D2654]">
            Chat about: {productName}
          </h3>
          <button
            onClick={onClose}
            className="text-gray-500 hover:text-gray-700"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        {error ? (
          <div className="p-4">
            <div className="bg-red-50 border border-red-200 rounded-lg p-4 flex items-start justify-between">
              <div className="flex items-center gap-2">
                <AlertCircle className="w-5 h-5 text-red-500 flex-shrink-0" />
                <p className="text-red-700">{error}</p>
              </div>
              <button
                onClick={() => setError('')}
                className="text-red-500 hover:text-red-700"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
            <button
              onClick={() => {
                setRetryCount(0);
                initializeChat();
              }}
              className="mt-4 w-full px-4 py-2 bg-[#2D2654] text-white rounded-lg hover:bg-[#3d3470] transition"
            >
              Retry
            </button>
          </div>
        ) : loading ? (
          <div className="p-4 text-center">Loading chat...</div>
        ) : (
          <>
            {isReporter && allChatRooms.length > 0 && (
              <div className="p-4 border-b">
                <select
                  value={selectedRoomId || ''}
                  onChange={(e) => {
                    const newRoomId = e.target.value;
                    setSelectedRoomId(newRoomId);
                    const newRoom = allChatRooms.find(room => room.id === newRoomId);
                    if (newRoom) {
                      setChatRoom(newRoom);
                      fetchMessages(newRoomId);
                      subscribeToRoom(newRoomId);
                    }
                  }}
                  className="w-full p-2 border rounded-lg focus:border-[#2D2654] focus:ring focus:ring-[#2D2654] focus:ring-opacity-50"
                >
                  {allChatRooms.map((room) => (
                    <option key={room.id} value={room.id}>
                      Chat Room {room.id.slice(0, 8)}
                    </option>
                  ))}
                </select>
              </div>
            )}

            {chatRoom && (
              <div className="p-4 border-b bg-gray-50">
                <div className="flex items-center justify-between">
                  <div className="text-sm text-gray-600">
                    Status: {chatRoom.approval_status === 'approved' ? (
                      <span className="text-green-600 font-medium">Approved</span>
                    ) : (
                      <span className="text-yellow-600 font-medium">Pending Approval</span>
                    )}
                  </div>
                  {isReporter && chatRoom.approval_status === 'pending' && (
                    <button
                      onClick={handleApproval}
                      className="bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition flex items-center gap-2"
                    >
                      <Check className="w-4 h-4" />
                      Approve Chat
                    </button>
                  )}
                </div>
                {!isReporter && chatRoom.approval_status === 'approved' && productInfo && (
                  <div className="mt-4 p-3 bg-green-50 rounded-lg">
                    <p className="text-sm text-green-800 font-medium">Contact Information:</p>
                    <p className="text-sm text-green-700">{productInfo.contact_info}</p>
                  </div>
                )}
              </div>
            )}

            <div className="h-96 overflow-y-auto p-4 space-y-4">
              {messages.length === 0 ? (
                <div className="text-center text-gray-500">
                  No messages yet. Start the conversation!
                </div>
              ) : (
                messages.map((message) => (
                  <div
                    key={message.id}
                    className={`flex ${
                      message.sender_id === user?.id ? 'justify-end' : 'justify-start'
                    }`}
                  >
                    <div
                      className={`max-w-[70%] rounded-lg p-3 ${
                        message.is_system_message
                          ? 'bg-gray-100 text-gray-700 mx-auto'
                          : message.sender_id === user?.id
                            ? `bg-[#2D2654] text-white ${message.isPending ? 'opacity-70' : ''}`
                            : 'bg-gray-100 text-gray-800'
                      }`}
                    >
                      <p className="text-sm">{message.message}</p>
                      <span className="text-xs opacity-75 mt-1 block">
                        {message.isPending ? 'Sending...' : new Date(message.created_at).toLocaleTimeString()}
                      </span>
                    </div>
                  </div>
                ))
              )}
              <div ref={messagesEndRef} />
            </div>

            <form onSubmit={sendMessage} className="p-4 border-t">
              <div className="flex space-x-2">
                <input
                  type="text"
                  value={newMessage}
                  onChange={(e) => setNewMessage(e.target.value)}
                  placeholder="Type your message..."
                  className="flex-1 rounded-lg border border-gray-300 p-2 focus:outline-none focus:border-[#2D2654]"
                />
                <button
                  type="submit"
                  disabled={!newMessage.trim() || !chatRoom}
                  className="bg-[#2D2654] text-white px-4 py-2 rounded-lg hover:bg-[#3d3470] disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <Send className="w-5 h-5" />
                </button>
              </div>
            </form>
          </>
        )}
      </div>
    </div>
  );
}