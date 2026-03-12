import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api_client.dart';
import '../../../core/outbox/outbox_item.dart';
import '../../../core/outbox/outbox_notifier.dart';
import '../../dashboard/controllers/location_notifier.dart';
import 'models.dart';

class GrnRepository {
  GrnRepository(this._dio, this._ref);
  final Dio _dio;
  final Ref _ref;

  int? get _locationId =>
      _ref.read(locationNotifierProvider).selected?.locationId;

  List<dynamic> _extractList(Response res) {
    final body = res.data;
    if (body is List) return body;
    if (body is Map) {
      final value = body['data'];
      if (value is List) return value;
      return const [];
    }
    return const [];
  }

  Future<List<GoodsReceiptDto>> getGoodsReceipts({String? search}) async {
    final qp = <String, dynamic>{};
    final loc = _locationId;
    if (loc != null) qp['location_id'] = loc;
    if (search != null && search.trim().isNotEmpty) {
      qp['search'] = search.trim();
    }
    final res = await _dio.get('/goods-receipts',
        queryParameters: qp.isEmpty ? null : qp);
    final data = _extractList(res);
    return data
        .map((e) => GoodsReceiptDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GoodsReceiptDetailDto> getGoodsReceipt(int id) async {
    final res = await _dio.get('/goods-receipts/$id');
    final body = res.data is Map && (res.data['data'] != null)
        ? res.data['data'] as Map<String, dynamic>
        : res.data as Map<String, dynamic>;
    return GoodsReceiptDetailDto.fromJson(body);
  }

  // Creates a purchase without PO and immediately records a GRN against it.
  // Returns the created purchaseId.
  Future<int> createGrnWithoutPo({
    required int supplierId,
    required List<GrnCreateItem> items,
    String? invoiceNumber,
    String? notes,
    String? invoiceFilePath, // local file path to upload
    double? paidAmount,
    int? paymentMethodId,
  }) async {
    // 1) Create purchase
    final itemMaps = [
      for (final it in items)
        {
          'product_id': it.productId,
          if (it.barcodeId != null && it.barcodeId! > 0)
            'barcode_id': it.barcodeId,
          'quantity': it.quantity,
          'unit_price': it.unitPrice,
          if (it.serialNumbers.isNotEmpty) 'serial_numbers': it.serialNumbers,
          if ((it.batchNumber ?? '').trim().isNotEmpty)
            'batch_number': it.batchNumber,
          if (it.expiryDate != null)
            'expiry_date': it.expiryDate!.toIso8601String(),
          if (it.taxId != null) 'tax_id': it.taxId,
          if (it.discountPercent != null)
            'discount_percentage': it.discountPercent,
          if (it.discountAmount != null) 'discount_amount': it.discountAmount,
        }
    ];
    final createBody = {
      'supplier_id': supplierId,
      if (_locationId != null) 'location_id': _locationId,
      if (invoiceNumber != null && invoiceNumber.isNotEmpty)
        'reference_number': invoiceNumber,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (paidAmount != null) 'paid_amount': paidAmount,
      if (paymentMethodId != null) 'payment_method_id': paymentMethodId,
      'items': itemMaps,
    };
    final outbox = _ref.read(outboxNotifierProvider.notifier);
    final idemKey = const Uuid().v4();
    final headers = {
      'Idempotency-Key': idemKey,
      'X-Idempotency-Key': idemKey,
    };
    if (!outbox.isOnline) {
      await outbox.enqueue(
        OutboxItem(
          type: 'purchase_quick_grn',
          method: 'POST',
          path: '/purchases/quick',
          headers: headers,
          body: createBody,
          meta: {
            'create_body': createBody,
            'items': itemMaps,
            'invoice_file_path': invoiceFilePath,
          },
          idempotencyKey: idemKey,
        ),
      );
      throw OutboxQueuedException('Purchase queued for sync');
    }

    Response createRes;
    try {
      createRes = await _dio.post(
        '/purchases/quick',
        data: createBody,
        options: Options(headers: headers),
      );
    } on DioException catch (e) {
      if (outbox.isNetworkError(e)) {
        await outbox.enqueue(
          OutboxItem(
            type: 'purchase_quick_grn',
            method: 'POST',
            path: '/purchases/quick',
            headers: headers,
            body: createBody,
            meta: {
              'create_body': createBody,
              'items': itemMaps,
              'invoice_file_path': invoiceFilePath,
            },
            idempotencyKey: idemKey,
          ),
        );
        throw OutboxQueuedException('Purchase queued for sync');
      }
      rethrow;
    }
    final created = (createRes.data is Map && createRes.data['data'] != null)
        ? createRes.data['data'] as Map<String, dynamic>
        : (createRes.data as Map<String, dynamic>);
    final purchaseId = created['purchase_id'] as int;

    // 2) Fetch purchase details to map to purchase_detail_id
    final purRes = await _dio.get('/purchases/$purchaseId');
    final details =
        ((purRes.data['data'] as Map<String, dynamic>)['items'] as List)
            .cast<Map<String, dynamic>>();

    // Build receive items in the same order as the create request. This purchase
    // was just created, so detail order is the only reliable mapping when the
    // same product can appear on multiple barcode-based lines.
    final receiveItems = <Map<String, dynamic>>[];
    final limit = items.length < details.length ? items.length : details.length;
    for (var index = 0; index < limit; index++) {
      final it = items[index];
      final pdid = details[index]['purchase_detail_id'] as int?;
      if (pdid == null) continue;
      receiveItems.add({
        'purchase_detail_id': pdid,
        if (it.barcodeId != null && it.barcodeId! > 0)
          'barcode_id': it.barcodeId,
        'received_quantity': it.quantity,
        if (it.serialNumbers.isNotEmpty) 'serial_numbers': it.serialNumbers,
        if ((it.batchNumber ?? '').trim().isNotEmpty)
          'batch_number': it.batchNumber,
        if (it.expiryDate != null)
          'expiry_date': it.expiryDate!.toIso8601String(),
      });
    }

    // 3) Record goods receipt
    await _dio.post('/goods-receipts', data: {
      'purchase_id': purchaseId,
      'items': receiveItems,
    });

    // 4) Optionally upload invoice file
    if (invoiceFilePath != null && invoiceFilePath.isNotEmpty) {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(invoiceFilePath),
      });
      await _dio.post('/purchases/$purchaseId/invoice', data: form);
    }

    return purchaseId;
  }
}

final grnRepositoryProvider = Provider<GrnRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return GrnRepository(dio, ref);
});
