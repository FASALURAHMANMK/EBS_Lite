import api from './apiClient';
import { CashRegister, Voucher, LedgerEntry } from '../types/accounting';

// Cash Register
export const getCashRegisters = () =>
  api.get<CashRegister[]>('/api/v1/cash-registers');

export const openCashRegister = (payload: { openingBalance: number }) =>
  api.post<{ registerId: number }>(
    '/api/v1/cash-registers/open',
    payload
  );

export const closeCashRegister = (payload: { closingBalance: number }) =>
  api.post<void>('/api/v1/cash-registers/close', payload);

export const recordCashTally = (payload: { count: number; notes?: string }) =>
  api.post<void>('/api/v1/cash-registers/tally', payload);

// Vouchers
export const listVouchers = () =>
  api.get<Voucher[]>('/api/v1/vouchers');

export const createVoucher = (type: string, payload: any) =>
  api.post<{ voucherId: number }>(`/api/v1/vouchers/${type}`, payload);

// Ledger
export const getLedgerBalances = () =>
  api.get<any[]>('/api/v1/ledgers');

export const getLedgerEntries = (
  accountId: number | string
) => api.get<LedgerEntry[]>(`/api/v1/ledgers/${accountId}/entries`);
