import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/router';
import { useAuth } from '../../context/AuthContext';
import { Eye, EyeOff, Building, AlertCircle, CheckCircle } from 'lucide-react';

const RegisterPage: React.FC = () => {
    const { state, register, clearError } = useAuth();
    const router = useRouter();
    const [currentStep, setCurrentStep] = useState(1);
    const [showPassword, setShowPassword] = useState(false);
    const [showConfirmPassword, setShowConfirmPassword] = useState(false);
   const [formData, setFormData] = useState({
  // User Information
  username: '',
  email: '',
  password: '',
  confirmPassword: '',
  fullName: '',
  
  // Company Information
  companyName: '',
  companyAddress: '',
  companyPhone: '',
  companyEmail: '',
  
  // Location Information
  locationName: '',
  locationPhone: '',
  locationEmail: '',
  
  // Agreement
  agreeToTerms: false
});
  
    useEffect(() => {
      clearError();
    }, []);
  
    const handleSubmit = async (e: React.FormEvent) => {
      e.preventDefault();
      
      if (formData.password !== formData.confirmPassword) {
        // Handle password mismatch error
        return;
      }
  
      try {
        const { confirmPassword, agreeToTerms, ...registrationData } = formData;
        await register(registrationData);
      } catch (error) {
        // Error is handled by the context
      }
    };
  
    const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
      const { name, value, type } = e.target;
      const checked = type === 'checkbox' ? (e.target as HTMLInputElement).checked : undefined;
      
      setFormData(prev => ({
        ...prev,
        [name]: type === 'checkbox' ? checked : value
      }));
    };
  
    const nextStep = () => {
      if (currentStep < 3) {
        setCurrentStep(currentStep + 1);
      }
    };
  
    const prevStep = () => {
      if (currentStep > 1) {
        setCurrentStep(currentStep - 1);
      }
    };
  
    const isStepValid = () => {
  switch (currentStep) {
    case 1:
      return formData.fullName && formData.username && formData.email;
    case 2:
      return formData.password && formData.confirmPassword && formData.password === formData.confirmPassword;
    case 3:
      return formData.companyName && formData.companyAddress && formData.companyPhone && 
             formData.companyEmail && formData.locationName && formData.agreeToTerms;
    default:
      return false;
  }
};
  
    const renderStepContent = () => {
      switch (currentStep) {
        case 1:
          return (
            <div className="space-y-6">
              <div>
                <label htmlFor="fullName" className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Full Name
                </label>
                <input
                  id="fullName"
                  name="fullName"
                  type="text"
                  required
                  value={formData.fullName}
                  onChange={handleInputChange}
                  className="w-full px-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                  placeholder="Enter your full name"
                />
              </div>
  
              <div>
                <label htmlFor="username" className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Username
                </label>
                <input
                  id="username"
                  name="username"
                  type="text"
                  required
                  value={formData.username}
                  onChange={handleInputChange}
                  className="w-full px-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                  placeholder="Choose a username"
                />
              </div>
  
              <div>
                <label htmlFor="email" className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Email Address
                </label>
                <input
                  id="email"
                  name="email"
                  type="email"
                  required
                  value={formData.email}
                  onChange={handleInputChange}
                  className="w-full px-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                  placeholder="Enter your email address"
                />
              </div>
            </div>
          );
  
        case 2:
          return (
            <div className="space-y-6">
              <div>
                <label htmlFor="password" className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Password
                </label>
                <div className="relative">
                  <input
                    id="password"
                    name="password"
                    type={showPassword ? 'text' : 'password'}
                    required
                    value={formData.password}
                    onChange={handleInputChange}
                    className="w-full pr-10 pl-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                    placeholder="Create a strong password"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute inset-y-0 right-0 pr-3 flex items-center"
                  >
                    {showPassword ? (
                      <EyeOff className="h-5 w-5 text-gray-400 hover:text-gray-600" />
                    ) : (
                      <Eye className="h-5 w-5 text-gray-400 hover:text-gray-600" />
                    )}
                  </button>
                </div>
              </div>
  
              <div>
                <label htmlFor="confirmPassword" className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Confirm Password
                </label>
                <div className="relative">
                  <input
                    id="confirmPassword"
                    name="confirmPassword"
                    type={showConfirmPassword ? 'text' : 'password'}
                    required
                    value={formData.confirmPassword}
                    onChange={handleInputChange}
                    className="w-full pr-10 pl-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                    placeholder="Confirm your password"
                  />
                  <button
                    type="button"
                    onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                    className="absolute inset-y-0 right-0 pr-3 flex items-center"
                  >
                    {showConfirmPassword ? (
                      <EyeOff className="h-5 w-5 text-gray-400 hover:text-gray-600" />
                    ) : (
                      <Eye className="h-5 w-5 text-gray-400 hover:text-gray-600" />
                    )}
                  </button>
                </div>
                {formData.confirmPassword && formData.password !== formData.confirmPassword && (
                  <p className="text-red-500 text-sm mt-1">Passwords do not match</p>
                )}
              </div>
  
              <div className="bg-gray-50 dark:bg-gray-800 p-4 rounded-lg">
                <p className="text-sm text-gray-600 dark:text-gray-400 mb-2">Password requirements:</p>
                <ul className="text-xs text-gray-500 dark:text-gray-500 space-y-1">
                  <li>• At least 8 characters long</li>
                  <li>• Contains uppercase and lowercase letters</li>
                  <li>• Contains at least one number</li>
                  <li>• Contains at least one special character</li>
                </ul>
              </div>
            </div>
          );
  
        case 3:
  return (
    <div className="space-y-6">
      <div>
        <label htmlFor="companyName" className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Company Name *
        </label>
        <input
          id="companyName"
          name="companyName"
          type="text"
          required
          value={formData.companyName}
          onChange={handleInputChange}
          className="w-full px-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
          placeholder="Enter your company name"
        />
      </div>

      <div>
        <label htmlFor="companyAddress" className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Company Address *
        </label>
        <textarea
          id="companyAddress"
          name="companyAddress"
          required
          value={formData.companyAddress}
          onChange={handleInputChange}
          rows={3}
          className="w-full px-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
          placeholder="Enter your company address"
        />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label htmlFor="companyPhone" className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            Company Phone *
          </label>
          <input
            id="companyPhone"
            name="companyPhone"
            type="tel"
            required
            value={formData.companyPhone}
            onChange={handleInputChange}
            className="w-full px-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
            placeholder="Company phone"
          />
        </div>

        <div>
          <label htmlFor="companyEmail" className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            Company Email *
          </label>
          <input
            id="companyEmail"
            name="companyEmail"
            type="email"
            required
            value={formData.companyEmail}
            onChange={handleInputChange}
            className="w-full px-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
            placeholder="Company email"
          />
        </div>
      </div>

      {/* Add Location Information Section */}
      <div className="border-t border-gray-200 dark:border-gray-700 pt-4">
        <h4 className="text-md font-medium text-gray-800 dark:text-white mb-4">Main Location Details</h4>
        
        <div>
          <label htmlFor="locationName" className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            Location Name *
          </label>
          <input
            id="locationName"
            name="locationName"
            type="text"
            required
            value={formData.locationName}
            onChange={handleInputChange}
            className="w-full px-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
            placeholder="e.g., Main Store, Head Office"
          />
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
          <div>
            <label htmlFor="locationPhone" className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Location Phone
            </label>
            <input
              id="locationPhone"
              name="locationPhone"
              type="tel"
              value={formData.locationPhone}
              onChange={handleInputChange}
              className="w-full px-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
              placeholder="Location phone (optional)"
            />
          </div>

          <div>
            <label htmlFor="locationEmail" className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Location Email
            </label>
            <input
              id="locationEmail"
              name="locationEmail"
              type="email"
              value={formData.locationEmail}
              onChange={handleInputChange}
              className="w-full px-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
              placeholder="Location email (optional)"
            />
          </div>
        </div>
      </div>

      <div className="flex items-center">
        <input
          id="agreeToTerms"
          name="agreeToTerms"
          type="checkbox"
          checked={formData.agreeToTerms}
          onChange={handleInputChange}
          className="h-4 w-4 text-red-600 focus:ring-red-500 border-gray-300 rounded"
        />
        <label htmlFor="agreeToTerms" className="ml-2 block text-sm text-gray-700 dark:text-gray-300">
          I agree to the{' '}
          <a href="#" className="text-red-600 hover:text-red-500">Terms of Service</a>
          {' '}and{' '}
          <a href="#" className="text-red-600 hover:text-red-500">Privacy Policy</a>
        </label>
      </div>
    </div>
  );
        default:
          return null;
      }
    };
  
    return (
      <div className="min-h-screen bg-gradient-to-br from-red-50 to-red-100 dark:from-gray-900 dark:to-gray-800 flex items-center justify-center p-4">
        <div className="w-full max-w-lg">
          {/* Logo and Header */}
          <div className="text-center mb-8">
            <div className="w-16 h-16 bg-gradient-to-r from-red-500 to-red-600 rounded-2xl flex items-center justify-center mx-auto mb-4 shadow-lg">
              <Building className="w-8 h-8 text-white" />
            </div>
            <h1 className="text-3xl font-bold text-gray-800 dark:text-white mb-2">Create Account</h1>
            <p className="text-gray-600 dark:text-gray-400">Set up your business account</p>
          </div>
  
          {/* Progress Steps */}
          <div className="mb-8">
            <div className="flex items-center justify-center space-x-4">
              {[1, 2, 3].map((step) => (
                <div key={step} className="flex items-center">
                  <div className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium ${
                    step <= currentStep 
                      ? 'bg-red-600 text-white' 
                      : 'bg-gray-200 dark:bg-gray-700 text-gray-500'
                  }`}>
                    {step < currentStep ? (
                      <CheckCircle className="w-5 h-5" />
                    ) : (
                      step
                    )}
                  </div>
                  {step < 3 && (
                    <div className={`w-8 h-0.5 ${
                      step < currentStep ? 'bg-red-600' : 'bg-gray-200 dark:bg-gray-700'
                    }`} />
                  )}
                </div>
              ))}
            </div>
            <div className="flex justify-center mt-2">
              <span className="text-sm text-gray-500">
                Step {currentStep} of 3
              </span>
            </div>
          </div>
  
          {/* Registration Form */}
          <div className="bg-white dark:bg-gray-900 rounded-2xl shadow-xl p-8 border border-gray-200 dark:border-gray-700">
            {state.error && (
              <div className="mb-6 p-4 bg-red-50 dark:bg-red-900/30 border border-red-200 dark:border-red-800 rounded-lg flex items-center space-x-3">
                <AlertCircle className="w-5 h-5 text-red-500" />
                <span className="text-red-700 dark:text-red-300 text-sm">{state.error}</span>
              </div>
            )}
  
            <form onSubmit={handleSubmit}>
              {renderStepContent()}
  
              {/* Navigation Buttons */}
              <div className="flex justify-between mt-8">
                <button
                  type="button"
                  onClick={prevStep}
                  disabled={currentStep === 1}
                  className="px-4 py-2 text-gray-600 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  Previous
                </button>
  
                {currentStep === 3 ? (
                  <button
                    type="submit"
                    disabled={!isStepValid() || state.loading}
                    className="px-6 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-2"
                  >
                    {state.loading ? (
                      <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                    ) : (
                      <>
                        <span>Create Account</span>
                        <CheckCircle className="w-4 h-4" />
                      </>
                    )}
                  </button>
                ) : (
                  <button
                    type="button"
                    onClick={nextStep}
                    disabled={!isStepValid()}
                    className="px-6 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    Next
                  </button>
                )}
              </div>
            </form>
  
            {/* Login Link */}
            <div className="mt-6 text-center">
              <span className="text-gray-600 dark:text-gray-400 text-sm">
                Already have an account?{' '}
                <button
                  className="text-red-600 hover:text-red-500 dark:text-red-400 dark:hover:text-red-300 font-medium"
                  onClick={() => router.push('/login')}
                >
                  Sign in
                </button>
              </span>
            </div>
          </div>
        </div>
      </div>
    );
  };
  
  export { RegisterPage };