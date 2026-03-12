import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/inventory_repository.dart';
import '../../data/models.dart';

Future<InventoryTrackingSelection?> showInventoryVariantSelector({
  required BuildContext context,
  required WidgetRef ref,
  required int productId,
  String? productName,
  InventoryTrackingSelection? initialSelection,
}) {
  return showDialog<InventoryTrackingSelection>(
    context: context,
    builder: (_) => _InventoryVariantDialog(
      repo: ref.read(inventoryRepositoryProvider),
      productId: productId,
      productName: productName,
      initialSelection: initialSelection,
    ),
  );
}

class _InventoryVariantDialog extends StatefulWidget {
  const _InventoryVariantDialog({
    required this.repo,
    required this.productId,
    this.productName,
    this.initialSelection,
  });

  final InventoryRepository repo;
  final int productId;
  final String? productName;
  final InventoryTrackingSelection? initialSelection;

  @override
  State<_InventoryVariantDialog> createState() =>
      _InventoryVariantDialogState();
}

class _InventoryVariantDialogState extends State<_InventoryVariantDialog> {
  bool _loading = true;
  String? _error;
  List<InventoryVariantStockDto> _variants = const [];
  int? _selectedBarcodeId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final variants = await widget.repo.getStockVariants(widget.productId);
      if (!mounted) return;
      setState(() {
        _variants = variants;
        _selectedBarcodeId = widget.initialSelection?.barcodeId ??
            (variants.isNotEmpty ? variants.first.barcodeId : null);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Variation'),
      content: SizedBox(
        width: 620,
        child: _loading
            ? const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
                ? SizedBox(
                    height: 180,
                    child: Center(child: Text(_error!)),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      Text(
                          widget.productName ?? 'Product #${widget.productId}'),
                      const SizedBox(height: 12),
                      if (_variants.isEmpty)
                        const Text('No active variations found')
                      else
                        RadioGroup<int>(
                          groupValue: _selectedBarcodeId,
                          onChanged: (value) =>
                              setState(() => _selectedBarcodeId = value),
                          child: Column(
                            children: _variants
                                .map(
                                  (variant) => RadioListTile<int>(
                                    value: variant.barcodeId,
                                    title: Text(variant.displayName),
                                    subtitle: Text([
                                      if ((variant.barcode ?? '')
                                          .trim()
                                          .isNotEmpty)
                                        'Barcode: ${variant.barcode!}',
                                      variant.trackingType,
                                    ].join(' • ')),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _variants.isEmpty
              ? null
              : () {
                  final selected = _variants.firstWhere(
                    (item) => item.barcodeId == _selectedBarcodeId,
                    orElse: () => _variants.first,
                  );
                  Navigator.of(context).pop(
                    InventoryTrackingSelection(
                      barcodeId: selected.barcodeId,
                      trackingType: selected.trackingType,
                      barcode: selected.barcode,
                      variantName: selected.variantName,
                    ),
                  );
                },
          child: const Text('Select'),
        ),
      ],
    );
  }
}
