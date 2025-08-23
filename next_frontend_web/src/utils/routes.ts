import { ROLES } from '../types';

export const getInitialRoute = (hasRole: (roles: number | number[]) => boolean): string => {
  if (hasRole([ROLES.SUPER_ADMIN, ROLES.ADMIN, ROLES.MANAGER])) return '/dashboard';
  if (hasRole(ROLES.SALES)) return '/sales';
  if (hasRole(ROLES.INVENTORY)) return '/inventory';
  if (hasRole(ROLES.HR)) return '/hr';
  if (hasRole(ROLES.ACCOUNTANT)) return '/accounting';
  return '/dashboard';
};
