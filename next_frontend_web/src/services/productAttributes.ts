import api from './apiClient';
import { ProductAttributeDefinition } from '../types';

export const getAttributeDefinitions = () =>
  api.get<ProductAttributeDefinition[]>('/api/v1/product-attribute-definitions');

export const createAttributeDefinition = (
  payload: Partial<ProductAttributeDefinition>
) =>
  api.post<ProductAttributeDefinition>(
    '/api/v1/product-attribute-definitions',
    payload
  );

export const updateAttributeDefinition = (
  id: string,
  payload: Partial<ProductAttributeDefinition>
) =>
  api.put<ProductAttributeDefinition>(
    `/api/v1/product-attribute-definitions/${id}`,
    payload
  );

export const deleteAttributeDefinition = (id: string) =>
  api.delete<void>(
    `/api/v1/product-attribute-definitions/${id}`
  );
