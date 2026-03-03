import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/file_transfer.dart';

class ImportExportRepository {
  ImportExportRepository(this._dio);
  final Dio _dio;

  Future<int?> importCustomers({
    required String filePath,
    required String filename,
  }) async {
    final res = await _dio.post(
      '/customers/import',
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: filename),
      }),
    );
    final body = res.data;
    if (body is Map && body['data'] is Map) {
      final d = body['data'] as Map;
      final count = d['count'];
      if (count is int) return count;
      if (count is num) return count.toInt();
    }
    return null;
  }

  Future<int?> importSuppliers({
    required String filePath,
    required String filename,
  }) async {
    final res = await _dio.post(
      '/suppliers/import',
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: filename),
      }),
    );
    final body = res.data;
    if (body is Map && body['data'] is Map) {
      final d = body['data'] as Map;
      final count = d['count'];
      if (count is int) return count;
      if (count is num) return count.toInt();
    }
    return null;
  }

  Future<void> importInventory({
    required String filePath,
    required String filename,
  }) async {
    await _dio.post(
      '/inventory/import',
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: filename),
      }),
    );
  }

  Future<void> exportCustomers() async {
    const filename = 'customers.xlsx';
    final bytes = await FileTransfer.downloadBytes(_dio, '/customers/export');
    final path = await FileTransfer.saveToTemp(bytes, filename);
    await FileTransfer.shareTempFile(
      filePath: path,
      filename: filename,
      mimeType: FileTransfer.guessMimeTypeFromFilename(filename) ??
          'application/octet-stream',
      subject: 'Customers export',
      text: 'Customers export attached.',
    );
  }

  Future<void> exportSuppliers() async {
    const filename = 'suppliers.xlsx';
    final bytes = await FileTransfer.downloadBytes(_dio, '/suppliers/export');
    final path = await FileTransfer.saveToTemp(bytes, filename);
    await FileTransfer.shareTempFile(
      filePath: path,
      filename: filename,
      mimeType: FileTransfer.guessMimeTypeFromFilename(filename) ??
          'application/octet-stream',
      subject: 'Suppliers export',
      text: 'Suppliers export attached.',
    );
  }

  Future<void> exportInventory() async {
    const filename = 'inventory.xlsx';
    final bytes = await FileTransfer.downloadBytes(_dio, '/inventory/export');
    final path = await FileTransfer.saveToTemp(bytes, filename);
    await FileTransfer.shareTempFile(
      filePath: path,
      filename: filename,
      mimeType: FileTransfer.guessMimeTypeFromFilename(filename) ??
          'application/octet-stream',
      subject: 'Inventory export',
      text: 'Inventory export attached.',
    );
  }
}

final importExportRepositoryProvider = Provider<ImportExportRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ImportExportRepository(dio);
});
