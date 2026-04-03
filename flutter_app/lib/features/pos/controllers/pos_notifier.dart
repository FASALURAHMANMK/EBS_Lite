import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/error_handler.dart';
import '../../../core/outbox/outbox_notifier.dart';
import '../../inventory/data/models.dart';
import '../data/models.dart';
import '../data/pos_repository.dart';
import '../../dashboard/data/payment_methods_repository.dart';

class PosState {
  final String? receiptPreview;
  final String? committedReceipt;
  final PosCustomerDto? customer;
  final String customerLabel;
  final String query;
  final List<PosProductDto> suggestions; // show top-2 only in UI
  final List<PosCartItem> cart;
  final double discount;
  final double tax; // computed via backend
  final bool isLoading;
  final String? error;
  final List<PaymentMethodDto> paymentMethods;
  final int? activeSaleId; // when resuming a held sale
  final String? sessionLabel;
  final String? sessionSourceSaleNumber;
  final SaleDto? editBaselineSale;

  const PosState({
    this.receiptPreview,
    this.committedReceipt,
    this.customer,
    this.customerLabel = 'Walk in',
    this.query = '',
    this.suggestions = const [],
    this.cart = const [],
    this.discount = 0.0,
    this.tax = 0.0,
    this.isLoading = false,
    this.error,
    this.paymentMethods = const [],
    this.activeSaleId,
    this.sessionLabel,
    this.sessionSourceSaleNumber,
    this.editBaselineSale,
  });

  double get subtotal => cart.fold(0.0, (s, i) => s + i.lineTotal);
  double get total => subtotal + tax - discount;
  bool get hasRefundLines => cart.any((item) => item.isRefundLine);
  bool get isEditingSale => editBaselineSale != null;

  PosState copyWith({
    String? receiptPreview,
    String? committedReceipt,
    PosCustomerDto? customer,
    String? customerLabel,
    String? query,
    List<PosProductDto>? suggestions,
    List<PosCartItem>? cart,
    double? discount,
    double? tax,
    bool? isLoading,
    String? error,
    List<PaymentMethodDto>? paymentMethods,
    int? activeSaleId,
    String? sessionLabel,
    String? sessionSourceSaleNumber,
    SaleDto? editBaselineSale,
    bool clearCommittedReceipt = false,
    bool clearActiveSaleId = false,
    bool clearCustomer = false,
    bool clearSession = false,
    bool clearEditBaselineSale = false,
  }) {
    return PosState(
      receiptPreview: receiptPreview ?? this.receiptPreview,
      committedReceipt: clearCommittedReceipt
          ? null
          : (committedReceipt ?? this.committedReceipt),
      customer: clearCustomer ? null : (customer ?? this.customer),
      customerLabel:
          clearCustomer ? 'Walk in' : (customerLabel ?? this.customerLabel),
      query: query ?? this.query,
      suggestions: suggestions ?? this.suggestions,
      cart: cart ?? this.cart,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      activeSaleId:
          clearActiveSaleId ? null : (activeSaleId ?? this.activeSaleId),
      sessionLabel: clearSession ? null : (sessionLabel ?? this.sessionLabel),
      sessionSourceSaleNumber: clearSession
          ? null
          : (sessionSourceSaleNumber ?? this.sessionSourceSaleNumber),
      editBaselineSale: clearEditBaselineSale
          ? null
          : (editBaselineSale ?? this.editBaselineSale),
    );
  }
}

class PosNotifier extends StateNotifier<PosState> {
  PosNotifier(this._repo) : super(const PosState());
  final PosRepository _repo;
  Timer? _debounce;
  String? _checkoutIdemKey;
  String? _holdIdemKey;

  Future<void> init() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final preview = await _repo.getNextReceiptPreview();
      final methods = await _repo.getPaymentMethods();
      state = state.copyWith(
        isLoading: false,
        receiptPreview: preview,
        paymentMethods: methods,
      );
      await _recalculateTotals();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: ErrorHandler.message(e));
    }
  }

  void setCustomer(PosCustomerDto? c) {
    state = state.copyWith(
      customer: c,
      customerLabel: c?.name ?? 'Walk in',
    );
  }

  void setDiscount(double value) {
    // Applying a total discount clears any line-item discounts
    if (value > 0) {
      final cleared = state.cart
          .map(
              (i) => i.discountPercent > 0 ? i.copyWith(discountPercent: 0) : i)
          .toList();
      state = state.copyWith(cart: cleared, discount: value);
    } else {
      state = state.copyWith(discount: value);
    }
    // ignore: unawaited_futures
    _recalculateTotals();
  }

  void setQuery(String q) {
    state = state.copyWith(query: q);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      await searchProducts(q);
    });
  }

  Future<void> searchProducts(String q) async {
    if (q.trim().isEmpty) {
      state = state.copyWith(suggestions: const []);
      return;
    }
    try {
      final list = await _repo.searchProducts(q);
      state = state.copyWith(suggestions: list);
    } catch (e) {
      state = state.copyWith(error: ErrorHandler.message(e));
    }
  }

  void addProduct(
    PosProductDto p, {
    double qty = 1,
    InventoryTrackingSelection? tracking,
    List<PosComboComponentTracking> comboTracking = const [],
  }) {
    final items = [...state.cart];
    final incoming = PosCartItem(
      product: p,
      quantity: qty,
      unitPrice: p.price,
      tracking: tracking,
      comboTracking: comboTracking,
    );
    // In refund/edit sessions, keep every scan/add as its own row so staff can
    // clearly distinguish replacement lines from refund lines.
    final sessionKeepsSeparateRows = state.hasRefundLines;
    final shouldMerge = !sessionKeepsSeparateRows && !incoming.requiresTracking;
    final idx = shouldMerge
        ? items.indexWhere((i) => i.identityKey == incoming.identityKey)
        : -1;
    if (idx >= 0) {
      items[idx] = items[idx].copyWith(quantity: items[idx].quantity + qty);
    } else {
      items.add(incoming);
    }
    state = state.copyWith(cart: items, query: '', suggestions: const []);
    // ignore: unawaited_futures
    _recalculateTotals();
  }

  void updateQty(PosCartItem item, double qty) {
    final items = state.cart
        .map((i) => i == item
            ? i.copyWith(quantity: qty, clearTracking: i.requiresTracking)
            : i)
        .toList();
    state = state.copyWith(cart: items);
    // ignore: unawaited_futures
    _recalculateTotals();
  }

  void setItemTracking(
    PosCartItem item,
    InventoryTrackingSelection? tracking,
  ) {
    final items = state.cart
        .map((i) => i == item ? i.copyWith(tracking: tracking) : i)
        .toList();
    state = state.copyWith(cart: items);
    // ignore: unawaited_futures
    _recalculateTotals();
  }

  void setItemComboTracking(
    PosCartItem item,
    List<PosComboComponentTracking> comboTracking,
  ) {
    final items = state.cart
        .map((i) => i == item ? i.copyWith(comboTracking: comboTracking) : i)
        .toList();
    state = state.copyWith(cart: items);
    // ignore: unawaited_futures
    _recalculateTotals();
  }

  void updateTrackedItem(
    PosCartItem item, {
    required double quantity,
    InventoryTrackingSelection? tracking,
    List<PosComboComponentTracking>? comboTracking,
  }) {
    final items = state.cart
        .map((i) => i == item
            ? i.copyWith(
                quantity: quantity,
                tracking: tracking,
                comboTracking: comboTracking,
              )
            : i)
        .toList();
    state = state.copyWith(cart: items);
    // ignore: unawaited_futures
    _recalculateTotals();
  }

  void removeItem(PosCartItem item) {
    final items = [...state.cart]..remove(item);
    state = state.copyWith(cart: items);
    // ignore: unawaited_futures
    _recalculateTotals();
  }

  void setItemDiscount(PosCartItem item, double percent) {
    final normalized = percent.clamp(0.0, 100.0);
    // Applying item-level discount disables total discount
    final items = state.cart
        .map((i) => i == item ? i.copyWith(discountPercent: normalized) : i)
        .toList();
    state = state.copyWith(cart: items, discount: 0.0);
    // ignore: unawaited_futures
    _recalculateTotals();
  }

  Future<PosCheckoutResult> processCheckout({
    required int? paymentMethodId,
    required double paidAmount,
    List<PosPaymentLineDto>? payments,
    double? redeemPoints,
    String? couponCode,
    bool? autoFillRaffleCustomerData,
    String? managerOverrideToken,
    String? overrideReason,
    String? salesActionPassword,
    String? overridePassword,
  }) async {
    _checkoutIdemKey ??= const Uuid().v4();
    try {
      final result = state.isEditingSale
          ? await _repo.editSale(
              baseline: state.editBaselineSale!,
              customerId: state.customer?.customerId,
              items: state.cart,
              paymentMethodId: paymentMethodId,
              paidAmount: paidAmount,
              discountAmount: state.discount,
              payments: payments,
              salesActionPassword: salesActionPassword,
              overridePassword: overridePassword,
              managerOverrideToken: managerOverrideToken,
              overrideReason: overrideReason,
            )
          : await _repo.checkout(
              customerId: state.customer?.customerId,
              items: state.cart,
              paymentMethodId: paymentMethodId,
              paidAmount: paidAmount,
              discountAmount: state.discount,
              saleId: state.activeSaleId,
              payments: payments,
              redeemPoints: redeemPoints,
              couponCode: couponCode,
              autoFillRaffleCustomerData: autoFillRaffleCustomerData,
              idempotencyKey: _checkoutIdemKey,
              managerOverrideToken: managerOverrideToken,
              overrideReason: overrideReason,
              salesActionPassword: salesActionPassword,
              overridePassword: overridePassword,
            );
      _checkoutIdemKey = null;
      final nextPreview = await _repo.getNextReceiptPreview();
      state = state.copyWith(
        clearCommittedReceipt: true,
        clearActiveSaleId: true,
        clearSession: true,
        clearEditBaselineSale: true,
        clearCustomer: true,
        receiptPreview: nextPreview ?? state.receiptPreview,
        cart: const [],
        suggestions: const [],
        discount: 0.0,
        tax: 0.0,
      );
      return result;
    } on OutboxQueuedException {
      _checkoutIdemKey = null;
      final nextPreview = await _repo.getNextReceiptPreview();
      state = state.copyWith(
        clearCommittedReceipt: true,
        clearActiveSaleId: true,
        clearSession: true,
        clearEditBaselineSale: true,
        clearCustomer: true,
        receiptPreview: nextPreview ?? state.receiptPreview,
        cart: const [],
        suggestions: const [],
        discount: 0.0,
        tax: 0.0,
      );
      rethrow;
    } catch (_) {
      rethrow;
    }
  }

  Future<void> holdCurrent() async {
    _holdIdemKey ??= const Uuid().v4();
    try {
      await _repo.holdSale(
        customerId: state.customer?.customerId,
        items: state.cart,
        discountAmount: state.discount,
        idempotencyKey: _holdIdemKey,
      );
      _holdIdemKey = null;
      // Reset cart and refresh preview. Do not show held sale number in header.
      final preview = await _repo.getNextReceiptPreview();
      state = state.copyWith(
        clearCommittedReceipt: true,
        clearActiveSaleId: true,
        clearSession: true,
        clearEditBaselineSale: true,
        cart: const [],
        suggestions: const [],
        discount: 0.0,
        tax: 0.0,
        receiptPreview: preview ?? state.receiptPreview,
      );
    } catch (_) {
      rethrow;
    }
  }

  void voidCurrent() {
    state = state.copyWith(
      cart: const [],
      suggestions: const [],
      discount: 0.0,
      tax: 0.0,
      clearCommittedReceipt: true,
      clearActiveSaleId: true,
      clearSession: true,
      clearEditBaselineSale: true,
    );
  }

  Future<void> loadHeldSaleItems(int saleId) async {
    // Resume and fetch items, then hydrate cart
    await _repo.resumeSale(saleId);
    final sale = await _repo.getSaleById(saleId);
    // Map items
    final items = sale.items
        .map((si) => PosCartItem(
              product: PosProductDto(
                productId: si.productId ?? 0,
                comboProductId: si.comboProductId,
                barcodeId: si.barcodeId ?? 0,
                name: si.productName ?? 'Item',
                price: si.unitPrice,
                stock: 0,
                barcode: si.barcode,
                variantName: si.variantName,
                isVirtualCombo: si.isVirtualCombo,
                trackingType: si.trackingType,
                isSerialized: si.isSerialized,
              ),
              quantity: si.quantity,
              unitPrice: si.unitPrice,
              discountPercent: si.discountPercent,
              tracking: si.isSerialized ||
                      si.trackingType == 'BATCH' ||
                      si.serialNumbers.isNotEmpty
                  ? InventoryTrackingSelection(
                      barcodeId: si.barcodeId,
                      trackingType: si.trackingType,
                      isSerialized: si.isSerialized,
                      barcode: si.barcode,
                      variantName: si.variantName,
                      serialNumbers: si.serialNumbers,
                    )
                  : null,
              comboTracking: si.comboComponentTracking,
            ))
        .toList();
    state = state.copyWith(
      cart: items,
      customerLabel: sale.customerName ?? state.customerLabel,
      committedReceipt: sale.saleNumber,
      activeSaleId: saleId,
      sessionLabel: 'Held sale resumed',
      sessionSourceSaleNumber: sale.saleNumber,
      editBaselineSale: null,
    );
    // ignore: unawaited_futures
    _recalculateTotals();
  }

  void loadRefundExchangeSession(
    SaleDto sale,
    List<SaleItemDto> items, {
    String label = 'Refund / exchange session',
  }) {
    final cartItems = items
        .where((item) =>
            ((item.productId ?? 0) > 0 || (item.comboProductId ?? 0) > 0) &&
            item.quantity > 0)
        .map((item) => _refundCartItemFromSaleItem(sale, item, item.quantity))
        .toList(growable: false);
    state = state.copyWith(
      cart: cartItems,
      customer:
          sale.customerId != null && (sale.customerName ?? '').trim().isNotEmpty
              ? PosCustomerDto(
                  customerId: sale.customerId!,
                  name: sale.customerName!,
                )
              : null,
      customerLabel: sale.customerName ?? 'Walk in',
      clearCommittedReceipt: true,
      clearActiveSaleId: true,
      clearCustomer:
          sale.customerId == null || (sale.customerName ?? '').trim().isEmpty,
      sessionLabel: label,
      sessionSourceSaleNumber: sale.saleNumber,
      editBaselineSale: null,
      query: '',
      suggestions: const [],
      discount: 0.0,
    );
    // ignore: unawaited_futures
    _recalculateTotals();
  }

  void loadInvoiceEditSession(SaleDto sale) {
    final cartItems = sale.items
        .where((item) =>
            ((item.productId ?? 0) > 0 || (item.comboProductId ?? 0) > 0) &&
            item.quantity > 0)
        .map(_saleCartItemFromSaleItem)
        .toList(growable: false);
    state = state.copyWith(
      cart: cartItems,
      customer:
          sale.customerId != null && (sale.customerName ?? '').trim().isNotEmpty
              ? PosCustomerDto(
                  customerId: sale.customerId!,
                  name: sale.customerName!,
                )
              : null,
      customerLabel: sale.customerName ?? 'Walk in',
      committedReceipt: sale.saleNumber,
      clearActiveSaleId: true,
      clearCustomer:
          sale.customerId == null || (sale.customerName ?? '').trim().isEmpty,
      sessionLabel: 'Editing existing sale',
      sessionSourceSaleNumber: sale.saleNumber,
      editBaselineSale: sale,
      query: '',
      suggestions: const [],
      discount: sale.discountAmount,
    );
    // ignore: unawaited_futures
    _recalculateTotals();
  }

  Future<void> _recalculateTotals() async {
    if (state.cart.isEmpty) {
      state = state.copyWith(tax: 0.0);
      return;
    }
    try {
      final res = await _repo.calculateTotals(
          items: state.cart, discountAmount: state.discount);
      state = state.copyWith(tax: res['tax_amount'] ?? 0.0);
    } catch (_) {
      // Soft-fail; leave previous tax value
    }
  }

  Future<void> refreshPreview() async {
    try {
      final preview = await _repo.getNextReceiptPreview();
      state =
          state.copyWith(receiptPreview: preview, clearCommittedReceipt: true);
    } catch (_) {}
  }
}

PosCartItem _saleCartItemFromSaleItem(SaleItemDto item) {
  final product = PosProductDto(
    productId: item.productId ?? 0,
    comboProductId: item.comboProductId,
    barcodeId: item.barcodeId ?? 0,
    name: item.productName ?? 'Item',
    price: item.unitPrice,
    stock: 0,
    barcode: item.barcode,
    variantName: item.variantName,
    isVirtualCombo: item.isVirtualCombo,
    trackingType: item.trackingType,
    isSerialized: item.isSerialized,
  );
  return PosCartItem(
    product: product,
    quantity: item.quantity,
    unitPrice: item.unitPrice,
    discountPercent: item.discountPercent,
    tracking: item.isSerialized || item.trackingType == 'BATCH'
        ? InventoryTrackingSelection(
            barcodeId: item.barcodeId,
            trackingType: item.trackingType,
            isSerialized: item.isSerialized,
            barcode: item.barcode,
            variantName: item.variantName,
            serialNumbers: item.serialNumbers,
          )
        : null,
    comboTracking: item.comboComponentTracking,
  );
}

PosCartItem _refundCartItemFromSaleItem(
  SaleDto sale,
  SaleItemDto item,
  double quantity,
) {
  final base = _saleCartItemFromSaleItem(item);
  return base.copyWith(
    quantity: -quantity.abs(),
    sourceSaleDetailId: item.saleDetailId ?? item.sourceSaleDetailId,
    sourceSaleId: sale.saleId,
    sourceSaleNumber: sale.saleNumber,
    lockedQuantity: true,
  );
}

final posNotifierProvider = StateNotifierProvider<PosNotifier, PosState>((ref) {
  final repo = ref.watch(posRepositoryProvider);
  final notifier = PosNotifier(repo);
  // lazy-init when first listened
  Future.microtask(() => notifier.init());
  return notifier;
});
