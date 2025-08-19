import React, { useState } from 'react';
import { useAppDispatch } from '../../../context/MainContext';
import { ShoppingCart, ShoppingBag, Banknote, CreditCard, Zap } from 'lucide-react';

interface QuickActionButtonProps {
  icon: React.ReactNode;
  label: string;
  onClick: () => void;
  color: string;
  position: number;
  isVisible: boolean;
}

const QuickActionButton: React.FC<QuickActionButtonProps> = ({
  icon,
  label,
  onClick,
  color,
  position,
  isVisible,
}) => {
  const angle = position * 45 - 200;
  const radius = 80;
  const x = Math.cos((angle * Math.PI) / 180) * radius;
  const y = Math.sin((angle * Math.PI) / 180) * radius;

  return (
    <button
      onClick={onClick}
      className={`absolute w-12 h-12 ${color} rounded-full shadow-lg hover:scale-110 transition-all duration-300 ease-in-out flex items-center justify-center group ${
        isVisible ? 'opacity-100 scale-100' : 'opacity-0 scale-0'
      }`}
      style={{
        transform: `translate(${x}px, ${y}px)`,
        transitionDelay: isVisible ? `${position * 50}ms` : '0ms',
      }}
      title={label}
    >
      {icon}
      <span className="absolute bottom-full mb-2 left-1/2 transform -translate-x-1/2 bg-gray-800 dark:bg-gray-700 text-white text-xs px-2 py-1 rounded opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap">
        {label}
      </span>
    </button>
  );
};

const QuickActionMenu: React.FC = () => {
  const dispatch = useAppDispatch();
  const [isOpen, setIsOpen] = useState(false);

  return (
    <div className="fixed bottom-8 right-8 z-50">
      <div className="relative">
        <QuickActionButton
          icon={<ShoppingCart className="w-5 h-5 text-white" />}
          label="Sale"
          onClick={() => dispatch({ type: 'SET_VIEW', payload: 'sales' })}
          color="bg-gradient-to-r from-red-500 to-red-600"
          position={0}
          isVisible={isOpen}
        />

        <QuickActionButton
          icon={<ShoppingBag className="w-5 h-5 text-white" />}
          label="Purchase"
          onClick={() => dispatch({ type: 'SET_VIEW', payload: 'purchase-entry' as any })}
          color="bg-gradient-to-r from-blue-500 to-blue-600"
          position={1}
          isVisible={isOpen}
        />

        <QuickActionButton
          icon={<Banknote className="w-5 h-5 text-white" />}
          label="Collection"
          onClick={() => dispatch({ type: 'SET_VIEW', payload: 'collectionss' as any })}
          color="bg-gradient-to-r from-green-500 to-green-600"
          position={2}
          isVisible={isOpen}
        />

        <QuickActionButton
          icon={<CreditCard className="w-5 h-5 text-white" />}
          label="Expense"
          onClick={() => dispatch({ type: 'SET_VIEW', payload: 'cash-register' as any })}
          color="bg-gradient-to-r from-purple-500 to-purple-600"
          position={3}
          isVisible={isOpen}
        />

        <button
          onClick={() => setIsOpen(!isOpen)}
          className={`w-16 h-16 bg-gradient-to-r from-orange-500 to-red-500 hover:from-orange-600 hover:to-red-600 rounded-full shadow-2xl flex items-center justify-center transition-all duration-300 ease-in-out transform hover:scale-110 ${
            isOpen ? 'rotate-45' : 'rotate-0'
          }`}
        >
          <Zap className="w-8 h-8 text-white" />
        </button>

        {isOpen && (
          <div
            className="fixed inset-0 bg-black/20 -z-10"
            onClick={() => setIsOpen(false)}
          />
        )}
      </div>
    </div>
  );
};

export default QuickActionMenu;
