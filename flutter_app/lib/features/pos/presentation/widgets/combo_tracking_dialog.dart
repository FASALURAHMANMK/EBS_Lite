import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../inventory/data/models.dart';
import '../../../inventory/presentation/widgets/inventory_tracking_selector.dart';
import '../../data/models.dart';

Future<List<PosComboComponentTracking>?> showComboTrackingDialog({
  required BuildContext context,
  required WidgetRef ref,
  required ComboProductDto combo,
  required double quantity,
  List<PosComboComponentTracking> initialTracking = const [],
}) {
  return showDialog<List<PosComboComponentTracking>>(
    context: context,
    builder: (_) => _ComboTrackingDialog(
      ref: ref,
      combo: combo,
      quantity: quantity,
      initialTracking: initialTracking,
    ),
  );
}

class _ComboTrackingDialog extends StatefulWidget {
  const _ComboTrackingDialog({
    required this.ref,
    required this.combo,
    required this.quantity,
    required this.initialTracking,
  });

  final WidgetRef ref;
  final ComboProductDto combo;
  final double quantity;
  final List<PosComboComponentTracking> initialTracking;

  @override
  State<_ComboTrackingDialog> createState() => _ComboTrackingDialogState();
}

class _ComboTrackingDialogState extends State<_ComboTrackingDialog> {
  late final List<PosComboComponentTracking> _components;

  @override
  void initState() {
    super.initState();
    final initialByBarcode = {
      for (final item in widget.initialTracking) item.barcodeId: item,
    };
    _components = widget.combo.components
        .where(_componentRequiresTracking)
        .map((component) {
      final existing = initialByBarcode[component.barcodeId];
      return PosComboComponentTracking(
        productId: component.productId,
        barcodeId: component.barcodeId,
        productName: component.productName,
        variantName: component.variantName,
        quantityPerCombo: component.quantity,
        trackingType: component.trackingType,
        isSerialized: component.isSerialized,
        tracking: existing?.tracking,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final requiredQtyLabel = widget.quantity.toStringAsFixed(
      widget.quantity == widget.quantity.roundToDouble() ? 0 : 3,
    );
    return AlertDialog(
      title: const Text('Configure Combo Tracking'),
      content: SizedBox(
        width: 720,
        child: _components.isEmpty
            ? const SizedBox(
                height: 120,
                child: Center(
                  child: Text('This combo does not contain tracked items.'),
                ),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  Text(
                    widget.combo.name,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Combo quantity: $requiredQtyLabel',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._components.asMap().entries.map((entry) {
                    final index = entry.key;
                    final component = entry.value;
                    final needed = widget.quantity * component.quantityPerCombo;
                    final configured =
                        component.hasTrackingConfigured(widget.quantity);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        component.displayLabel,
                                        style: theme.textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        [
                                          component.isSerialized
                                              ? 'Serial tracked'
                                              : 'Batch tracked',
                                          'Need ${needed.toStringAsFixed(component.isSerialized ? 0 : 3)}',
                                        ].join(' • '),
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  configured
                                      ? Icons.task_alt_rounded
                                      : Icons.pending_actions_rounded,
                                  color: configured
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                component.summary(widget.quantity),
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.tonalIcon(
                                onPressed: () =>
                                    _configureComponent(context, index),
                                icon: Icon(
                                  component.isSerialized
                                      ? Icons.qr_code_2_rounded
                                      : Icons.inventory_2_outlined,
                                ),
                                label: Text(
                                  component.isSerialized
                                      ? 'Select Serials'
                                      : 'Select Batches',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              _components.isEmpty ? () => Navigator.of(context).pop() : _submit,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Future<void> _configureComponent(BuildContext context, int index) async {
    final component = _components[index];
    final selection = await showInventoryTrackingSelector(
      context: context,
      ref: widget.ref,
      productId: component.productId,
      quantity: widget.quantity * component.quantityPerCombo,
      mode: InventoryTrackingMode.issue,
      productName: component.productName,
      initialSelection: component.tracking ??
          InventoryTrackingSelection(
            barcodeId: component.barcodeId,
            trackingType: component.trackingType,
            isSerialized: component.isSerialized,
            variantName: component.variantName,
          ),
    );
    if (!context.mounted || selection == null) return;
    setState(() {
      _components[index] = component.copyWith(tracking: selection);
    });
  }

  void _submit() {
    final missing = _components
        .where((component) => !component.hasTrackingConfigured(widget.quantity))
        .map((component) => component.displayLabel)
        .toList();
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Complete tracking for ${missing.first}${missing.length > 1 ? ' and ${missing.length - 1} more item(s)' : ''}.',
            ),
          ),
        );
      return;
    }
    Navigator.of(context).pop(_components);
  }
}

bool _componentRequiresTracking(ComboProductComponentDto component) {
  return component.isSerialized || component.trackingType == 'BATCH';
}
