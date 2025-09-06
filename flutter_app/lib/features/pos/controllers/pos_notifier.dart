import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final bool isLoading;
  final String? error;
  final List<PaymentMethodDto> paymentMethods;

  const PosState({
    this.receiptPreview,
    this.committedReceipt,
    this.customer,
    this.customerLabel = 'Walk in',
    this.query = '',
    this.suggestions = const [],
    this.cart = const [],
    this.discount = 0.0,
    this.isLoading = false,
    this.error,
    this.paymentMethods = const [],
  });

  double get subtotal => cart.fold(0.0, (s, i) => s + i.lineTotal);
  double get total => (subtotal - discount).clamp(0.0, double.infinity);

  PosState copyWith({
    String? receiptPreview,
    String? committedReceipt,
    PosCustomerDto? customer,
    String? customerLabel,
    String? query,
    List<PosProductDto>? suggestions,
    List<PosCartItem>? cart,
    double? discount,
    bool? isLoading,
    String? error,
    List<PaymentMethodDto>? paymentMethods,
  }) {
    return PosState(
      receiptPreview: receiptPreview ?? this.receiptPreview,
      committedReceipt: committedReceipt ?? this.committedReceipt,
      customer: customer ?? this.customer,
      customerLabel: customerLabel ?? this.customerLabel,
      query: query ?? this.query,
      suggestions: suggestions ?? this.suggestions,
      cart: cart ?? this.cart,
      discount: discount ?? this.discount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      paymentMethods: paymentMethods ?? this.paymentMethods,
    );
  }
}

class PosNotifier extends StateNotifier<PosState> {
  PosNotifier(this._repo) : super(const PosState());
  final PosRepository _repo;
  Timer? _debounce;

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
    state = state.copyWith(discount: value);
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
  }

  void updateQty(PosCartItem item, double qty) {
    final items = state.cart.map((i) => i == item ? i.copyWith(quantity: qty) : i).toList();
    state = state.copyWith(cart: items);
  }

  void removeItem(PosCartItem item) {
    final items = [...state.cart]..remove(item);
    state = state.copyWith(cart: items);
  }

  Future<PosCheckoutResult> processCheckout({
    required int? paymentMethodId,
    required double paidAmount,
  }) async {
    final result = await _repo.checkout(
      customerId: state.customer?.customerId,
      items: state.cart,
      paymentMethodId: paymentMethodId,
      paidAmount: paidAmount,
      discountAmount: state.discount,
    );
    state = state.copyWith(
      committedReceipt: result.saleNumber,
      cart: const [],
      suggestions: const [],
      discount: 0.0,
    );
    return result;
  }
}

final posNotifierProvider = StateNotifierProvider<PosNotifier, PosState>((ref) {
  final repo = ref.watch(posRepositoryProvider);
  final notifier = PosNotifier(repo);
  // lazy-init when first listened
  Future.microtask(() => notifier.init());
  return notifier;
});

