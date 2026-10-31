import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/business_models.dart';

class OperationsDashboardPage extends StatefulWidget {
  const OperationsDashboardPage({super.key});

  @override
  State<OperationsDashboardPage> createState() =>
      _OperationsDashboardPageState();
}

class _OperationsDashboardPageState extends State<OperationsDashboardPage> {
  int _selectedIndex = 0;
  final _currency = NumberFormat.currency(symbol: '৳', decimalDigits: 0);

  static const _navItems = [
    (Icons.dashboard_outlined, Icons.dashboard, 'Overview'),
    (Icons.people_outline, Icons.people, 'Customers'),
    (Icons.category_outlined, Icons.category, 'Rate cards'),
    (Icons.inventory_2_outlined, Icons.inventory_2, 'Inventory'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Documents'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final content = _buildContent();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Al-Noor Digital Print House'),
            actions: [
              IconButton(
                tooltip: 'Point of sale',
                onPressed: () => context.push('/pos'),
                icon: const Icon(Icons.point_of_sale_outlined),
              ),
              IconButton(
                tooltip: 'Settings',
                onPressed: () => context.push('/settings'),
                icon: const Icon(Icons.settings_outlined),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Row(
            children: [
              if (wide) _buildRail(),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: content,
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: wide ? null : NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            destinations: _navItems
                .take(4)
                .map((item) => NavigationDestination(
                      icon: Icon(item.$1),
                      selectedIcon: Icon(item.$2),
                      label: item.$3,
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildRail() {
    return NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) =>
          setState(() => _selectedIndex = index),
      labelType: NavigationRailLabelType.all,
      destinations: _navItems
          .map((item) => NavigationRailDestination(
                icon: Icon(item.$1),
                selectedIcon: Icon(item.$2),
                label: Text(item.$3),
              ))
          .toList(),
    );
  }

  Widget _buildContent() {
    if (_selectedIndex == 0) return _buildOverview();
    final label = _navItems[_selectedIndex].$3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'This workspace is ready for $label. Use the quick actions below to start building today’s production queue.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        _buildQuickActions(),
      ],
    );
  }

  Widget _buildOverview() {
    return ListView(
      shrinkWrap: true,
      children: [
        Text('Good morning, Admin', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(DateFormat('EEEE, d MMMM yyyy').format(DateTime.now())),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _metric('Today’s sales', _currency.format(24500), Icons.trending_up, Colors.green),
            _metric('Outstanding', _currency.format(18200), Icons.account_balance_wallet_outlined, Colors.orange),
            _metric('In production', '12 jobs', Icons.precision_manufacturing_outlined, Colors.blue),
            _metric('Low stock', '4 items', Icons.warning_amber_outlined, Colors.red),
          ],
        ),
        const SizedBox(height: 28),
        _buildQuickActions(),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              Expanded(child: _buildCashCard()),
              const SizedBox(width: 16),
              Expanded(child: _buildActivityCard()),
            ];
            if (constraints.maxWidth < 700) {
              return Column(
                children: [
                  _buildCashCard(),
                  const SizedBox(height: 16),
                  _buildActivityCard(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: cards,
            );
          },
        ),
      ],
    );
  }

  Widget _metric(String label, String value, IconData icon, Color color) {
    return SizedBox(
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: .12),
                foregroundColor: color,
                child: Icon(icon),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      ('New quotation', Icons.request_quote_outlined, () => _showBillingDialog()),
      ('New invoice', Icons.receipt_long_outlined, () => _showBillingDialog()),
      ('Add customer', Icons.person_add_alt_1_outlined, () => _showAddPartyDialog(false)),
      ('Stock in', Icons.add_box_outlined, () => _showStockDialog()),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick actions', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: actions
              .map((action) => OutlinedButton.icon(
                    onPressed: action.$3,
                    icon: Icon(action.$2),
                    label: Text(action.$1),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildCashCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily cash position', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 18),
            _cashRow('Opening balance', 5000),
            _cashRow('Cash received', 24500),
            _cashRow('Expenses', -3200),
            const Divider(),
            _cashRow('Expected closing', 26300, strong: true),
          ],
        ),
      ),
    );
  }

  Widget _cashRow(String label, double amount, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            _currency.format(amount),
            style: TextStyle(fontWeight: strong ? FontWeight.bold : null),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent activity', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Icon(Icons.receipt_long_outlined)),
              title: Text('Invoice INV-1008 created'),
              subtitle: Text('Rahman Traders · 10:24 AM'),
              trailing: Text('৳8,400'),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Icon(Icons.payments_outlined)),
              title: Text('Payment received'),
              subtitle: Text('Nusrat Jahan · 09:48 AM'),
              trailing: Text('৳3,000'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddPartyDialog(bool supplier) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${supplier ? 'supplier' : 'customer'}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _showStockDialog() => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Stock in'),
          content: const Text('Record paper, ink, or finishing material received from a supplier.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
        ),
      );

  Future<void> _showBillingDialog() => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('New print document'),
          content: const Text('Area and piece billing, add-ons, discounts, payments, and job-slip printing are available in the billing workspace.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/pos');
              },
              child: const Text('Open billing'),
            ),
          ],
        ),
      );

  // Keeps the business calculator close to the first billing workflow.
  BillTotals previewBill() => BusinessCalculator.calculateBill(
        lines: const [
          BillingLineInput(
            description: 'Visiting card',
            unit: BillingUnit.piece,
            unitRate: 4,
            pieces: 100,
          ),
        ],
      );
}
