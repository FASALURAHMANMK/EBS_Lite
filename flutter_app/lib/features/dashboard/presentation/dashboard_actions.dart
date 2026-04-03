import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/location_notifier.dart';
import '../data/models.dart';
import '../../customers/presentation/widgets/quick_collection_sheet.dart';
import '../../customers/presentation/pages/customer_management_page.dart';
import '../../expenses/presentation/widgets/quick_expense_sheet.dart';
import '../../inventory/presentation/pages/inventory_management_page.dart';
import '../../pos/controllers/pos_notifier.dart';
import '../../pos/presentation/pages/pos_page.dart';
import '../../purchases/presentation/pages/grn_form_page.dart';
import '../../accounts/presentation/pages/cash_register_page.dart';

class DashboardActionDefinition {
  const DashboardActionDefinition({
    required this.id,
    required this.label,
    required this.icon,
    this.requiresLocation = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final bool requiresLocation;
}

const dashboardActions = <DashboardActionDefinition>[
  DashboardActionDefinition(
    id: 'new_sale',
    label: 'New Sale',
    icon: Icons.point_of_sale_rounded,
  ),
  DashboardActionDefinition(
    id: 'new_purchase',
    label: 'New Purchase / GRN',
    icon: Icons.shopping_cart_rounded,
    requiresLocation: true,
  ),
  DashboardActionDefinition(
    id: 'new_collection',
    label: 'New Collection',
    icon: Icons.payments_rounded,
    requiresLocation: true,
  ),
  DashboardActionDefinition(
    id: 'new_expense',
    label: 'New Expense',
    icon: Icons.money_off_rounded,
    requiresLocation: true,
  ),
  DashboardActionDefinition(
    id: 'products',
    label: 'Products',
    icon: Icons.inventory_rounded,
  ),
  DashboardActionDefinition(
    id: 'customers',
    label: 'Customers',
    icon: Icons.people_alt_rounded,
  ),
  DashboardActionDefinition(
    id: 'cash_register',
    label: 'Cash Register',
    icon: Icons.account_balance_wallet_rounded,
    requiresLocation: true,
  ),
];

DashboardActionDefinition? dashboardActionForId(String id) {
  for (final a in dashboardActions) {
    if (a.id == id) return a;
  }
  return null;
}

Future<void> runDashboardAction(
  BuildContext context,
  WidgetRef ref,
  String actionId,
) async {
  final def = dashboardActionForId(actionId);
  if (def == null) return;

  if (def.requiresLocation) {
    final locId = await _ensureLocationSelected(context, ref);
    if (locId == null || !context.mounted) return;
  }

  switch (actionId) {
    case 'new_sale':
      ref
          .read(posNotifierProvider.notifier)
          .startNewSaleSession(transactionType: 'RETAIL');
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PosPage()),
      );
      return;
    case 'new_purchase':
      final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const GrnFormPage()),
      );
      if (!context.mounted) return;
      if (created == true) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Purchase/GRN created')));
      }
      return;
    case 'new_collection':
      await showQuickCollectionSheet(context, ref);
      return;
    case 'new_expense':
      await showQuickExpenseSheet(context, ref);
      return;
    case 'products':
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const InventoryManagementPage()),
      );
      return;
    case 'customers':
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CustomerManagementPage()),
      );
      return;
    case 'cash_register':
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CashRegisterPage()),
      );
      return;
  }
}

Future<int?> _ensureLocationSelected(
    BuildContext context, WidgetRef ref) async {
  final state = ref.read(locationNotifierProvider);
  final selected = state.selected;
  if (selected != null) return selected.locationId;

  if (state.locations.isNotEmpty) {
    await _showLocationPicker(context, ref, state.locations);
    return ref.read(locationNotifierProvider).selected?.locationId;
  }

  if (!context.mounted) return null;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('No locations available')));
  return null;
}

Future<void> _showLocationPicker(
  BuildContext context,
  WidgetRef ref,
  List<Location> locations,
) async {
  final notifier = ref.read(locationNotifierProvider.notifier);
  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Select Location'),
        content: SizedBox(
          width: 360,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: locations.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final loc = locations[index];
              return ListTile(
                title: Text(loc.name),
                onTap: () async {
                  await notifier.select(loc);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      );
    },
  );
}
