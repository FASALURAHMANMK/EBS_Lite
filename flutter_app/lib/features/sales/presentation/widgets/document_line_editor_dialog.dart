import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../../customers/data/models.dart';
import '../../../inventory/data/models.dart';
import '../../../pos/data/models.dart';
import 'professional_document_widgets.dart';

String formatDocumentQuantity(double value) {
  final normalized = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  return normalized.replaceFirst(RegExp(r'\.?0+$'), '');
}

String formatDocumentMoney(double value) => value.toStringAsFixed(2);

class DocumentTaxProfile {
  const DocumentTaxProfile({
    required this.taxId,
    required this.name,
    required this.rate,
  });

  final int taxId;
  final String name;
  final double rate;

  String get label {
    final cleanName = name.trim();
    final pct =
        rate % 1 == 0 ? rate.toStringAsFixed(0) : rate.toStringAsFixed(2);
    if (cleanName.isEmpty) return '$pct%';
    return '$cleanName ($pct%)';
  }
}

class DocumentProductOption {
  const DocumentProductOption({
    this.productId,
    this.comboProductId,
    this.barcodeId,
    required this.name,
    this.variantName,
    this.barcode,
    this.categoryName,
    this.primaryStorage,
    required this.unitPrice,
    this.stockOnHand,
    this.taxId,
    this.trackingType = 'VARIANT',
    this.isSerialized = false,
    this.isVirtualCombo = false,
  });

  factory DocumentProductOption.fromPosProduct(PosProductDto product) =>
      DocumentProductOption(
        productId: product.productId > 0 ? product.productId : null,
        comboProductId: product.comboProductId,
        barcodeId: product.barcodeId > 0 ? product.barcodeId : null,
        name: product.name,
        variantName: product.variantName,
        barcode: product.barcode,
        categoryName: product.categoryName,
        primaryStorage: product.primaryStorage,
        unitPrice: product.price,
        stockOnHand: product.stock,
        taxId: null,
        trackingType: product.trackingType,
        isSerialized: product.isSerialized,
        isVirtualCombo: product.isVirtualCombo,
      );

  factory DocumentProductOption.fromInventory(InventoryListItem item) =>
      DocumentProductOption(
        productId: item.productId > 0 ? item.productId : null,
        comboProductId: item.comboProductId,
        barcodeId: item.barcodeId,
        name: item.name,
        variantName: item.variantName,
        barcode: item.barcode,
        categoryName: item.categoryName,
        primaryStorage: item.primaryStorage,
        unitPrice: item.price ?? 0,
        stockOnHand: item.stock,
        taxId: null,
        trackingType: item.trackingType,
        isSerialized: item.trackingType == 'SERIAL',
        isVirtualCombo: item.isVirtualCombo,
      );

  final int? productId;
  final int? comboProductId;
  final int? barcodeId;
  final String name;
  final String? variantName;
  final String? barcode;
  final String? categoryName;
  final String? primaryStorage;
  final double unitPrice;
  final double? stockOnHand;
  final int? taxId;
  final String trackingType;
  final bool isSerialized;
  final bool isVirtualCombo;

  String get displayName {
    final pieces = [
      name.trim(),
      if ((variantName ?? '').trim().isNotEmpty) variantName!.trim(),
    ];
    return pieces.join(' • ');
  }

  String get supportingText {
    final parts = <String>[
      if ((barcode ?? '').trim().isNotEmpty) barcode!.trim(),
      if ((categoryName ?? '').trim().isNotEmpty) categoryName!.trim(),
      if ((primaryStorage ?? '').trim().isNotEmpty) primaryStorage!.trim(),
      'Price ${formatDocumentMoney(unitPrice)}',
      if (stockOnHand != null) 'Stock ${formatDocumentQuantity(stockOnHand!)}',
    ];
    return parts.join(' • ');
  }
}

class DocumentLineDraft {
  DocumentLineDraft({
    this.productId,
    this.comboProductId,
    this.barcodeId,
    this.productName,
    this.variantName,
    this.barcode,
    this.primaryStorage,
    this.trackingType = 'VARIANT',
    this.isSerialized = false,
    this.taxId,
    this.taxName,
    this.taxRate = 0,
    this.persistedTaxAmount,
    this.sourceSaleDetailId,
    this.lockedQuantity = false,
    this.tracking,
    this.comboTracking = const [],
    this.quantity = 0,
    this.unitPrice = 0,
    this.discountPercent = 0,
  });

  factory DocumentLineDraft.empty() => DocumentLineDraft();

  factory DocumentLineDraft.fromQuoteJson(Map<String, dynamic> json) =>
      DocumentLineDraft(
        productId: json['product_id'] as int?,
        comboProductId: json['combo_product_id'] as int?,
        productName:
            (json['product_name'] ?? json['product']?['name'] ?? 'Item')
                .toString(),
        variantName: json['variant_name']?.toString(),
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
        discountPercent: (json['discount_percentage'] as num?)?.toDouble() ?? 0,
        taxId: (json['tax_id'] as num?)?.toInt(),
        persistedTaxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
      );

  factory DocumentLineDraft.fromSaleItem(SaleItemDto item) => DocumentLineDraft(
        productId: item.productId,
        comboProductId: item.comboProductId,
        barcodeId: item.barcodeId,
        taxId: item.taxId,
        persistedTaxAmount: item.taxAmount,
        productName: item.productName,
        variantName: item.variantName,
        barcode: item.barcode,
        trackingType: item.trackingType,
        isSerialized: item.isSerialized,
        sourceSaleDetailId: item.sourceSaleDetailId,
        comboTracking: item.comboComponentTracking,
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
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        discountPercent: item.discountPercent,
      );

  factory DocumentLineDraft.fromExchangeItem(SaleDto sale, SaleItemDto item) {
    final draft = DocumentLineDraft.fromSaleItem(item);
    draft.sourceSaleDetailId ??= item.saleDetailId;
    draft.lockedQuantity = true;
    draft.quantity = -item.quantity.abs();
    draft.productName ??= 'Refund from ${sale.saleNumber}';
    return draft;
  }

  int? productId;
  int? comboProductId;
  int? barcodeId;
  String? productName;
  String? variantName;
  String? barcode;
  String? primaryStorage;
  String trackingType;
  bool isSerialized;
  int? taxId;
  String? taxName;
  double taxRate;
  double? persistedTaxAmount;
  int? sourceSaleDetailId;
  bool lockedQuantity;
  InventoryTrackingSelection? tracking;
  List<PosComboComponentTracking> comboTracking;
  double quantity;
  double unitPrice;
  double discountPercent;

  bool get hasProduct => (productId ?? 0) > 0 || (comboProductId ?? 0) > 0;
  bool get isCombo => (comboProductId ?? 0) > 0;
  bool get isRefundLine => quantity < 0;
  bool get requiresTracking =>
      isSerialized || trackingType == 'BATCH' || trackingType == 'SERIAL';
  bool get productSelectionLocked =>
      lockedQuantity || (sourceSaleDetailId ?? 0) > 0;
  double get lineSubtotal => quantity * unitPrice;
  double get lineDiscountAmount =>
      lineSubtotal * (discountPercent.clamp(0.0, 100.0) / 100.0);
  double get lineTotal => lineSubtotal - lineDiscountAmount;
  double get taxAmount => persistedTaxAmount ?? (lineTotal * (taxRate / 100));
  double get lineGrandTotal => lineTotal + taxAmount;
  String get taxLabel {
    if ((taxName ?? '').trim().isNotEmpty && taxRate > 0) {
      final pct = taxRate % 1 == 0
          ? taxRate.toStringAsFixed(0)
          : taxRate.toStringAsFixed(2);
      return '${taxName!.trim()} ($pct%)';
    }
    if ((taxName ?? '').trim().isNotEmpty) return taxName!.trim();
    if (taxRate > 0) {
      final pct = taxRate % 1 == 0
          ? taxRate.toStringAsFixed(0)
          : taxRate.toStringAsFixed(2);
      return '$pct%';
    }
    return 'No tax';
  }

  String get displayName {
    final pieces = [
      (productName ?? '').trim(),
      if ((variantName ?? '').trim().isNotEmpty) variantName!.trim(),
    ].where((value) => value.isNotEmpty).toList();
    return pieces.isEmpty ? 'Select item' : pieces.join(' • ');
  }

  String get supportingText {
    final parts = <String>[
      if ((barcode ?? '').trim().isNotEmpty) barcode!.trim(),
      if ((primaryStorage ?? '').trim().isNotEmpty) primaryStorage!.trim(),
      if (requiresTracking)
        tracking == null
            ? 'Tracking required'
            : tracking!.summary(quantity.abs()),
    ];
    return parts.join(' • ');
  }

  String get trackingSummary {
    if (!requiresTracking) return 'Tracking not required';
    if (tracking == null) return 'Tracking required';
    return tracking!.summary(quantity.abs());
  }

  DocumentLineDraft copy() => DocumentLineDraft(
        productId: productId,
        comboProductId: comboProductId,
        barcodeId: barcodeId,
        productName: productName,
        variantName: variantName,
        barcode: barcode,
        primaryStorage: primaryStorage,
        trackingType: trackingType,
        isSerialized: isSerialized,
        taxId: taxId,
        taxName: taxName,
        taxRate: taxRate,
        persistedTaxAmount: persistedTaxAmount,
        sourceSaleDetailId: sourceSaleDetailId,
        lockedQuantity: lockedQuantity,
        tracking: tracking,
        comboTracking: List<PosComboComponentTracking>.from(comboTracking),
        quantity: quantity,
        unitPrice: unitPrice,
        discountPercent: discountPercent,
      );

  void applyProductOption(DocumentProductOption option) {
    final sign = quantity < 0 ? -1.0 : 1.0;
    final nextAbsQuantity = quantity.abs() > 0 ? quantity.abs() : 1.0;
    productId = option.productId;
    comboProductId = option.comboProductId;
    barcodeId = option.barcodeId;
    productName = option.name;
    variantName = option.variantName;
    barcode = option.barcode;
    primaryStorage = option.primaryStorage;
    trackingType = option.trackingType;
    isSerialized = option.isSerialized;
    sourceSaleDetailId = null;
    lockedQuantity = false;
    taxId = option.taxId;
    taxName = null;
    taxRate = 0;
    persistedTaxAmount = null;
    tracking = null;
    comboTracking = const [];
    quantity = sign * nextAbsQuantity;
    unitPrice = option.unitPrice;
    discountPercent = 0;
  }

  void applyTaxProfile(DocumentTaxProfile? profile) {
    if (profile == null) {
      taxName = null;
      taxRate = 0;
      if ((taxId ?? 0) <= 0) {
        taxId = null;
      }
      persistedTaxAmount = null;
      return;
    }
    taxId = profile.taxId;
    taxName = profile.name;
    taxRate = profile.rate;
    persistedTaxAmount = null;
  }

  Map<String, dynamic> toQuoteJson() => {
        if ((productId ?? 0) > 0) 'product_id': productId,
        if ((comboProductId ?? 0) > 0) 'combo_product_id': comboProductId,
        'quantity': quantity,
        'unit_price': unitPrice,
        'discount_percentage': discountPercent,
      };

  Map<String, dynamic> toInvoiceJson() => {
        if ((productId ?? 0) > 0) 'product_id': productId,
        if ((comboProductId ?? 0) > 0) 'combo_product_id': comboProductId,
        if ((barcodeId ?? 0) > 0) 'barcode_id': barcodeId,
        if ((sourceSaleDetailId ?? 0) > 0)
          'source_sale_detail_id': sourceSaleDetailId,
        'quantity': quantity,
        'unit_price': unitPrice,
        'discount_percentage': discountPercent,
        if (tracking != null) ...tracking!.toIssueJson(),
        if (comboTracking.isNotEmpty)
          'combo_component_tracking':
              comboTracking.map((item) => item.toJson()).toList(),
      };

  PosCartItem toPosCartItem() => PosCartItem(
        product: PosProductDto(
          productId: productId ?? 0,
          comboProductId: comboProductId,
          barcodeId: barcodeId ?? 0,
          name: productName ?? 'Item',
          price: unitPrice,
          stock: 0,
          barcode: barcode,
          variantName: variantName,
          isVirtualCombo: isCombo,
          trackingType: trackingType,
          isSerialized: isSerialized,
        ),
        quantity: quantity,
        unitPrice: unitPrice,
        discountPercent: discountPercent,
        sourceSaleDetailId: sourceSaleDetailId,
        tracking: tracking,
        comboTracking: comboTracking,
        lockedQuantity: lockedQuantity,
      );
}

class DocumentLineDialogResult {
  const DocumentLineDialogResult.saved(DocumentLineDraft this.line)
      : remove = false;

  const DocumentLineDialogResult.deleted()
      : line = null,
        remove = true;

  final DocumentLineDraft? line;
  final bool remove;
}

Future<DocumentLineDialogResult?> showDocumentLineEditorDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  required DocumentLineDraft initialLine,
  required Future<List<DocumentProductOption>> Function(String query)
      searchProducts,
  bool allowNegativeQuantity = false,
  bool allowDelete = false,
  Future<InventoryTrackingSelection?> Function(DocumentLineDraft draft)?
      configureTracking,
  Future<DocumentTaxProfile?> Function(DocumentProductOption option)?
      resolveTaxProfile,
}) {
  return showDialog<DocumentLineDialogResult>(
    context: context,
    builder: (_) => _DocumentLineEditorDialog(
      title: title,
      initialLine: initialLine,
      searchProducts: searchProducts,
      allowNegativeQuantity: allowNegativeQuantity,
      allowDelete: allowDelete,
      configureTracking: configureTracking,
      resolveTaxProfile: resolveTaxProfile,
    ),
  );
}

class _DocumentLineEditorDialog extends ConsumerStatefulWidget {
  const _DocumentLineEditorDialog({
    required this.title,
    required this.initialLine,
    required this.searchProducts,
    required this.allowNegativeQuantity,
    required this.allowDelete,
    this.configureTracking,
    this.resolveTaxProfile,
  });

  final String title;
  final DocumentLineDraft initialLine;
  final Future<List<DocumentProductOption>> Function(String query)
      searchProducts;
  final bool allowNegativeQuantity;
  final bool allowDelete;
  final Future<InventoryTrackingSelection?> Function(DocumentLineDraft draft)?
      configureTracking;
  final Future<DocumentTaxProfile?> Function(DocumentProductOption option)?
      resolveTaxProfile;

  @override
  ConsumerState<_DocumentLineEditorDialog> createState() =>
      _DocumentLineEditorDialogState();
}

class _DocumentLineEditorDialogState
    extends ConsumerState<_DocumentLineEditorDialog> {
  late DocumentLineDraft _draft;
  late final TextEditingController _searchCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _discountCtrl;

  List<DocumentProductOption> _results = const [];
  bool _searching = false;
  bool _resolvingTax = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialLine.copy();
    _searchCtrl = TextEditingController(text: _draft.barcode ?? '');
    _qtyCtrl = TextEditingController(
      text: _draft.quantity == 0 ? '' : _draft.quantity.toStringAsFixed(2),
    );
    _priceCtrl = TextEditingController(
      text: _draft.unitPrice == 0 ? '' : _draft.unitPrice.toStringAsFixed(2),
    );
    _discountCtrl = TextEditingController(
      text: _draft.discountPercent.toStringAsFixed(2),
    );
    Future.microtask(() => _runSearch(_searchCtrl.text.trim()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await widget.searchProducts(query);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ErrorHandler.message(e));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _syncDraftFromFields() {
    _draft.quantity = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    _draft.unitPrice = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    _draft.discountPercent =
        (double.tryParse(_discountCtrl.text.trim()) ?? 0).clamp(0.0, 100.0);
  }

  Future<void> _selectProduct(DocumentProductOption option) async {
    setState(() {
      _draft.applyProductOption(option);
      _qtyCtrl.text = _draft.quantity.toStringAsFixed(2);
      _priceCtrl.text = _draft.unitPrice.toStringAsFixed(2);
      _discountCtrl.text = _draft.discountPercent.toStringAsFixed(2);
      _error = null;
      _resolvingTax = widget.resolveTaxProfile != null;
    });
    if (widget.resolveTaxProfile == null) return;
    try {
      final profile = await widget.resolveTaxProfile!(option);
      if (!mounted) return;
      setState(() {
        _draft.applyTaxProfile(profile);
        _resolvingTax = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorHandler.message(e);
        _resolvingTax = false;
      });
    }
  }

  Future<void> _configureTracking() async {
    _syncDraftFromFields();
    if (!_draft.hasProduct) {
      setState(() => _error = 'Select an item before configuring tracking.');
      return;
    }
    if (!_draft.requiresTracking || widget.configureTracking == null) {
      return;
    }
    if (_draft.quantity == 0) {
      setState(() => _error = 'Enter quantity before configuring tracking.');
      return;
    }
    final selection = await widget.configureTracking!(_draft.copy());
    if (selection == null || !mounted) return;
    setState(() {
      _draft.tracking = selection;
      _error = null;
    });
  }

  void _save() {
    _syncDraftFromFields();
    if (!_draft.hasProduct) {
      setState(() => _error = 'Select an item first.');
      return;
    }
    if (widget.allowNegativeQuantity) {
      if (_draft.quantity == 0) {
        setState(() => _error = 'Quantity cannot be zero.');
        return;
      }
    } else if (_draft.quantity <= 0) {
      setState(() => _error = 'Quantity must be greater than zero.');
      return;
    }
    if (_draft.unitPrice <= 0) {
      setState(() => _error = 'Unit price must be greater than zero.');
      return;
    }
    if (_draft.requiresTracking && _draft.tracking == null) {
      setState(() => _error = 'Configure tracking before saving this line.');
      return;
    }
    Navigator.of(context).pop(DocumentLineDialogResult.saved(_draft.copy()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewport = MediaQuery.sizeOf(context);
    final wide = viewport.width >= 1040;
    final dialogHeight =
        (viewport.height * 0.88).clamp(540.0, wide ? 680.0 : 760.0).toDouble();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: SizedBox(
          height: dialogHeight,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Search by barcode or product name, then set quantity, price, and discount before saving the line.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_draft.hasProduct)
                      ProfessionalBadge(
                        label:
                            _draft.isRefundLine ? 'Refund Line' : 'Sale Line',
                        backgroundColor: _draft.isRefundLine
                            ? const Color(0xFFFDE8E4)
                            : const Color(0xFFEAF1F8),
                        foregroundColor: _draft.isRefundLine
                            ? const Color(0xFF8A3E31)
                            : const Color(0xFF23415F),
                      ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                if ((_error ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Expanded(
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 11,
                              child: _buildCatalogPanel(
                                context,
                                expandContent: true,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 10,
                              child: _buildEditorPanel(
                                context,
                                expandContent: true,
                              ),
                            ),
                          ],
                        )
                      : ListView(
                          children: [
                            _buildCatalogPanel(
                              context,
                              expandContent: false,
                            ),
                            const SizedBox(height: 14),
                            _buildEditorPanel(
                              context,
                              expandContent: false,
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (widget.allowDelete && widget.initialLine.hasProduct)
                      TextButton.icon(
                        onPressed: () => Navigator.of(context)
                            .pop(const DocumentLineDialogResult.deleted()),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Delete Line'),
                      )
                    else
                      const SizedBox.shrink(),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Save Line'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogPanel(
    BuildContext context, {
    required bool expandContent,
  }) {
    final resultsView = DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _searching
            ? const Center(child: CircularProgressIndicator())
            : _results.isEmpty
                ? Center(
                    child: Text(
                      'No matching items found.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      final selected = item.productId == _draft.productId &&
                          item.comboProductId == _draft.comboProductId &&
                          item.barcodeId == _draft.barcodeId;
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        selected: selected,
                        enabled: !_draft.productSelectionLocked,
                        leading: Icon(
                          item.isVirtualCombo
                              ? Icons.widgets_rounded
                              : Icons.inventory_2_rounded,
                          size: 20,
                        ),
                        title: Text(item.displayName),
                        subtitle: Text(item.supportingText),
                        trailing: selected
                            ? const Icon(Icons.check_circle_rounded, size: 18)
                            : null,
                        onTap: _draft.productSelectionLocked
                            ? null
                            : () => _selectProduct(item),
                      );
                    },
                  ),
      ),
    );

    return ProfessionalSectionCard(
      title: 'Item Search',
      subtitle: _draft.productSelectionLocked
          ? 'This line is tied to an original source item, so product selection is locked.'
          : 'Scan or type a barcode, SKU, or product name.',
      expandChild: expandContent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchCtrl,
            enabled: !_draft.productSelectionLocked,
            decoration: const InputDecoration(
              hintText: 'Search by barcode or product name',
              labelText: 'Search / Barcode',
              prefixIcon: Icon(Icons.qr_code_scanner_rounded),
            ),
            onChanged: (value) => _runSearch(value.trim()),
            onSubmitted: (value) => _runSearch(value.trim()),
          ),
          const SizedBox(height: 12),
          if (expandContent)
            Expanded(child: resultsView)
          else
            SizedBox(height: 260, child: resultsView),
        ],
      ),
    );
  }

  Widget _buildEditorPanel(
    BuildContext context, {
    required bool expandContent,
  }) {
    final theme = Theme.of(context);
    final previewQty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final previewPrice = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final previewDiscount =
        (double.tryParse(_discountCtrl.text.trim()) ?? 0).clamp(0.0, 100.0);
    final previewSubtotal = previewQty * previewPrice;
    final previewNet =
        previewSubtotal - (previewSubtotal * (previewDiscount / 100));
    final previewTax =
        _draft.persistedTaxAmount ?? (previewNet * (_draft.taxRate / 100));
    final previewGrand = previewNet + previewTax;
    return ProfessionalSectionCard(
      title: 'Line Details',
      subtitle:
          'Review the selected item and confirm commercial values before saving.',
      expandChild: expandContent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFD),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFD7E3EF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _draft.hasProduct ? _draft.displayName : 'Select item',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _draft.hasProduct
                      ? (_draft.supportingText.isEmpty
                          ? 'Ready for quantity and price entry.'
                          : _draft.supportingText)
                      : 'Select an item from the catalog to begin.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 168,
                child: TextField(
                  controller: _qtyCtrl,
                  enabled: !_draft.lockedQuantity,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: true,
                    signed: widget.allowNegativeQuantity,
                  ),
                  decoration: InputDecoration(
                    labelText: widget.allowNegativeQuantity
                        ? 'Quantity (+/-)'
                        : 'Quantity',
                    prefixIcon: const Icon(Icons.format_list_numbered_rounded),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                width: 168,
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Unit Price',
                    prefixIcon: Icon(Icons.sell_outlined),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                width: 168,
                child: TextField(
                  controller: _discountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Discount %',
                    prefixIcon: Icon(Icons.percent_rounded),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _DialogReadOnlyField(
                label: 'Tax',
                value: _resolvingTax ? 'Loading...' : _draft.taxLabel,
                width: 168,
              ),
              _DialogReadOnlyField(
                label: 'Tax Amount',
                value: formatDocumentMoney(previewTax),
                width: 168,
              ),
            ],
          ),
          if (_draft.requiresTracking && widget.configureTracking != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _configureTracking,
              icon: const Icon(Icons.qr_code_2_rounded),
              label: Text(
                _draft.tracking == null
                    ? 'Configure Tracking'
                    : 'Tracking: ${_draft.trackingSummary}',
              ),
            ),
          ],
          if (_draft.lockedQuantity) ...[
            const SizedBox(height: 12),
            Text(
              'Quantity is locked for this source-linked line.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (widget.allowNegativeQuantity) ...[
            const SizedBox(height: 8),
            Text(
              'Use a negative quantity to create a refund line.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (expandContent) const Spacer() else const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Line Preview',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _PreviewRow(
                  label: 'Subtotal',
                  value: formatDocumentMoney(previewSubtotal),
                ),
                const SizedBox(height: 8),
                _PreviewRow(
                  label: 'Discount',
                  value: '${formatDocumentMoney(previewDiscount)}%',
                ),
                const SizedBox(height: 8),
                _PreviewRow(
                  label: 'Tax',
                  value: formatDocumentMoney(previewTax),
                ),
                const SizedBox(height: 8),
                _PreviewRow(
                  label: 'Net Total',
                  emphasize: true,
                  value: formatDocumentMoney(previewGrand),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: emphasize
                ? theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  )
                : theme.textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: emphasize
              ? theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                )
              : theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
        ),
      ],
    );
  }
}

class _DialogReadOnlyField extends StatelessWidget {
  const _DialogReadOnlyField({
    required this.label,
    required this.value,
    required this.width,
  });

  final String label;
  final String value;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class DocumentCustomerSnapshot {
  const DocumentCustomerSnapshot({
    this.customerId,
    required this.name,
    this.customerType = 'RETAIL',
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.shippingAddress,
    this.taxNumber,
    this.creditLimit = 0,
    this.creditBalance = 0,
    this.paymentTerms = 0,
  });

  factory DocumentCustomerSnapshot.fromCustomer(CustomerDto customer) =>
      DocumentCustomerSnapshot(
        customerId: customer.customerId,
        name: customer.name,
        customerType: customer.customerType,
        contactPerson: customer.contactPerson,
        phone: customer.phone,
        email: customer.email,
        address: customer.address,
        shippingAddress: customer.shippingAddress,
        taxNumber: customer.taxNumber,
        creditLimit: customer.creditLimit,
        creditBalance: customer.creditBalance,
        paymentTerms: customer.paymentTerms,
      );

  final int? customerId;
  final String name;
  final String customerType;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final String? shippingAddress;
  final String? taxNumber;
  final double creditLimit;
  final double creditBalance;
  final int paymentTerms;

  String get primaryAddress {
    final shipping = (shippingAddress ?? '').trim();
    if (shipping.isNotEmpty) return shipping;
    final billing = (address ?? '').trim();
    if (billing.isNotEmpty) return billing;
    return 'No address on customer profile';
  }

  List<String> get identityChips => [
        if ((contactPerson ?? '').trim().isNotEmpty) contactPerson!.trim(),
        if ((phone ?? '').trim().isNotEmpty) phone!.trim(),
        if ((email ?? '').trim().isNotEmpty) email!.trim(),
      ];
}
