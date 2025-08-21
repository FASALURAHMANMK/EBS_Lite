export interface CashRegister {
  id: number;
  openingBalance: number;
  closingBalance?: number;
  openedAt: string;
  closedAt?: string;
}

export interface Voucher {
  id: number;
  type: string;
  amount: number;
  description?: string;
  createdAt: string;
}

export interface VoucherPayload {
  amount: number;
  description?: string;
}

export interface LedgerEntry {
  id: number;
  accountId: number;
  accountName: string;
  debit: number;
  credit: number;
  balance: number;
  entryDate: string;
}

export interface LedgerQueryPayload {
  accountId: number | string;
  dateFrom?: string;
  dateTo?: string;
}

export interface AccountBalance {
  accountId: number;
  accountName: string;
  balance: number;
}
