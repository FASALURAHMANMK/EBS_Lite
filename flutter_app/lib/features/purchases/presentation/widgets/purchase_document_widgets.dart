import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_selection_dialog.dart';
import '../../../../shared/widgets/professional_document_widgets.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../inventory/data/models.dart';
import '../../../suppliers/data/models.dart';
import '../../../suppliers/data/supplier_repository.dart';

class PurchaseDocumentMetricCard extends StatelessWidget {
  const PurchaseDocumentMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.subtitle,
    this.tint = const Color(0xFFEAF1F8),
    this.foreground = const Color(0xFF23415F),
  });

  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color tint;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: foreground.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: foreground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: foreground,
                      ),
                ),
                if ((subtitle ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: foreground.withValues(alpha: 0.82),
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

ProfessionalBadge purchaseStatusBadge(String status) {
  final normalized = status.trim().toUpperCase();
  switch (normalized) {
    case 'RECEIVED':
      return const ProfessionalBadge(
        label: 'Received',
        backgroundColor: Color(0xFFE8F3EC),
        foregroundColor: Color(0xFF255C35),
      );
    case 'PARTIALLY_RECEIVED':
      return const ProfessionalBadge(
        label: 'Partially Received',
        backgroundColor: Color(0xFFFFF1D6),
        foregroundColor: Color(0xFF8A5200),
      );
    case 'APPROVED':
      return const ProfessionalBadge(
        label: 'Approved',
        backgroundColor: Color(0xFFE3F0FF),
        foregroundColor: Color(0xFF1B4F8C),
      );
    case 'PENDING':
      return const ProfessionalBadge(
        label: 'Pending',
        backgroundColor: Color(0xFFFFF1D6),
        foregroundColor: Color(0xFF8A5200),
      );
    case 'DRAFT':
      return const ProfessionalBadge(
        label: 'Draft',
        backgroundColor: Color(0xFFEAF1F8),
        foregroundColor: Color(0xFF23415F),
      );
    default:
      return ProfessionalBadge(
        label: normalized.isEmpty ? 'Open' : normalized.replaceAll('_', ' '),
      );
  }
}

class PurchaseDocumentListCard extends StatelessWidget {
  const PurchaseDocumentListCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badges,
    this.trailing,
    this.selected = false,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final List<Widget> badges;
  final Widget? trailing;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.32)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.55)
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing!,
                ],
              ],
            ),
            if (subtitle.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
            if (badges.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: badges,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PurchaseSupplierPicker extends ConsumerWidget {
  const PurchaseSupplierPicker({
    super.key,
    this.supplierId,
    this.supplierName,
    required this.onPicked,
  });

  final int? supplierId;
  final String? supplierName;
  final void Function(int id, String name) onPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = supplierName ??
        (supplierId == null
            ? 'Tap to select supplier'
            : 'Supplier #$supplierId');
    return InkWell(
      onTap: () async {
        final picked = await _openSupplierPicker(context, ref);
        if (picked != null) {
          onPicked(picked.supplierId, picked.supplierName);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Supplier',
          prefixIcon: Icon(Icons.local_shipping_outlined),
          border: OutlineInputBorder(),
        ),
        child: Row(
          children: [
            Expanded(child: Text(display, overflow: TextOverflow.ellipsis)),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ),
      ),
    );
  }

  Future<({int supplierId, String supplierName})?> _openSupplierPicker(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final repo = ref.read(supplierRepositoryProvider);
    List<SupplierDto> results = [];
    try {
      results = await repo.getSuppliers();
    } catch (_) {}
    int? selected = supplierId;
    if (!context.mounted) return null;
    return showDialog<({int supplierId, String supplierName})?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AppSelectionDialog(
          title: 'Select Supplier',
          maxWidth: 720,
          searchField: TextField(
            decoration: const InputDecoration(
              hintText: 'Search suppliers',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (value) async {
              final query = value.trim();
              try {
                final list = await repo.getSuppliers(
                    search: query.isEmpty ? null : query);
                setInner(() => results = list);
              } catch (_) {}
            },
          ),
          body: results.isEmpty
              ? const Center(child: Text('No suppliers'))
              : RadioGroup<int>(
                  groupValue: selected,
                  onChanged: (value) => setInner(() => selected = value),
                  child: ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final supplier = results[index];
                      return RadioListTile<int>(
                        value: supplier.supplierId,
                        title: Text(supplier.name),
                        subtitle: Text(
                          [(supplier.phone ?? ''), (supplier.email ?? '')]
                              .where((value) => value.isNotEmpty)
                              .join(' • '),
                        ),
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final supplier = results.firstWhere(
                  (item) => item.supplierId == selected,
                  orElse: () => results.isEmpty
                      ? SupplierDto(
                          supplierId: -1,
                          name: '',
                          contactPerson: null,
                          phone: null,
                          email: null,
                          address: null,
                          paymentTerms: 0,
                          creditLimit: 0,
                          isMercantile: true,
                          isNonMercantile: false,
                          isActive: true,
                          totalPurchases: 0,
                          totalReturns: 0,
                          outstandingAmount: 0,
                          lastPurchaseDate: null,
                        )
                      : results.first,
                );
                if (supplier.supplierId <= 0) {
                  Navigator.pop(context, null);
                  return;
                }
                Navigator.pop(
                  context,
                  (
                    supplierId: supplier.supplierId,
                    supplierName: supplier.name,
                  ),
                );
              },
              child: const Text('Select'),
            ),
          ],
        ),
      ),
    );
  }
}

class PurchaseProductPicker extends ConsumerStatefulWidget {
  const PurchaseProductPicker({
    super.key,
    required this.product,
    required this.onPicked,
    this.selectedVariantName,
    this.labelText = 'Product',
    this.emptyText = 'Tap to select a product',
  });

  final InventoryListItem? product;
  final String? selectedVariantName;
  final void Function(InventoryListItem product) onPicked;
  final String labelText;
  final String emptyText;

  @override
  ConsumerState<PurchaseProductPicker> createState() =>
      _PurchaseProductPickerState();
}

class _PurchaseProductPickerState extends ConsumerState<PurchaseProductPicker> {
  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final variantName = (widget.selectedVariantName ?? '').trim();
    return InkWell(
      onTap: () async {
        final picked = await _openProductPicker(context);
        if (picked != null) {
          widget.onPicked(picked);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: widget.labelText,
          prefixIcon: const Icon(Icons.inventory_2_rounded),
          border: const OutlineInputBorder(),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                product == null
                    ? widget.emptyText
                    : [
                        product.name,
                        if (variantName.isNotEmpty) variantName,
                        if ((product.variantName ?? '').trim().isNotEmpty &&
                            product.variantName!.trim() != variantName)
                          product.variantName!.trim(),
                        if ((product.sku ?? '').isNotEmpty)
                          'SKU: ${product.sku}',
                      ].join(' • '),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ),
      ),
    );
  }

  Future<InventoryListItem?> _openProductPicker(BuildContext context) async {
    final repo = ref.read(inventoryRepositoryProvider);
    List<InventoryListItem> initial = [];
    try {
      initial = await repo.getStock();
    } catch (_) {}
    List<InventoryListItem> results = List.of(initial);
    int? selectedId = widget.product?.productId;
    if (!context.mounted) return null;
    return showDialog<InventoryListItem?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AppSelectionDialog(
          title: 'Select Product',
          maxWidth: 720,
          searchField: TextField(
            decoration: const InputDecoration(
              hintText: 'Search by name or SKU',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (value) async {
              final query = value.trim();
              if (query.isEmpty) {
                setInner(() => results = List.of(initial));
                return;
              }
              final list = await repo.searchProducts(query);
              setInner(() => results = list);
            },
          ),
          body: results.isEmpty
              ? const Center(child: Text('No products'))
              : RadioGroup<int>(
                  groupValue: selectedId,
                  onChanged: (value) => setInner(() => selectedId = value),
                  child: ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final item = results[index];
                      return RadioListTile<int>(
                        value: item.productId,
                        title: Text(item.name),
                        subtitle: Text(
                          [
                            if ((item.variantName ?? '').trim().isNotEmpty)
                              'Var: ${item.variantName!.trim()}',
                            if ((item.sku ?? '').isNotEmpty) 'SKU: ${item.sku}',
                            'Stock: ${item.stock.toStringAsFixed(2)}',
                          ].join(' • '),
                        ),
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final item = results.firstWhere(
                  (entry) => entry.productId == selectedId,
                  orElse: () => InventoryListItem(
                    productId: -1,
                    name: '',
                    sku: null,
                    categoryName: null,
                    brandName: null,
                    unitSymbol: null,
                    reorderLevel: 0,
                    stock: 0,
                    isLowStock: false,
                    price: null,
                  ),
                );
                Navigator.pop(context, item.productId == -1 ? null : item);
              },
              child: const Text('Select'),
            ),
          ],
        ),
      ),
    );
  }
}
