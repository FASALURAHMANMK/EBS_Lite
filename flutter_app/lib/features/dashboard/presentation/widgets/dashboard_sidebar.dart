import 'package:flutter/material.dart';

class DashboardSidebar extends StatelessWidget {
  const DashboardSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.black),
            child: Row(
              children: const [
                Icon(Icons.business, color: Colors.red, size: 32),
                SizedBox(width: 8),
                Text('Menu', style: TextStyle(color: Colors.white, fontSize: 18)),
              ],
            ),
          ),
          _item(context, Icons.dashboard, 'Dashboard'),
          _item(context, Icons.point_of_sale, 'Sales'),
          _item(context, Icons.people, 'Customers'),
          _item(context, Icons.shopping_cart, 'Purchases'),
          _item(context, Icons.inventory, 'Inventory'),
          _item(context, Icons.account_balance, 'Accounting'),
          _item(context, Icons.bar_chart, 'Reports'),
          _item(context, Icons.group, 'HR'),
          _item(context, Icons.settings, 'Settings'),
        ],
      ),
    );
  }

  ListTile _item(BuildContext context, IconData icon, String label) {
    return ListTile(
      leading: Icon(icon, color: Colors.red),
      title: Text(label),
      onTap: () => Navigator.pop(context),
    );
  }
}
