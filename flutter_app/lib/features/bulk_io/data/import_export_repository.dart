import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/file_transfer.dart';

class ImportExportRepository {
  ImportExportRepository(this._dio);
  final Dio _dio;

  Future<void> _downloadAndShare({
    required String endpoint,
    required String filename,
    required String subject,
    required String text,
  }) async {
    final bytes = await FileTransfer.downloadBytes(_dio, endpoint);
    final path = await FileTransfer.saveToTemp(bytes, filename);
    await FileTransfer.shareTempFile(
      filePath: path,
      filename: filename,
      mimeType: FileTransfer.guessMimeTypeFromFilename(filename) ??
          'application/octet-stream',
      subject: subject,
      text: text,
    );
  }

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

  Future<Map<String, int>?> importInventory({
    required String filePath,
    required String filename,
  }) async {
    final res = await _dio.post(
      '/inventory/import',
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: filename),
      }),
    );
    final body = res.data;
    if (body is Map && body['data'] is Map) {
      final d = body['data'] as Map;
      int? toInt(dynamic v) {
        if (v is int) return v;
        if (v is num) return v.toInt();
        return null;
      }

      final created = toInt(d['created']) ?? toInt(d['count']);
      final updated = toInt(d['updated']);
      final skipped = toInt(d['skipped']);
      final errors =
          (d['errors'] is List) ? (d['errors'] as List).length : null;
      return {
        if (created != null) 'created': created,
        if (updated != null) 'updated': updated,
        if (skipped != null) 'skipped': skipped,
        if (errors != null) 'errors': errors,
      };
    }
    return null;
  }

  Future<void> exportCustomers() async {
    await _downloadAndShare(
      endpoint: '/customers/export',
      filename: 'customers.xlsx',
      subject: 'Customers export',
      text: 'Customers export attached.',
    );
  }

  Future<void> exportSuppliers() async {
    await _downloadAndShare(
      endpoint: '/suppliers/export',
      filename: 'suppliers.xlsx',
      subject: 'Suppliers export',
      text: 'Suppliers export attached.',
    );
  }

  Future<void> exportInventory() async {
    await _downloadAndShare(
      endpoint: '/inventory/export',
      filename: 'inventory.xlsx',
      subject: 'Inventory export',
      text: 'Inventory export attached.',
    );
  }

  Future<void> downloadCustomersTemplate() async {
    await _downloadAndShare(
      endpoint: '/customers/import-template',
      filename: 'customers_template.xlsx',
      subject: 'Customers import template',
      text: 'Fill this template and upload it in Import.',
    );
  }

  Future<void> downloadCustomersExample() async {
    await _downloadAndShare(
      endpoint: '/customers/import-example',
      filename: 'customers_example.xlsx',
      subject: 'Customers import example',
      text: 'Example file attached.',
    );
  }

  Future<void> downloadSuppliersTemplate() async {
    await _downloadAndShare(
      endpoint: '/suppliers/import-template',
      filename: 'suppliers_template.xlsx',
      subject: 'Suppliers import template',
      text: 'Fill this template and upload it in Import.',
    );
  }

  Future<void> downloadSuppliersExample() async {
    await _downloadAndShare(
      endpoint: '/suppliers/import-example',
      filename: 'suppliers_example.xlsx',
      subject: 'Suppliers import example',
      text: 'Example file attached.',
    );
  }

  Future<void> downloadInventoryTemplate() async {
    await _downloadAndShare(
      endpoint: '/inventory/import-template',
      filename: 'inventory_template.xlsx',
      subject: 'Inventory import template',
      text: 'Fill this template and upload it in Import.',
    );
  }

  Future<void> downloadInventoryExample() async {
    await _downloadAndShare(
      endpoint: '/inventory/import-example',
      filename: 'inventory_example.xlsx',
      subject: 'Inventory import example',
      text: 'Example file attached.',
    );
  }
}

final importExportRepositoryProvider = Provider<ImportExportRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ImportExportRepository(dio);
});
