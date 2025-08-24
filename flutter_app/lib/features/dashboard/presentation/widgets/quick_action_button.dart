import 'package:flutter/material.dart';

class QuickActionButton extends StatefulWidget {
  const QuickActionButton({super.key});

  @override
  State<QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<QuickActionButton>
    with SingleTickerProviderStateMixin {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          if (_open) ...[
            Positioned(
              right: 100,
              bottom: 0,
              child: _miniButton(Icons.point_of_sale, 'Sale'),
            ),
            Positioned(
              right: 70,
              bottom: 70,
              child: _miniButton(Icons.shopping_cart, 'Purchase'),
            ),
            Positioned(
              right: 0,
              bottom: 100,
              child: _miniButton(Icons.payment, 'Collection'),
            ),
            Positioned(
              right: 120,
              bottom: 120,
              child: _miniButton(Icons.money_off, 'Expense'),
            ),
          ],
          FloatingActionButton(
            onPressed: () => setState(() => _open = !_open),
            child: Icon(_open ? Icons.close : Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _miniButton(IconData icon, String tooltip) {
    return FloatingActionButton.small(
      heroTag: tooltip,
      tooltip: tooltip,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      onPressed: () {},
      child: Icon(icon),
    );
  }
}
