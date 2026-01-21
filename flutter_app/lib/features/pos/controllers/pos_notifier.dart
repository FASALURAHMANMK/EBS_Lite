import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

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
  });

  double get subtotal => cart.fold(0.0, (s, i) => s + i.lineTotal);
  double get total => (subtotal + tax - discount).clamp(0.0, double.infinity);

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
    bool clearCommittedReceipt = false,
    bool clearActiveSaleId = false,
    bool clearCustomer = false,
  }) {
    return PosState(
      receiptPreview: receiptPreview ?? this.receiptPreview,
      committedReceipt: clearCommittedReceipt ? null : (committedReceipt ?? this.committedReceipt),
      customer: clearCustomer ? null : (customer ?? this.customer),
      customerLabel: clearCustomer ? 'Walk in' : (customerLabel ?? this.customerLabel),
      query: query ?? this.query,
      suggestions: suggestions ?? this.suggestions,
      cart: cart ?? this.cart,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      activeSaleId: clearActiveSaleId ? null : (activeSaleId ?? this.activeSaleId),
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
      state = state.copyWith(isLoading: false, error: e.toString());
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
          .map((i) => i.discountPercent > 0 ? i.copyWith(discountPercent: 0) : i)
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
      state = state.copyWith(error: e.toString());
    }
  }

  void addProduct(PosProductDto p, {double qty = 1}) {
    final items = [...state.cart];
    final idx = items.indexWhere((i) => i.product.productId == p.productId);
    if (idx >= 0) {
      items[idx] = items[idx].copyWith(quantity: items[idx].quantity + qty);
    } else {
      items.add(PosCartItem(product: p, quantity: qty, unitPrice: p.price));
    }
    state = state.copyWith(cart: items, query: '', suggestions: const []);
    // ignore: unawaited_futures
    _recalculateTotals();
  }

  void updateQty(PosCartItem item, double qty) {
    final items = state.cart.map((i) => i == item ? i.copyWith(quantity: qty) : i).toList();
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
  }) async {
    _checkoutIdemKey ??= const Uuid().v4();
    try {
      final result = await _repo.checkout(
        customerId: state.customer?.customerId,
        items: state.cart,
        paymentMethodId: paymentMethodId,
        paidAmount: paidAmount,
        discountAmount: state.discount,
        saleId: state.activeSaleId,
        payments: payments,
        redeemPoints: redeemPoints,
        idempotencyKey: _checkoutIdemKey,
      );
      _checkoutIdemKey = null;
      final nextPreview = await _repo.getNextReceiptPreview();
      state = state.copyWith(
        clearCommittedReceipt: true,
        clearActiveSaleId: true,
        clearCustomer: true,
        receiptPreview: nextPreview,
        cart: const [],
        suggestions: const [],
        discount: 0.0,
        tax: 0.0,
      );
      return result;
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
        cart: const [],
        suggestions: const [],
        discount: 0.0,
        tax: 0.0,
        receiptPreview: preview,
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
                name: si.productName ?? 'Item',
                price: si.unitPrice,
                stock: 0,
              ),
              quantity: si.quantity,
              unitPrice: si.unitPrice,
              discountPercent: si.discountPercent,
            ))
        .toList();
    state = state.copyWith(
      cart: items,
      customerLabel: sale.customerName ?? state.customerLabel,
      committedReceipt: sale.saleNumber,
      activeSaleId: saleId,
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
      final res = await _repo.calculateTotals(items: state.cart, discountAmount: state.discount);
      state = state.copyWith(tax: res['tax_amount'] ?? 0.0);
    } catch (_) {
      // Soft-fail; leave previous tax value
    }
  }

  Future<void> refreshPreview() async {
    try {
      final preview = await _repo.getNextReceiptPreview();
      state = state.copyWith(receiptPreview: preview, clearCommittedReceipt: true);
    } catch (_) {}
  }
}

final posNotifierProvider = StateNotifierProvider<PosNotifier, PosState>((ref) {
  final repo = ref.watch(posRepositoryProvider);
  final notifier = PosNotifier(repo);
  // lazy-init when first listened
  Future.microtask(() => notifier.init());
  return notifier;
});
