import React from 'react';

const FAQPage: React.FC = () => (
  <div className="max-w-3xl mx-auto p-6">
    <h1 className="text-2xl font-bold mb-4">Frequently Asked Questions</h1>
    <div className="space-y-4">
      <div>
        <h2 className="font-semibold">How do I contact support?</h2>
        <p>You can reach out through the contact form available on the support page.</p>
      </div>
      <div>
        <h2 className="font-semibold">Where can I learn more about the application?</h2>
        <p>Check the documentation and guides provided in the help section.</p>
      </div>
    </div>
  </div>
);

export default FAQPage;
