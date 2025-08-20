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

export interface LedgerEntry {
  id: number;
  accountId: number;
  accountName: string;
  debit: number;
  credit: number;
  balance: number;
  entryDate: string;
}
