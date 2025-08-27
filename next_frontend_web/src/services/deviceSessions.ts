import api from './apiClient';
import { DeviceSession } from '../types';

export const getDeviceSessions = () =>
  api.get<DeviceSession[]>('/api/v1/device-sessions');

export const revokeDeviceSession = (sessionId: string) =>
  api.delete<DeviceSession>(`/api/v1/device-sessions/${sessionId}`);
