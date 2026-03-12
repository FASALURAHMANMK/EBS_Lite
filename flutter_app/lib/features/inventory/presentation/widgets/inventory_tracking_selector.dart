import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/inventory_repository.dart';
import '../../data/models.dart';

enum InventoryTrackingMode { issue, receive }

Future<InventoryTrackingSelection?> showInventoryTrackingSelector({
  required BuildContext context,
  required WidgetRef ref,
  required int productId,
  required double quantity,
  required InventoryTrackingMode mode,
  String? productName,
  InventoryTrackingSelection? initialSelection,
}) {
  return showDialog<InventoryTrackingSelection>(
    context: context,
    builder: (_) => _InventoryTrackingDialog(
      repo: ref.read(inventoryRepositoryProvider),
      productId: productId,
      quantity: quantity,
      mode: mode,
      productName: productName,
      initialSelection: initialSelection,
    ),
  );
}

class _InventoryTrackingDialog extends StatefulWidget {
  const _InventoryTrackingDialog({
    required this.repo,
    required this.productId,
    required this.quantity,
    required this.mode,
    this.productName,
    this.initialSelection,
  });

  final InventoryRepository repo;
  final int productId;
  final double quantity;
  final InventoryTrackingMode mode;
  final String? productName;
  final InventoryTrackingSelection? initialSelection;

  @override
  State<_InventoryTrackingDialog> createState() =>
      _InventoryTrackingDialogState();
}

class _InventoryTrackingDialogState extends State<_InventoryTrackingDialog> {
  final _batchNumberCtrl = TextEditingController();
  final _serialInputCtrl = TextEditingController();
  final Map<int, TextEditingController> _batchQtyCtrls = {};

  bool _loading = true;
  String? _error;
  List<InventoryVariantStockDto> _variants = const [];
  List<InventoryBatchStockDto> _batches = const [];
  List<InventorySerialStockDto> _serials = const [];
  int? _selectedBarcodeId;
  DateTime? _expiryDate;
  final Set<String> _selectedSerials = <String>{};

  InventoryVariantStockDto? get _selectedVariant {
    if (_variants.isEmpty) return null;
    final barcodeId = _selectedBarcodeId;
    if (barcodeId == null) return _variants.first;
    for (final item in _variants) {
      if (item.barcodeId == barcodeId) return item;
    }
    return _variants.first;
  }

  String get _trackingType => _selectedVariant?.trackingType ?? 'VARIANT';

  @override
  void initState() {
    super.initState();
    _batchNumberCtrl.text = widget.initialSelection?.batchNumber ?? '';
    _serialInputCtrl.text =
        (widget.initialSelection?.serialNumbers ?? const []).join('\n');
    _expiryDate = widget.initialSelection?.expiryDate;
    _selectedSerials.addAll(widget.initialSelection?.serialNumbers ?? const []);
    _load();
  }

  @override
  void dispose() {
    _batchNumberCtrl.dispose();
    _serialInputCtrl.dispose();
    for (final ctrl in _batchQtyCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final variants = await widget.repo.getStockVariants(widget.productId);
      if (!mounted) return;
      final fallbackBarcodeId =
          widget.initialSelection?.barcodeId ?? variants.firstOrNull?.barcodeId;
      _variants = variants;
      _selectedBarcodeId = fallbackBarcodeId;
      await _loadTrackingData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadTrackingData() async {
    final variant = _selectedVariant;
    if (variant == null) return;
    if (widget.mode == InventoryTrackingMode.issue &&
        variant.trackingType == 'BATCH') {
      _batches = await widget.repo.getStockBatches(
        productId: widget.productId,
        barcodeId: variant.barcodeId,
      );
      for (final batch in _batches) {
        final existing = widget.initialSelection?.batchAllocations.firstWhere(
          (e) => e.lotId == batch.lotId,
          orElse: () =>
              const InventoryBatchAllocationDto(lotId: 0, quantity: 0),
        );
        final ctrl = _batchQtyCtrls.putIfAbsent(
          batch.lotId,
          () => TextEditingController(),
        );
        if ((existing?.lotId ?? 0) > 0 && ctrl.text.trim().isEmpty) {
          ctrl.text = existing!.quantity.toStringAsFixed(3);
        }
      }
    } else {
      _batches = const [];
    }
    if (widget.mode == InventoryTrackingMode.issue &&
        variant.trackingType == 'SERIAL') {
      _serials = await widget.repo.getAvailableSerials(
        productId: widget.productId,
        barcodeId: variant.barcodeId,
      );
    } else {
      _serials = const [];
    }
    if (mounted) {
      setState(() {});
    }
  }

  List<String> _parseSerials(String raw) {
    return raw
        .split(RegExp(r'[\n,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  void _autoAllocateBatches() {
    var remaining = widget.quantity;
    for (final batch in _batches) {
      final take = remaining > batch.remainingQuantity
          ? batch.remainingQuantity
          : remaining;
      final ctrl = _batchQtyCtrls.putIfAbsent(
        batch.lotId,
        () => TextEditingController(),
      );
      ctrl.text = take <= 0 ? '' : take.toStringAsFixed(3);
      remaining -= take;
    }
    setState(() {});
  }

  double get _allocatedBatchQty {
    return _batchQtyCtrls.values.fold<double>(0, (sum, ctrl) {
      return sum + (double.tryParse(ctrl.text.trim()) ?? 0);
    });
  }

  void _submit() {
    final variant = _selectedVariant;
    if (variant == null) {
      Navigator.of(context).pop();
      return;
    }
    if (widget.quantity <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
              content: Text('Enter a quantity before selecting tracking')),
        );
      return;
    }

    var serialNumbers = const <String>[];
    var batchAllocations = const <InventoryBatchAllocationDto>[];
    String? batchNumber;

    if (variant.trackingType == 'SERIAL') {
      final serials = widget.mode == InventoryTrackingMode.issue
          ? (() {
              final values = _selectedSerials.toList();
              values.sort();
              return values;
            })()
          : _parseSerials(_serialInputCtrl.text);
      if (serials.length != widget.quantity.round()) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Serial count must match quantity (${widget.quantity.toStringAsFixed(0)})',
              ),
            ),
          );
        return;
      }
      serialNumbers = serials;
    }

    if (variant.trackingType == 'BATCH') {
      if (widget.mode == InventoryTrackingMode.issue) {
        final allocations = _batches
            .map((batch) => InventoryBatchAllocationDto(
                  lotId: batch.lotId,
                  quantity: double.tryParse(
                        _batchQtyCtrls[batch.lotId]?.text.trim() ?? '',
                      ) ??
                      0,
                ))
            .where((e) => e.quantity > 0)
            .toList();
        final allocated =
            allocations.fold<double>(0, (sum, item) => sum + item.quantity);
        if ((allocated - widget.quantity).abs() > 0.0001) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  'Batch allocation must equal ${widget.quantity.toStringAsFixed(3)}',
                ),
              ),
            );
          return;
        }
        batchAllocations = allocations;
      } else {
        batchNumber = _batchNumberCtrl.text.trim().isEmpty
            ? null
            : _batchNumberCtrl.text.trim();
      }
    }

    Navigator.of(context).pop(
      InventoryTrackingSelection(
        barcodeId: variant.barcodeId,
        trackingType: variant.trackingType,
        barcode: variant.barcode,
        variantName: variant.variantName,
        serialNumbers: serialNumbers,
        batchAllocations: batchAllocations,
        batchNumber: batchNumber,
        expiryDate: _expiryDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variant = _selectedVariant;
    return AlertDialog(
      title: Text(
        widget.mode == InventoryTrackingMode.issue
            ? 'Select Variation / Batch / Serial'
            : 'Configure Variation / Tracking',
      ),
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
                    child: Center(
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      Text(
                        widget.productName ?? 'Product #${widget.productId}',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quantity: ${widget.quantity.toStringAsFixed(3)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Variation', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      if (_variants.isEmpty)
                        const Text('No active variations found')
                      else
                        DropdownButtonFormField<int>(
                          initialValue: _selectedBarcodeId,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.qr_code_2_rounded),
                          ),
                          items: _variants
                              .map(
                                (item) => DropdownMenuItem<int>(
                                  value: item.barcodeId,
                                  child: Text(
                                    '${item.displayName} • Stock ${item.quantity.toStringAsFixed(3)}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) async {
                            setState(() {
                              _selectedBarcodeId = value;
                              _batches = const [];
                              _serials = const [];
                              _selectedSerials.clear();
                            });
                            await _loadTrackingData();
                          },
                        ),
                      if (variant != null) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                                label:
                                    Text('Tracking: ${variant.trackingType}')),
                            if ((variant.barcode ?? '').trim().isNotEmpty)
                              Chip(label: Text('Barcode: ${variant.barcode}')),
                            Chip(
                              label: Text(
                                'Available: ${variant.quantity.toStringAsFixed(3)}',
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (_trackingType == 'BATCH' &&
                          widget.mode == InventoryTrackingMode.issue) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Text('Batches',
                                  style: theme.textTheme.titleSmall),
                            ),
                            TextButton.icon(
                              onPressed: _autoAllocateBatches,
                              icon: const Icon(Icons.auto_fix_high_rounded),
                              label: const Text('Auto Fill FIFO'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_batches.isEmpty)
                          const Text('No stock batches available')
                        else
                          ..._batches.map(
                            (batch) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      [
                                        (batch.batchNumber ?? '').trim().isEmpty
                                            ? 'Lot #${batch.lotId}'
                                            : 'Batch ${batch.batchNumber}',
                                        if (batch.expiryDate != null)
                                          'Exp ${_fmtDate(batch.expiryDate!)}',
                                        'Avail ${batch.remainingQuantity.toStringAsFixed(3)}',
                                      ].join(' • '),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 120,
                                    child: TextField(
                                      controller: _batchQtyCtrls.putIfAbsent(
                                        batch.lotId,
                                        () => TextEditingController(),
                                      ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Use Qty',
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          'Allocated: ${_allocatedBatchQty.toStringAsFixed(3)} / ${widget.quantity.toStringAsFixed(3)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (_trackingType == 'SERIAL' &&
                          widget.mode == InventoryTrackingMode.issue) ...[
                        const SizedBox(height: 16),
                        Text('Serial Numbers',
                            style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 220,
                          child: _serials.isEmpty
                              ? const Center(
                                  child: Text('No serials available'))
                              : ListView.builder(
                                  itemCount: _serials.length,
                                  itemBuilder: (context, index) {
                                    final serial = _serials[index];
                                    final selected = _selectedSerials
                                        .contains(serial.serialNumber);
                                    return CheckboxListTile(
                                      dense: true,
                                      value: selected,
                                      title: Text(serial.serialNumber),
                                      subtitle: Text([
                                        if ((serial.variantName ?? '')
                                            .trim()
                                            .isNotEmpty)
                                          serial.variantName!,
                                        if ((serial.barcode ?? '')
                                            .trim()
                                            .isNotEmpty)
                                          serial.barcode!,
                                      ].join(' • ')),
                                      onChanged: (value) {
                                        setState(() {
                                          if (value == true) {
                                            if (_selectedSerials.length <
                                                widget.quantity.round()) {
                                              _selectedSerials
                                                  .add(serial.serialNumber);
                                            }
                                          } else {
                                            _selectedSerials
                                                .remove(serial.serialNumber);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                        Text(
                          'Selected: ${_selectedSerials.length} / ${widget.quantity.toStringAsFixed(0)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (_trackingType == 'BATCH' &&
                          widget.mode == InventoryTrackingMode.receive) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _batchNumberCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Batch Number',
                            prefixIcon: Icon(Icons.inventory_rounded),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _expiryDate ?? now,
                              firstDate: DateTime(now.year - 1),
                              lastDate: DateTime(now.year + 20),
                            );
                            if (picked != null) {
                              setState(() => _expiryDate = picked);
                            }
                          },
                          icon: const Icon(Icons.event_rounded),
                          label: Text(
                            _expiryDate == null
                                ? 'Select Expiry Date'
                                : 'Expiry: ${_fmtDate(_expiryDate!)}',
                          ),
                        ),
                      ],
                      if (_trackingType == 'SERIAL' &&
                          widget.mode == InventoryTrackingMode.receive) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _serialInputCtrl,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            labelText: 'Serial Numbers',
                            hintText: 'One serial per line or comma-separated',
                            prefixIcon: Icon(Icons.numbers_rounded),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Entered: ${_parseSerials(_serialInputCtrl.text).length} / ${widget.quantity.toStringAsFixed(0)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  String _fmtDate(DateTime value) {
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '${value.year}-$m-$d';
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
