import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';

import '../../../dashboard/controllers/location_notifier.dart';
import '../../controllers/pos_notifier.dart';
import '../../data/models.dart';
import '../../data/pos_repository.dart';
import '../widgets/customer_selector_dialog.dart';
import 'payment_page.dart';
import '../../../../shared/widgets/manager_override_dialog.dart';
import '../../../../core/error_handler.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../inventory/data/models.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../inventory/presentation/widgets/inventory_tracking_selector.dart';
import '../widgets/combo_tracking_dialog.dart';

class PosPage extends ConsumerWidget {
  const PosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final state = ref.watch(posNotifierProvider);
    final notifier = ref.read(posNotifierProvider.notifier);
    final loc = ref.watch(locationNotifierProvider).selected;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: isWide ? 104 : null,
        leading: isWide ? const DesktopSidebarToggleLeading() : null,
        title: const Text('New Sale'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Held Sales',
            icon: const Icon(Icons.inbox_rounded),
            onPressed: () async {
              await showDialog(
                  context: context, builder: (_) => const _HeldSalesDialog());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Row: Receipt number + Customer selection button
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(builder: (context) {
                        final display = state.activeSaleId != null
                            ? (state.committedReceipt ?? '-')
                            : (state.receiptPreview ?? '-');
                        return Text(
                          'Receipt # $display',
                          style: Theme.of(context).textTheme.titleMedium,
                        );
                      }),
                      if (loc != null)
                        Text('Location: ${loc.name}',
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    final picked = await showDialog<PosCustomerDto>(
                      context: context,
                      builder: (_) => const CustomerSelectorDialog(),
                    );
                    if (picked != null) notifier.setCustomer(picked);
                  },
                  icon: const Icon(Icons.person_search_rounded),
                  label: const Text('Customer'),
                )
              ],
            ),
          ),
          // Customer name row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Customer: ${state.customerLabel}'),
            ),
          ),
          const SizedBox(height: 8),
          // Product search with live suggestions (show 2)
          const _SearchBar(),
          const SizedBox(height: 8),
          // Cart list (scrollable). No extra spacer; bottom bar has own height.
          const Expanded(child: _CartList()),
        ],
      ),
      // Persistent amount + process button
      bottomNavigationBar: _BottomBar(),
    );
  }
}

class _SearchBar extends ConsumerStatefulWidget {
  const _SearchBar();

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  static const double _fieldHeight = 56;

  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  MobileScannerController? _scannerController;
  bool _showScanner = false;
  bool _scanLock = false;

  bool get _scanSupported {
    if (kIsWeb) return true;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS =>
        true,
      _ => false,
    };
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    final scannerController = _scannerController;
    if (scannerController != null) {
      unawaited(scannerController.dispose());
    }
    super.dispose();
  }

  void _setScannerVisible(bool visible) {
    if (!_scanSupported) return;

    if (visible == _showScanner) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _showScanner = visible;
      _scanLock = false;
    });

    if (visible) {
      _scannerController ??= MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
    }
  }

  void _handleDetect(BarcodeCapture capture) {
    if (!_showScanner || _scanLock) return;

    final raw = capture.barcodes
        .map((b) => b.rawValue ?? b.displayValue)
        .whereType<String>()
        .map((s) => s.trim())
        .firstWhere((s) => s.isNotEmpty, orElse: () => '');

    if (raw.isEmpty) return;

    setState(() => _scanLock = true);
    unawaited(HapticFeedback.mediumImpact());
    unawaited(SystemSound.play(SystemSoundType.click));

    _controller.value = TextEditingValue(
      text: raw,
      selection: TextSelection.collapsed(offset: raw.length),
    );
    ref.read(posNotifierProvider.notifier).setQuery(raw);

    _setScannerVisible(false);
  }

  Future<void> _addProductWithQty(
      PosProductDto product, PosNotifier notifier) async {
    double qty = 1;
    if (product.isWeighable) {
      final picked = await _promptWeighableQuantity(context, product);
      if (!mounted) return;
      if (picked == null || picked <= 0) return;
      qty = picked;
    }
    final config = await _configureCartTracking(
      context: context,
      ref: ref,
      product: product,
      quantity: qty,
    );
    if (!mounted) return;
    if (config == null) return;
    notifier.addProduct(
      product,
      qty: qty,
      tracking: config.tracking,
      comboTracking: config.comboTracking ?? const [],
    );
  }

  Widget _buildTextField(
    BuildContext context,
    List<PosProductDto> suggestions,
    PosNotifier notifier,
  ) {
    return SizedBox(
      height: _fieldHeight,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded),
          hintText: 'Search name / barcode…',
          suffixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_scanSupported)
                IconButton(
                  tooltip: 'Scan barcode',
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  onPressed: () => _setScannerVisible(true),
                ),
              IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  _controller.clear();
                  ref.read(posNotifierProvider.notifier).setQuery('');
                },
              ),
            ],
          ),
        ),
        onChanged: notifier.setQuery,
        onSubmitted: (_) {
          if (suggestions.isNotEmpty) {
            unawaited(_addProductWithQty(suggestions.first, notifier));
          }
        },
      ),
    );
  }

  Widget _buildScanner(BuildContext context) {
    final ctrl = _scannerController;

    return SizedBox(
      height: _fieldHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: ctrl,
              onDetect: _handleDetect,
              errorBuilder: (context, error) {
                final scheme = Theme.of(context).colorScheme;
                return ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Camera error: ${error.errorCode.message}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              },
              placeholderBuilder: (_) => ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ctrl != null)
                    ValueListenableBuilder<MobileScannerState>(
                      valueListenable: ctrl,
                      builder: (context, value, _) {
                        final torchState = value.torchState;
                        if (torchState == TorchState.unavailable) {
                          return const SizedBox.shrink();
                        }
                        final isOn = torchState == TorchState.on;
                        return IconButton(
                          tooltip: isOn ? 'Flash off' : 'Flash on',
                          icon: Icon(
                            isOn
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => unawaited(ctrl.toggleTorch()),
                        );
                      },
                    ),
                  IconButton(
                    tooltip: 'Close scanner',
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => _setScannerVisible(false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(posNotifierProvider);
    final notifier = ref.read(posNotifierProvider.notifier);

    if (!_showScanner && _controller.text != state.query) {
      _controller.value = TextEditingValue(
        text: state.query,
        selection: TextSelection.collapsed(offset: state.query.length),
      );
    }

    final suggestions = state.suggestions.take(2).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _showScanner
                ? KeyedSubtree(
                    key: const ValueKey('scanner'),
                    child: _buildScanner(context),
                  )
                : KeyedSubtree(
                    key: const ValueKey('textfield'),
                    child: _buildTextField(context, suggestions, notifier),
                  ),
          ),
          if (!_showScanner && suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: suggestions
                    .map((p) => ListTile(
                          dense: true,
                          title: Text(p.name),
                          subtitle: Text(
                            [
                              'Price: ${p.price.toStringAsFixed(2)}',
                              'Stock: ${p.stock.toStringAsFixed(2)}${_posUnitSuffix(p)}',
                              if ((p.primaryStorage ?? '').trim().isNotEmpty)
                                p.primaryStorage!,
                              if (p.isVirtualCombo) 'Combo',
                            ].join('  •  '),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle_rounded),
                            onPressed: () async =>
                                _addProductWithQty(p, notifier),
                          ),
                          onTap: () async => _addProductWithQty(p, notifier),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _CartList extends ConsumerWidget {
  const _CartList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(posNotifierProvider);
    final notifier = ref.read(posNotifierProvider.notifier);
    if (state.cart.isEmpty) {
      return Center(
        child: Text(
          'No items yet. Search and add products.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemBuilder: (context, index) {
        final item = state.cart[index];
        final trackingLines = _trackingSummaryLines(item);
        return Card(
          child: ListTile(
            title: Row(
              children: [
                Expanded(child: Text(item.product.displayLabel)),
                if (item.discountPercent > 0)
                  Row(children: [
                    const Icon(Icons.local_offer_outlined, size: 16),
                    const SizedBox(width: 4),
                    Text('-${item.discountPercent.toStringAsFixed(0)}%'),
                  ]),
              ],
            ),
            subtitle: Text(
              [
                'Unit: ${item.unitPrice.toStringAsFixed(2)}${_posUnitSuffix(item.product)}',
                ...trackingLines,
              ].join('\n'),
            ),
            leading: IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded),
              onPressed: () async {
                final newQty = (item.quantity - 1).clamp(0.0, 1e9);
                if (newQty == 0) {
                  notifier.removeItem(item);
                } else {
                  if (item.requiresTracking) {
                    final config = await _configureCartTracking(
                      context: context,
                      ref: ref,
                      product: item.product,
                      quantity: newQty,
                      initialTracking: item.tracking,
                      initialComboTracking: item.comboTracking,
                    );
                    if (!context.mounted) return;
                    if (config == null) return;
                    notifier.updateTrackedItem(
                      item,
                      quantity: newQty,
                      tracking: config.tracking,
                      comboTracking: config.comboTracking,
                    );
                  } else {
                    notifier.updateQty(item, newQty);
                  }
                }
              },
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.requiresTracking)
                  IconButton(
                    tooltip: 'Configure tracking',
                    icon: Icon(
                      item.hasTrackingConfigured
                          ? Icons.task_alt_rounded
                          : Icons.qr_code_2_rounded,
                    ),
                    onPressed: () async {
                      final config = await _configureCartTracking(
                        context: context,
                        ref: ref,
                        product: item.product,
                        quantity: item.quantity,
                        initialTracking: item.tracking,
                        initialComboTracking: item.comboTracking,
                      );
                      if (!context.mounted) return;
                      if (config != null) {
                        if (config.comboTracking != null) {
                          notifier.setItemComboTracking(
                            item,
                            config.comboTracking!,
                          );
                        } else if (config.tracking != null) {
                          notifier.setItemTracking(item, config.tracking);
                        }
                      }
                    },
                  ),
                Text(
                    'x ${item.quantity.toStringAsFixed(item.product.isWeighable ? 3 : 0)}  '),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  onPressed: () async {
                    if (item.product.isWeighable) {
                      final extra =
                          await _promptWeighableQuantity(context, item.product);
                      if (!context.mounted) return;
                      if (extra == null || extra <= 0) return;
                      final newQty = item.quantity + extra;
                      if (item.requiresTracking) {
                        final config = await _configureCartTracking(
                          context: context,
                          ref: ref,
                          product: item.product,
                          quantity: newQty,
                          initialTracking: item.tracking,
                          initialComboTracking: item.comboTracking,
                        );
                        if (!context.mounted) return;
                        if (config == null) return;
                        notifier.updateTrackedItem(
                          item,
                          quantity: newQty,
                          tracking: config.tracking,
                          comboTracking: config.comboTracking,
                        );
                      } else {
                        notifier.updateQty(item, newQty);
                      }
                      return;
                    }
                    final newQty = item.quantity + 1;
                    if (item.requiresTracking) {
                      final config = await _configureCartTracking(
                        context: context,
                        ref: ref,
                        product: item.product,
                        quantity: newQty,
                        initialTracking: item.tracking,
                        initialComboTracking: item.comboTracking,
                      );
                      if (!context.mounted) return;
                      if (config == null) return;
                      notifier.updateTrackedItem(
                        item,
                        quantity: newQty,
                        tracking: config.tracking,
                        comboTracking: config.comboTracking,
                      );
                    } else {
                      notifier.updateQty(item, item.quantity + 1);
                    }
                  },
                ),
                const SizedBox(width: 8),
                Text(item.lineTotal.toStringAsFixed(2),
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            onTap: () async {
              final percent = await showDialog<double>(
                context: context,
                builder: (_) => _LineDiscountDialog(
                  initialPercent: item.discountPercent,
                  lineGross: item.quantity * item.unitPrice,
                ),
              );
              if (percent != null) {
                notifier.setItemDiscount(item, percent);
              }
            },
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemCount: state.cart.length,
    );
  }
}

String _posUnitSuffix(PosProductDto product) {
  final symbol = (product.sellingUnitSymbol ?? '').trim();
  if (symbol.isNotEmpty) return ' / $symbol';
  final name = (product.sellingUnitName ?? '').trim();
  if (name.isNotEmpty) return ' / $name';
  return '';
}

Future<double?> _promptWeighableQuantity(
    BuildContext context, PosProductDto product) async {
  final controller = TextEditingController(text: '1');
  final unitLabel = _posUnitSuffix(product).replaceFirst(' / ', '');
  return showDialog<double>(
    context: context,
    builder: (context) => AlertDialog(
      title:
          Text('Enter Quantity${unitLabel.isNotEmpty ? ' ($unitLabel)' : ''}'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Quantity for ${product.name}',
          prefixIcon: const Icon(Icons.scale_outlined),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final qty = double.tryParse(controller.text.trim());
            if (qty == null || qty <= 0) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(content: Text('Enter a quantity above 0')),
                );
              return;
            }
            Navigator.of(context).pop(qty);
          },
          child: const Text('Add'),
        ),
      ],
    ),
  );
}

class _BottomBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(posNotifierProvider);
    final notifier = ref.read(posNotifierProvider.notifier);
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal'),
                      Text(state.subtotal.toStringAsFixed(2)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tax'),
                      Text(state.tax.toStringAsFixed(2)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Builder(builder: (context) {
                    final hasLineDiscount =
                        state.cart.any((i) => i.discountPercent > 0);
                    final lineDisc = state.cart.fold<double>(
                        0.0,
                        (s, i) =>
                            s +
                            (i.quantity *
                                i.unitPrice *
                                (i.discountPercent.clamp(0.0, 100.0) / 100.0)));
                    final displayDiscount =
                        hasLineDiscount ? lineDisc : state.discount;
                    final color = hasLineDiscount
                        ? Theme.of(context).disabledColor
                        : Theme.of(context).colorScheme.onSurface;
                    return InkWell(
                      onTap: hasLineDiscount
                          ? null
                          : () async {
                              final value = await showDialog<double>(
                                context: context,
                                builder: (_) => _DiscountDialog(
                                  initial: state.discount,
                                  preTotal: state.subtotal + state.tax,
                                ),
                              );
                              if (value != null) {
                                notifier.setDiscount(value);
                              }
                            },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Discount', style: TextStyle(color: color)),
                          Text(displayDiscount.toStringAsFixed(2),
                              style: TextStyle(color: color)),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(state.total.toStringAsFixed(2),
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(children: [
                  OutlinedButton.icon(
                    onPressed: state.cart.isEmpty
                        ? null
                        : () async {
                            await notifier.holdCurrent();
                            // Extra nudge to refresh preview immediately in UI
                            await notifier.refreshPreview();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Sale held')),
                              );
                            }
                          },
                    icon: const Icon(Icons.pause_circle_outline_rounded),
                    label: const Text('Hold'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: state.cart.isEmpty
                        ? null
                        : () {
                            notifier.voidCurrent();
                          },
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Void'),
                  ),
                ]),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: state.cart.isEmpty
                      ? null
                      : () async {
                          if (state.cart.any((e) => !e.hasTrackingConfigured)) {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Configure batch / serial details for all tracked items and combo components before payment.',
                                  ),
                                ),
                              );
                            return;
                          }
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const PaymentPage()),
                          );
                        },
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Payment'),
                  style:
                      FilledButton.styleFrom(minimumSize: const Size(180, 48)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<InventoryTrackingSelection?> _configurePosTracking({
  required BuildContext context,
  required WidgetRef ref,
  required PosProductDto product,
  required double quantity,
  InventoryTrackingSelection? initialSelection,
}) {
  return showInventoryTrackingSelector(
    context: context,
    ref: ref,
    productId: product.productId,
    quantity: quantity,
    mode: InventoryTrackingMode.issue,
    productName: product.name,
    initialSelection: initialSelection,
  );
}

Future<_TrackedCartConfig?> _configureCartTracking({
  required BuildContext context,
  required WidgetRef ref,
  required PosProductDto product,
  required double quantity,
  InventoryTrackingSelection? initialTracking,
  List<PosComboComponentTracking> initialComboTracking = const [],
}) async {
  if (product.requiresTracking) {
    final tracking = await _configurePosTracking(
      context: context,
      ref: ref,
      product: product,
      quantity: quantity,
      initialSelection: initialTracking ??
          InventoryTrackingSelection(
            barcodeId: product.barcodeId > 0 ? product.barcodeId : null,
            trackingType: product.trackingType,
            isSerialized: product.isSerialized,
            barcode: product.barcode,
            variantName: product.variantName,
          ),
    );
    if (!context.mounted || tracking == null) return null;
    return _TrackedCartConfig(tracking: tracking);
  }

  final comboProductId = product.comboProductId;
  if ((comboProductId ?? 0) <= 0) {
    return const _TrackedCartConfig();
  }

  final combo = await ref
      .read(inventoryRepositoryProvider)
      .getComboProduct(comboProductId!);
  if (!context.mounted) return null;
  final hasTrackedComponents =
      combo.components.any(_comboComponentRequiresTracking);
  if (!hasTrackedComponents) {
    return const _TrackedCartConfig(
        comboTracking: <PosComboComponentTracking>[]);
  }

  final comboTracking = await showComboTrackingDialog(
    context: context,
    ref: ref,
    combo: combo,
    quantity: quantity,
    initialTracking: initialComboTracking,
  );
  if (!context.mounted || comboTracking == null) return null;
  return _TrackedCartConfig(comboTracking: comboTracking);
}

List<String> _trackingSummaryLines(PosCartItem item) {
  final lines = <String>[];
  if (item.requiresDirectTracking) {
    lines.add(
      item.tracking == null
          ? 'Tracking required'
          : item.tracking!.summary(item.quantity),
    );
  }
  if (item.requiresComboTracking) {
    lines.addAll(
      item.comboTracking
          .where((component) => component.requiresTracking)
          .map((component) => component.summary(item.quantity)),
    );
  }
  return lines;
}

class _TrackedCartConfig {
  const _TrackedCartConfig({
    this.tracking,
    this.comboTracking,
  });

  final InventoryTrackingSelection? tracking;
  final List<PosComboComponentTracking>? comboTracking;
}

bool _comboComponentRequiresTracking(ComboProductComponentDto component) {
  return component.isSerialized || component.trackingType == 'BATCH';
}

class _DiscountDialog extends StatefulWidget {
  const _DiscountDialog({required this.initial, required this.preTotal});
  final double initial; // absolute amount
  final double preTotal; // subtotal + tax to compute percent mode
  @override
  State<_DiscountDialog> createState() => _DiscountDialogState();
}

class _LineDiscountDialog extends StatefulWidget {
  const _LineDiscountDialog(
      {required this.initialPercent, required this.lineGross});
  final double initialPercent; // percent
  final double lineGross; // qty * unit price
  @override
  State<_LineDiscountDialog> createState() => _LineDiscountDialogState();
}

enum _DiscMode { amount, percent }

class _LineDiscountDialogState extends State<_LineDiscountDialog> {
  late final TextEditingController _controller;
  _DiscMode _mode = _DiscMode.percent;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.initialPercent.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Item Discount'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RadioGroup<_DiscMode>(
            groupValue: _mode,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _mode = value);
            },
            child: Row(children: const [
              Radio<_DiscMode>(value: _DiscMode.amount),
              Text('Amount'),
              SizedBox(width: 16),
              Radio<_DiscMode>(value: _DiscMode.percent),
              Text('Percent'),
            ]),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText:
                  _mode == _DiscMode.percent ? 'Discount %' : 'Discount Amount',
              prefixIcon: const Icon(Icons.local_offer_outlined),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final raw = double.tryParse(_controller.text.trim()) ?? 0.0;
            double percent;
            if (_mode == _DiscMode.percent) {
              percent = raw.clamp(0.0, 100.0);
            } else {
              final gross = widget.lineGross <= 0 ? 0.0 : widget.lineGross;
              percent = gross > 0 ? (raw / gross * 100.0) : 0.0;
              percent = percent.clamp(0.0, 100.0);
            }
            Navigator.of(context).pop(percent);
          },
          child: const Text('Apply'),
        )
      ],
    );
  }
}

class _DiscountDialogState extends State<_DiscountDialog> {
  late final TextEditingController _controller;
  _DiscMode _mode = _DiscMode.amount;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.initial.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Discount'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RadioGroup<_DiscMode>(
            groupValue: _mode,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _mode = value);
            },
            child: Row(children: const [
              Radio<_DiscMode>(value: _DiscMode.amount),
              Text('Amount'),
              SizedBox(width: 16),
              Radio<_DiscMode>(value: _DiscMode.percent),
              Text('Percent'),
            ]),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText:
                  _mode == _DiscMode.amount ? 'Discount Amount' : 'Discount %',
              prefixIcon: const Icon(Icons.local_offer_outlined),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final raw = double.tryParse(_controller.text.trim()) ?? 0.0;
            double amount;
            if (_mode == _DiscMode.amount) {
              amount = raw;
            } else {
              final pre = widget.preTotal;
              amount = pre > 0 ? (pre * (raw / 100.0)) : 0.0;
            }
            Navigator.of(context).pop(amount.clamp(0.0, 1e12));
          },
          child: const Text('Apply'),
        )
      ],
    );
  }
}

class _HeldSalesDialog extends ConsumerStatefulWidget {
  const _HeldSalesDialog();
  @override
  ConsumerState<_HeldSalesDialog> createState() => _HeldSalesDialogState();
}

class _HeldSalesDialogState extends ConsumerState<_HeldSalesDialog> {
  bool _loading = true;
  List<HeldSaleDto> _items = const [];
  Object? _error;

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
      final list = await ref.read(posRepositoryProvider).getHeldSales();
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Held Sales'),
      content: SizedBox(
        width: 520,
        height: 420,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? AppErrorView(error: _error!, onRetry: _load)
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final s = _items[index];
                      return ListTile(
                        title: Text(s.saleNumber),
                        subtitle: Text(
                            '${s.customerName ?? 'Walk in'} • ${s.totalAmount.toStringAsFixed(2)}'),
                        trailing: Wrap(spacing: 8, children: [
                          TextButton(
                            onPressed: () async {
                              await ref
                                  .read(posNotifierProvider.notifier)
                                  .loadHeldSaleItems(s.saleId);
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                            },
                            child: const Text('Resume'),
                          ),
                          TextButton(
                            onPressed: () async {
                              final reason = await showDialog<String>(
                                context: context,
                                barrierDismissible: false,
                                builder: (ctx) {
                                  final ctrl = TextEditingController();
                                  bool busy = false;
                                  return StatefulBuilder(
                                    builder: (ctx, setState) => AlertDialog(
                                      title: const Text('Void Reason'),
                                      content: TextField(
                                        controller: ctrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Reason',
                                          prefixIcon:
                                              Icon(Icons.description_outlined),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: busy
                                              ? null
                                              : () => Navigator.of(ctx).pop(),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          onPressed: busy
                                              ? null
                                              : () {
                                                  setState(() => busy = true);
                                                  final v = ctrl.text.trim();
                                                  if (v.isEmpty) {
                                                    setState(
                                                        () => busy = false);
                                                    ScaffoldMessenger.of(ctx)
                                                        .showSnackBar(
                                                      const SnackBar(
                                                          content: Text(
                                                              'Reason is required')),
                                                    );
                                                    return;
                                                  }
                                                  Navigator.of(ctx).pop(v);
                                                },
                                          child: const Text('Continue'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                              if (reason == null || reason.trim().isEmpty) {
                                return;
                              }

                              final repo = ref.read(posRepositoryProvider);
                              try {
                                await repo.voidSaleWithReason(
                                  s.saleId,
                                  reason: reason,
                                );
                              } on DioException catch (e) {
                                final data = e.response?.data;
                                final maybe =
                                    (data is Map && data['data'] is Map)
                                        ? Map<String, dynamic>.from(
                                            data['data'] as Map)
                                        : null;
                                if (e.response?.statusCode == 403 &&
                                    maybe?['code'] == 'OVERRIDE_REQUIRED') {
                                  if (!context.mounted) return;
                                  final perms =
                                      (maybe?['required_permissions'] as List?)
                                              ?.map((x) => x.toString())
                                              .toList() ??
                                          const <String>[];
                                  final approved =
                                      await showManagerOverrideDialog(
                                    context,
                                    ref,
                                    title: 'Manager override required (void)',
                                    requiredPermissions: perms,
                                  );
                                  if (!context.mounted) return;
                                  if (approved == null) return;
                                  await repo.voidSaleWithReason(
                                    s.saleId,
                                    reason: reason,
                                    managerOverrideToken:
                                        approved.overrideToken,
                                  );
                                } else {
                                  rethrow;
                                }
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(
                                        content: Text(ErrorHandler.message(e))),
                                  );
                                return;
                              }
                              // After voiding, refresh the receipt preview on POS
                              await ref
                                  .read(posNotifierProvider.notifier)
                                  .refreshPreview();
                              await _load();
                            },
                            child: const Text('Void'),
                          ),
                        ]),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close')),
      ],
    );
  }
}
