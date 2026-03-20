import 'package:flutter/material.dart';

import '../../data/models.dart';

class EditableCostAdjustmentRow {
  EditableCostAdjustmentRow({
    String? label,
    String? amount,
    this.direction = 'EXPENSE',
  })  : labelController = TextEditingController(text: label ?? ''),
        amountController = TextEditingController(text: amount ?? '');

  final TextEditingController labelController;
  final TextEditingController amountController;
  String direction;

  CostAdjustmentDraft? toDraft() {
    final label = labelController.text.trim();
    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    if (label.isEmpty || amount <= 0) return null;
    return CostAdjustmentDraft(
      label: label,
      amount: amount,
      direction: direction,
    );
  }

  void dispose() {
    labelController.dispose();
    amountController.dispose();
  }
}

class CostAdjustmentListEditor extends StatelessWidget {
  const CostAdjustmentListEditor({
    super.key,
    required this.title,
    required this.rows,
    required this.onAdd,
    required this.onChanged,
    required this.onRemove,
    this.emptyLabel = 'No add-ons added',
  });

  final String title;
  final List<EditableCostAdjustmentRow> rows;
  final VoidCallback onAdd;
  final VoidCallback onChanged;
  final void Function(int index) onRemove;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              Text(
                emptyLabel,
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ...rows.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: entry.value.labelController,
                              onChanged: (_) => onChanged(),
                              decoration: const InputDecoration(
                                labelText: 'Label',
                                prefixIcon: Icon(Icons.label_outline_rounded),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: entry.value.amountController,
                              onChanged: (_) => onChanged(),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Amount',
                                prefixIcon:
                                    Icon(Icons.currency_exchange_rounded),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: entry.value.direction,
                              items: const [
                                DropdownMenuItem(
                                  value: 'EXPENSE',
                                  child: Text('Expense'),
                                ),
                                DropdownMenuItem(
                                  value: 'INCOME',
                                  child: Text('Income'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                entry.value.direction = value;
                                onChanged();
                              },
                              decoration: const InputDecoration(
                                labelText: 'Type',
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            onPressed: () => onRemove(entry.key),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
