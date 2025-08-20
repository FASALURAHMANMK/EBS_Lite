import React from 'react';
import POSBase from './POSBase';

interface ModernPOSProps {
  mode?: 'sale' | 'return';
}

const ModernPOS: React.FC<ModernPOSProps> = ({ mode }) => (
  <POSBase variant="modern" mode={mode} />
);

export default ModernPOS;
