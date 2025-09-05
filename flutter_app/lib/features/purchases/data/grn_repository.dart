import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../dashboard/controllers/location_notifier.dart';
import '../../inventory/data/inventory_repository.dart';
import 'models.dart';

class GrnRepository {
  GrnRepository(this._dio, this._ref);
  final Dio _dio;
  final Ref _ref;

  int? get _locationId => _ref.read(locationNotifierProvider).selected?.locationId;

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
    if (search != null && search.trim().isNotEmpty) qp['search'] = search.trim();
    final res = await _dio.get('/goods-receipts', queryParameters: qp.isEmpty ? null : qp);
    final data = _extractList(res);
    return data.map((e) => GoodsReceiptDto.fromJson(e as Map<String, dynamic>)).toList();
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
  }) async {
    // 1) Create purchase
    final createBody = {
      'supplier_id': supplierId,
      if (_locationId != null) 'location_id': _locationId,
      if (invoiceNumber != null && invoiceNumber.isNotEmpty) 'reference_number': invoiceNumber,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'items': [
        for (final it in items)
          {
            'product_id': it.productId,
            'quantity': it.quantity,
            'unit_price': it.unitPrice,
            if (it.taxId != null) 'tax_id': it.taxId,
            if (it.discountPercent != null) 'discount_percentage': it.discountPercent,
            if (it.discountAmount != null) 'discount_amount': it.discountAmount,
          }
      ]
    };
    final createRes = await _dio.post('/purchases/quick', data: createBody);
    final created = (createRes.data is Map && createRes.data['data'] != null) ? createRes.data['data'] as Map<String, dynamic> : (createRes.data as Map<String, dynamic>);
    final purchaseId = created['purchase_id'] as int;

    // 2) Fetch purchase details to map to purchase_detail_id
    final purRes = await _dio.get('/purchases/$purchaseId');
    final details = ((purRes.data['data'] as Map<String, dynamic>)['items'] as List).cast<Map<String, dynamic>>();

    // Build receive items by matching product_id
    final receiveItems = <Map<String, dynamic>>[];
    for (final it in items) {
      final match = details.firstWhere(
        (d) => (d['product_id'] as int) == it.productId,
        orElse: () => const {},
      );
      final pdid = match['purchase_detail_id'] as int?;
      if (pdid == null) continue;
      receiveItems.add({
        'purchase_detail_id': pdid,
        'received_quantity': it.quantity,
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
