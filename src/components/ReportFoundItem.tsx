import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { Camera } from 'lucide-react';

function ReportFoundItem() {
  const navigate = useNavigate();
  const [formData, setFormData] = useState({
    productName: '',
    description: '',
    contactInfo: '',
    fullName: '',
    photo: null as File | null,
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value
    }));
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      setFormData(prev => ({
        ...prev,
        photo: e.target.files![0]
      }));
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const { data: { user } } = await supabase.auth.getUser();
      
      if (!user) {
        throw new Error('Please log in to report a found item');
      }

      let photoUrl = '';
      
      if (formData.photo) {
        const fileExt = formData.photo.name.split('.').pop();
        const fileName = `${Math.random()}.${fileExt}`;
        const { data: uploadData, error: uploadError } = await supabase.storage
          .from('product-photos')
          .upload(fileName, formData.photo);

        if (uploadError) throw uploadError;
        
        const { data: { publicUrl } } = supabase.storage
          .from('product-photos')
          .getPublicUrl(fileName);
          
        photoUrl = publicUrl;
      }

      const { error: insertError } = await supabase
        .from('lost_products')
        .insert({
          user_id: user.id,
          product_name: formData.productName,
          description: formData.description,
          contact_info: formData.contactInfo,
          full_name: formData.fullName,
          photo_url: photoUrl,
          status: 'found'
        });

      if (insertError) throw insertError;

      navigate('/reported-products');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 py-16 px-4 sm:px-6 lg:px-8">
      <div className="max-w-2xl mx-auto bg-white p-10 rounded-xl shadow-lg">
        <h2 className="text-3xl font-bold text-[#2D2654] mb-10">Report Found Item</h2>
        
        {error && (
          <div className="bg-red-50 text-red-500 p-4 rounded-lg mb-8">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-8">
          <div>
            <label htmlFor="fullName" className="block text-sm font-medium text-gray-700 mb-2">
              Full Name
            </label>
            <input
              type="text"
              id="fullName"
              name="fullName"
              required
              value={formData.fullName}
              onChange={handleChange}
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-[#2D2654] focus:ring focus:ring-[#2D2654] focus:ring-opacity-50 p-3"
            />
          </div>

          <div>
            <label htmlFor="productName" className="block text-sm font-medium text-gray-700 mb-2">
              Product Name
            </label>
            <input
              type="text"
              id="productName"
              name="productName"
              required
              value={formData.productName}
              onChange={handleChange}
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-[#2D2654] focus:ring focus:ring-[#2D2654] focus:ring-opacity-50 p-3"
            />
          </div>

          <div>
            <label htmlFor="description" className="block text-sm font-medium text-gray-700 mb-2">
              Description
            </label>
            <textarea
              id="description"
              name="description"
              required
              value={formData.description}
              onChange={handleChange}
              rows={4}
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-[#2D2654] focus:ring focus:ring-[#2D2654] focus:ring-opacity-50 p-3"
            />
          </div>

          <div>
            <label htmlFor="contactInfo" className="block text-sm font-medium text-gray-700 mb-2">
              Contact Information
            </label>
            <input
              type="text"
              id="contactInfo"
              name="contactInfo"
              required
              value={formData.contactInfo}
              onChange={handleChange}
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-[#2D2654] focus:ring focus:ring-[#2D2654] focus:ring-opacity-50 p-3"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Photo
            </label>
            <div className="mt-1 flex items-center">
              <label className="relative cursor-pointer bg-white rounded-md font-medium text-[#2D2654] hover:text-[#3d3470] focus-within:outline-none">
                <span className="inline-flex items-center px-6 py-3 border border-[#2D2654] rounded-md shadow-sm text-sm font-medium text-[#2D2654] bg-white hover:bg-gray-50">
                  <Camera className="w-5 h-5 mr-2" />
                  Upload Photo
                </span>
                <input
                  type="file"
                  className="sr-only"
                  accept="image/*"
                  onChange={handleFileChange}
                />
              </label>
              {formData.photo && (
                <span className="ml-3 text-sm text-gray-600">
                  {formData.photo.name}
                </span>
              )}
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full flex justify-center py-4 px-6 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-[#2D2654] hover:bg-[#3d3470] focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#2D2654] disabled:opacity-50 mt-8"
          >
            {loading ? 'Submitting...' : 'Submit Report'}
          </button>
        </form>
      </div>
    </div>
  );
}

export default ReportFoundItem;