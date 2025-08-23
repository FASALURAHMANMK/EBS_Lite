export const getInitialRoute = (hasRole: (roles: string | string[]) => boolean): string => {
  if (hasRole(['Admin', 'Manager', 'User'])) return '/dashboard';
  if (hasRole('Sales')) return '/sales';
  if (hasRole('Store')) return '/inventory';
  if (hasRole('HR')) return '/hr';
  if (hasRole('Accountant')) return '/accounting/ledger';
  return '/dashboard';
};
