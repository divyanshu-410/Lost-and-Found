import React, { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { X, MessageCircle, AlertCircle } from 'lucide-react';
import ChatModal from './ChatModal';

interface Product {
  id: string;
  product_name: string;
  description: string;
  contact_info: string;
  photo_url: string;
  status: string;
  created_at: string;
  full_name: string;
  user_id: string;
}

interface ChatRoom {
  id: string;
  status: string;
  product_id: string;
  claimer_id: string;
  approval_status: string;
}

function ReportedProducts() {
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [selectedImage, setSelectedImage] = useState<string | null>(null);
  const [chatModalOpen, setChatModalOpen] = useState(false);
  const [selectedProduct, setSelectedProduct] = useState<Product | null>(null);
  const [user, setUser] = useState<any>(null);
  const [chatRooms, setChatRooms] = useState<Record<string, ChatRoom>>({});

  useEffect(() => {
    const getUser = async () => {
      try {
        const { data: { user }, error: userError } = await supabase.auth.getUser();
        if (userError) throw userError;
        setUser(user);
      } catch (err) {
        console.error('Error fetching user:', err);
        setError('Failed to fetch user information. Please try refreshing the page.');
      }
    };
    getUser();
  }, []);

  useEffect(() => {
    fetchProducts();
  }, []);

  useEffect(() => {
    if (user && products.length > 0) {
      fetchChatRooms();
    }
  }, [user, products]);

  const fetchChatRooms = async () => {
    if (!user) return;
    
    try {
      // First, fetch rooms where user is the claimer
      const { data: claimerRooms, error: claimerError } = await supabase
        .from('chat_rooms')
        .select('*')
        .eq('claimer_id', user.id);

      if (claimerError) throw claimerError;

      // Then, fetch rooms for products where user is the reporter
      const productIds = products
        .filter(p => p.user_id === user.id)
        .map(p => p.id);

      if (productIds.length > 0) {
        const { data: reporterRooms, error: reporterError } = await supabase
          .from('chat_rooms')
          .select('*')
          .in('product_id', productIds);

        if (reporterError) throw reporterError;

        // Combine and deduplicate rooms
        const allRooms = [...(claimerRooms || []), ...(reporterRooms || [])];
        const uniqueRooms = allRooms.reduce((acc, room) => {
          acc[room.product_id] = room;
          return acc;
        }, {} as Record<string, ChatRoom>);

        setChatRooms(uniqueRooms);
      }
    } catch (err) {
      console.error('Error fetching chat rooms:', err);
      setError('Failed to load chat information. Please try refreshing the page.');
    }
  };

  const fetchProducts = async () => {
    try {
      const { data, error: fetchError } = await supabase
        .from('lost_products')
        .select('*')
        .order('created_at', { ascending: false });

      if (fetchError) throw fetchError;
      
      if (!data || data.length === 0) {
        setProducts([]);
        return;
      }
      
      setProducts(data);
    } catch (err) {
      console.error('Error fetching products:', err);
      setError(err instanceof Error ? err.message : 'Failed to load products. Please try refreshing the page.');
    } finally {
      setLoading(false);
    }
  };

  const handleChatClick = (product: Product) => {
    if (!user) {
      setError('Please log in to chat with the item owner');
      return;
    }
    
    try {
      setSelectedProduct(product);
      setChatModalOpen(true);
    } catch (err) {
      console.error('Error opening chat:', err);
      setError('Failed to open chat. Please try again.');
    }
  };

  const dismissError = () => {
    setError('');
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-xl text-gray-600">Loading...</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
        {error && (
          <div className="mb-6 bg-red-50 border border-red-200 rounded-lg p-4 flex items-start justify-between">
            <div className="flex items-center gap-2">
              <AlertCircle className="w-5 h-5 text-red-500 flex-shrink-0" />
              <p className="text-red-700">{error}</p>
            </div>
            <button
              onClick={dismissError}
              className="text-red-500 hover:text-red-700"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        )}

        <h2 className="text-3xl font-bold text-[#2D2654] mb-8">Reported Products</h2>
        
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {products.map((product) => {
            const chatRoom = chatRooms[product.id];
            const showContactInfo = chatRoom?.approval_status === 'approved';
            const isReporter = user?.id === product.user_id;
            const hasActiveChat = chatRoom !== undefined;
            const canChat = user && (isReporter || !hasActiveChat);
            
            return (
              <div
                key={product.id}
                className="bg-white rounded-xl shadow-lg overflow-hidden hover:shadow-xl transition"
              >
                {product.photo_url && (
                  <div 
                    className="relative h-64 cursor-pointer overflow-hidden"
                    onClick={() => setSelectedImage(product.photo_url)}
                  >
                    <img
                      src={product.photo_url}
                      alt={product.product_name}
                      className="w-full h-full object-cover hover:scale-105 transition-transform duration-300"
                    />
                    <div className="absolute inset-0 bg-black bg-opacity-0 hover:bg-opacity-10 transition-opacity flex items-center justify-center">
                      <span className="text-white opacity-0 hover:opacity-100 transition-opacity">
                        Click to view full image
                      </span>
                    </div>
                  </div>
                )}
                <div className="p-6">
                  <div className="flex items-center justify-between mb-4">
                    <h3 className="text-xl font-semibold text-[#2D2654]">
                      {product.product_name}
                    </h3>
                    <span className={`px-3 py-1 rounded-full text-sm font-medium ${
                      product.status === 'found' 
                        ? 'bg-green-100 text-green-800'
                        : 'bg-yellow-100 text-yellow-800'
                    }`}>
                      {product.status.charAt(0).toUpperCase() + product.status.slice(1)}
                    </span>
                  </div>
                  <p className="text-gray-600 mb-4">{product.description}</p>
                  <div className="border-t pt-4">
                    <p className="text-sm text-gray-500">
                      Reported by: {product.full_name}
                    </p>
                    {showContactInfo && (
                      <div className="mt-2 p-3 bg-green-50 rounded-lg">
                        <p className="text-sm text-green-800 font-medium">
                          Contact Information:
                        </p>
                        <p className="text-sm text-green-700">
                          {product.contact_info}
                        </p>
                      </div>
                    )}
                    <p className="text-sm text-gray-500 mt-2">
                      Posted: {new Date(product.created_at).toLocaleDateString()}
                    </p>
                    {canChat && (
                      <button
                        onClick={() => handleChatClick(product)}
                        className={`mt-4 w-full flex items-center justify-center gap-2 px-4 py-2 rounded-lg text-white ${
                          hasActiveChat
                            ? 'bg-green-600 hover:bg-green-700'
                            : 'bg-[#2D2654] hover:bg-[#3d3470]'
                        } transition-colors`}
                      >
                        <MessageCircle className="w-5 h-5" />
                        {isReporter ? 'View Chats' : hasActiveChat ? 'Continue Chat' : 'Chat for Claim'}
                      </button>
                    )}
                    {!canChat && !isReporter && hasActiveChat && (
                      <div className="mt-4 text-sm text-gray-500 text-center">
                        Chat request pending approval
                      </div>
                    )}
                  </div>
                </div>
              </div>
            );
          })}
        </div>

        {products.length === 0 && !error && (
          <div className="text-center py-12">
            <p className="text-gray-600">No products have been reported yet.</p>
          </div>
        )}

        {/* Full Image Modal */}
        {selectedImage && (
          <div 
            className="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50 p-4"
            onClick={() => setSelectedImage(null)}
          >
            <div className="relative max-w-7xl w-full max-h-[90vh] flex items-center justify-center">
              <button
                onClick={() => setSelectedImage(null)}
                className="absolute top-4 right-4 text-white hover:text-gray-300 z-10"
              >
                <X className="w-8 h-8" />
              </button>
              <img
                src={selectedImage}
                alt="Full size"
                className="max-w-full max-h-[90vh] object-contain rounded-lg"
                onClick={(e) => e.stopPropagation()}
              />
            </div>
          </div>
        )}

        {/* Chat Modal */}
        {selectedProduct && (
          <ChatModal
            isOpen={chatModalOpen}
            onClose={() => {
              setChatModalOpen(false);
              setSelectedProduct(null);
            }}
            productId={selectedProduct.id}
            productName={selectedProduct.product_name}
          />
        )}
      </div>
    </div>
  );
}

export default ReportedProducts;