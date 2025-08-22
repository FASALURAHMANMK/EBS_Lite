import api from './apiClient';
import { AttendanceRecord } from '../types';

export const checkIn = (employeeId: string) =>
  api.post('/api/v1/attendance/check-in', { employeeId });

export const checkOut = (employeeId: string) =>
  api.post('/api/v1/attendance/check-out', { employeeId });

export const applyLeave = (payload: {
  employeeId: string;
  startDate: string;
  endDate: string;
  reason?: string;
}) => api.post('/api/v1/attendance/leave', payload);

export const getHolidays = () =>
  api.get<string[]>('/api/v1/attendance/holidays');

export interface AttendanceQuery {
  employeeId?: string;
  startDate?: string;
  endDate?: string;
}

export const getAttendanceRecords = (query: AttendanceQuery = {}) => {
  const params = new URLSearchParams();
  if (query.employeeId) params.append('employee_id', query.employeeId);
  if (query.startDate) params.append('start_date', query.startDate);
  if (query.endDate) params.append('end_date', query.endDate);
  const qs = params.toString();
  return api.get<AttendanceRecord[]>(`/api/v1/attendance/records${qs ? `?${qs}` : ''}`);
};
