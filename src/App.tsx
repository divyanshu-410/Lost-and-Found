import React, { useEffect, useState } from 'react';
import { LogOut, HelpCircle, Search, MapPin, Bell, Shield } from 'lucide-react';
import { BrowserRouter as Router, Routes, Route, Link, useNavigate } from 'react-router-dom';
import { supabase } from './lib/supabase';
import Signup from './components/Signup';
import Login from './components/Login';
import ReportProduct from './components/ReportProduct';
import ReportFoundItem from './components/ReportFoundItem';
import ReportedProducts from './components/ReportedProducts';

function Home() {
  return (
    <div className="min-h-screen bg-gradient-to-b from-white to-gray-50">
      {/* Hero Section */}
      <div className="container mx-auto px-4 py-20">
        <div className="text-center max-w-4xl mx-auto">
          <h1 className="text-6xl font-bold text-[#2D2654] mb-6 leading-tight">
            Lost Something?
            <br />
            <span className="bg-clip-text text-transparent bg-gradient-to-r from-[#2D2654] to-[#6B5B95]">
              We'll Help You Find It
            </span>
          </h1>
          <p className="text-xl text-gray-600 mb-12 max-w-2xl mx-auto">
            Connect with your community to find lost items or help others recover theirs. Our platform makes it easy to report, search, and reunite items with their owners.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center mb-16">
            <Link 
              to="/report-product"
              className="bg-[#2D2654] text-white px-8 py-4 rounded-full hover:bg-[#3d3470] transition transform hover:scale-105 shadow-lg flex items-center justify-center gap-2 text-lg font-medium"
            >
              <Search className="w-5 h-5" />
              Report Lost Item
            </Link>
            <Link
              to="/report-found-item"
              className="border-2 border-[#2D2654] text-[#2D2654] px-8 py-4 rounded-full hover:bg-gray-50 transition transform hover:scale-105 shadow-lg flex items-center justify-center gap-2 text-lg font-medium"
            >
              <MapPin className="w-5 h-5" />
              Report Found Item
            </Link>
          </div>
        </div>

        {/* Features Section */}
        <div className="grid md:grid-cols-3 gap-8 mt-20">
          <div className="bg-white p-8 rounded-2xl shadow-lg hover:shadow-xl transition transform hover:-translate-y-1">
            <div className="w-14 h-14 bg-[#2D2654] rounded-full flex items-center justify-center mb-6">
              <Bell className="w-7 h-7 text-white" />
            </div>
            <h3 className="text-xl font-bold text-[#2D2654] mb-4">Quick Reporting</h3>
            <p className="text-gray-600">
              Easy-to-use interface for reporting lost or found items. Get your listing up in minutes.
            </p>
          </div>

          <div className="bg-white p-8 rounded-2xl shadow-lg hover:shadow-xl transition transform hover:-translate-y-1">
            <div className="w-14 h-14 bg-[#2D2654] rounded-full flex items-center justify-center mb-6">
              <Shield className="w-7 h-7 text-white" />
            </div>
            <h3 className="text-xl font-bold text-[#2D2654] mb-4">Secure Communication</h3>
            <p className="text-gray-600">
              Safe and private messaging system to connect with item owners or finders.
            </p>
          </div>

          <div className="bg-white p-8 rounded-2xl shadow-lg hover:shadow-xl transition transform hover:-translate-y-1">
            <div className="w-14 h-14 bg-[#2D2654] rounded-full flex items-center justify-center mb-6">
              <HelpCircle className="w-7 h-7 text-white" />
            </div>
            <h3 className="text-xl font-bold text-[#2D2654] mb-4">Community Support</h3>
            <p className="text-gray-600">
              Join a helpful community dedicated to reuniting lost items with their owners.
            </p>
          </div>
        </div>

        {/* CTA Section */}
        <div className="mt-20 text-center">
          <Link 
            to="/reported-products"
            className="inline-flex items-center gap-2 bg-gradient-to-r from-[#2D2654] to-[#6B5B95] text-white px-10 py-5 rounded-full hover:opacity-90 transition transform hover:scale-105 shadow-lg text-lg font-medium"
          >
            View All Reported Items
          </Link>
        </div>
      </div>
    </div>
  );
}

function Navigation({ user, onLogout }: { user: any; onLogout: () => void }) {
  return (
    <nav className="bg-[#2D2654] p-4 sticky top-0 z-50">
      <div className="container mx-auto flex justify-between items-center">
        <Link to="/" className="text-white text-2xl font-semibold">Lost and Found</Link>
        <div className="flex items-center space-x-4">
          {user ? (
            <>
              <span className="text-white">
                Welcome, {user.user_metadata.first_name || 'User'}!
              </span>
              <button
                onClick={onLogout}
                className="flex items-center gap-2 text-white hover:text-gray-200 bg-[#3d3470] px-4 py-2 rounded-full transition"
              >
                <LogOut className="w-4 h-4" />
                Logout
              </button>
            </>
          ) : (
            <>
              <Link to="/signup" className="text-white hover:text-gray-200">Sign-up</Link>
              <Link to="/login" className="text-white hover:text-gray-200">Log-in</Link>
            </>
          )}
        </div>
      </div>
    </nav>
  );
}

function Footer() {
  return (
    <footer className="bg-[#2D2654] text-white py-4 text-center">
      <a href="https://divyanshujaiswal.in.net/">Made with ❤️ by Divyanshu Jaiswal</a>
    </footer>
  );
}

function App() {
  const [user, setUser] = useState<any>(null);

  useEffect(() => {
    // Check current auth status
    supabase.auth.getSession().then(({ data: { session } }) => {
      setUser(session?.user ?? null);
    });

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null);
    });

    return () => subscription.unsubscribe();
  }, []);

  const handleLogout = async () => {
    try {
      await supabase.auth.signOut();
      setUser(null);
    } catch (error) {
      console.error('Error logging out:', error);
    }
  };

  return (
    <Router>
      <div className="min-h-screen flex flex-col">
        <Navigation user={user} onLogout={handleLogout} />
        <main className="flex-grow">
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/signup" element={<Signup />} />
            <Route path="/login" element={<Login />} />
            <Route path="/report-product" element={<ReportProduct />} />
            <Route path="/report-found-item" element={<ReportFoundItem />} />
            <Route path="/reported-products" element={<ReportedProducts />} />
          </Routes>
        </main>
        <Footer />
      </div>
    </Router>
  );
}

export default App;