import 'package:flutter/material.dart';

import '../../data/models.dart';

const List<String> kProductStorageTypes = <String>[
  'Shelf',
  'Rack',
  'Box',
  'Bin',
  'Warehouse',
  'Showcase',
  'Other',
];

class ProductStorageEditor extends StatefulWidget {
  const ProductStorageEditor({
    super.key,
    required this.entries,
    required this.barcodes,
    required this.onChanged,
    this.enabled = true,
    this.locationLabel,
  });

  final List<ProductStorageAssignmentPayload> entries;
  final List<ProductBarcodeDto> barcodes;
  final ValueChanged<List<ProductStorageAssignmentPayload>> onChanged;
  final bool enabled;
  final String? locationLabel;

  @override
  State<ProductStorageEditor> createState() => _ProductStorageEditorState();
}

class _ProductStorageEditorState extends State<ProductStorageEditor> {
  late List<ProductStorageAssignmentPayload> _entries;

  @override
  void initState() {
    super.initState();
    _entries = List<ProductStorageAssignmentPayload>.from(widget.entries);
  }

  @override
  void didUpdateWidget(covariant ProductStorageEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries != widget.entries) {
      _entries = List<ProductStorageAssignmentPayload>.from(widget.entries);
    }
  }

  void _emit() {
    widget.onChanged(List<ProductStorageAssignmentPayload>.from(_entries));
  }

  String? _defaultBarcode() {
    if (widget.barcodes.isEmpty) return null;
    final primary = widget.barcodes.where((e) => e.isPrimary);
    if (primary.isNotEmpty) return primary.first.barcode;
    return widget.barcodes.first.barcode;
  }

  void _addEntry() {
    setState(() {
      _entries = [
        ..._entries,
        ProductStorageAssignmentPayload(
          barcode: _defaultBarcode(),
          storageType: kProductStorageTypes.first,
          storageLabel: '',
          notes: null,
          isPrimary: _entries.isEmpty,
          sortOrder: _entries.length + 1,
        ),
      ];
    });
    _emit();
  }

  void _updateEntry(int index, ProductStorageAssignmentPayload next) {
    setState(() {
      _entries[index] = next;
    });
    _emit();
  }

  void _removeEntry(int index) {
    setState(() {
      _entries.removeAt(index);
      _entries = [
        for (var i = 0; i < _entries.length; i++)
          ProductStorageAssignmentPayload(
            storageAssignmentId: _entries[i].storageAssignmentId,
            barcodeId: _entries[i].barcodeId,
            barcode: _entries[i].barcode,
            storageType: _entries[i].storageType,
            storageLabel: _entries[i].storageLabel,
            notes: _entries[i].notes,
            isPrimary: _entries[i].isPrimary && i == 0,
            sortOrder: i + 1,
          ),
      ];
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locationText = (widget.locationLabel ?? '').trim();
    if (widget.barcodes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Add product barcodes or variations first to map storage.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  locationText.isEmpty
                      ? 'Storage is managed for the currently selected location.'
                      : 'Storage for $locationText',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_entries.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 28),
                const SizedBox(height: 10),
                Text(
                  'No storage slots added yet',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Track shelf, rack, box, or any other storage position for each variation.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ..._entries.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Storage ${index + 1}',
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          onPressed:
                              widget.enabled ? () => _removeEntry(index) : null,
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ),
                    DropdownButtonFormField<String>(
                      initialValue:
                          widget.barcodes.any((b) => b.barcode == item.barcode)
                              ? item.barcode
                              : _defaultBarcode(),
                      decoration: const InputDecoration(
                        labelText: 'Variation / Barcode',
                      ),
                      items: widget.barcodes
                          .map(
                            (barcode) => DropdownMenuItem<String>(
                              value: barcode.barcode,
                              child: Text(
                                [
                                  barcode.variantName ?? '',
                                  barcode.barcode,
                                ].where((e) => e.trim().isNotEmpty).join(' • '),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: widget.enabled
                          ? (value) {
                              _updateEntry(
                                index,
                                ProductStorageAssignmentPayload(
                                  storageAssignmentId: item.storageAssignmentId,
                                  barcode: value,
                                  storageType: item.storageType,
                                  storageLabel: item.storageLabel,
                                  notes: item.notes,
                                  isPrimary: item.isPrimary,
                                  sortOrder: index + 1,
                                ),
                              );
                            }
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue:
                                kProductStorageTypes.contains(item.storageType)
                                    ? item.storageType
                                    : kProductStorageTypes.first,
                            decoration: const InputDecoration(
                              labelText: 'Type',
                            ),
                            items: kProductStorageTypes
                                .map(
                                  (type) => DropdownMenuItem<String>(
                                    value: type,
                                    child: Text(type),
                                  ),
                                )
                                .toList(),
                            onChanged: widget.enabled
                                ? (value) {
                                    if (value == null) return;
                                    _updateEntry(
                                      index,
                                      ProductStorageAssignmentPayload(
                                        storageAssignmentId:
                                            item.storageAssignmentId,
                                        barcode: item.barcode,
                                        storageType: value,
                                        storageLabel: item.storageLabel,
                                        notes: item.notes,
                                        isPrimary: item.isPrimary,
                                        sortOrder: index + 1,
                                      ),
                                    );
                                  }
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            key: ValueKey(
                                'storage-label-$index-${item.barcode}'),
                            initialValue: item.storageLabel,
                            enabled: widget.enabled,
                            decoration: const InputDecoration(
                              labelText: 'Label',
                              hintText: 'A-02 / Box 4',
                            ),
                            onChanged: (value) => _updateEntry(
                              index,
                              ProductStorageAssignmentPayload(
                                storageAssignmentId: item.storageAssignmentId,
                                barcode: item.barcode,
                                storageType: item.storageType,
                                storageLabel: value,
                                notes: item.notes,
                                isPrimary: item.isPrimary,
                                sortOrder: index + 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: ValueKey('storage-notes-$index-${item.barcode}'),
                      initialValue: item.notes,
                      enabled: widget.enabled,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Front aisle, cold shelf, display stack...',
                      ),
                      onChanged: (value) => _updateEntry(
                        index,
                        ProductStorageAssignmentPayload(
                          storageAssignmentId: item.storageAssignmentId,
                          barcode: item.barcode,
                          storageType: item.storageType,
                          storageLabel: item.storageLabel,
                          notes: value,
                          isPrimary: item.isPrimary,
                          sortOrder: index + 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile.adaptive(
                      value: item.isPrimary,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Primary location'),
                      subtitle: const Text(
                        'Use this as the main pick/put-away reference in the selected location.',
                      ),
                      onChanged: widget.enabled
                          ? (value) {
                              setState(() {
                                _entries = [
                                  for (var i = 0; i < _entries.length; i++)
                                    ProductStorageAssignmentPayload(
                                      storageAssignmentId:
                                          _entries[i].storageAssignmentId,
                                      barcodeId: _entries[i].barcodeId,
                                      barcode: _entries[i].barcode,
                                      storageType: _entries[i].storageType,
                                      storageLabel: _entries[i].storageLabel,
                                      notes: _entries[i].notes,
                                      isPrimary: i == index ? value : false,
                                      sortOrder: i + 1,
                                    ),
                                ];
                              });
                              _emit();
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: widget.enabled ? _addEntry : null,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add storage slot'),
        ),
      ],
    );
  }
}
