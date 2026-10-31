import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ErpDashboardPage extends StatelessWidget {
  const ErpDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cards = <({String label, String value, IconData icon})>[
      (label: 'Today’s invoices', value: '0', icon: Icons.receipt_long),
      (label: 'Pending jobs', value: '0', icon: Icons.assignment),
      (label: 'Low stock items', value: '0', icon: Icons.inventory_2),
      (label: 'Cash register', value: '৳0.00', icon: Icons.account_balance_wallet),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Al-Noor Digital Print House'), actions: [IconButton(tooltip: 'Legacy POS scanner', onPressed: () => context.go('/'), icon: const Icon(Icons.qr_code_scanner))]),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('ERP / POS workspace', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('Manage print jobs, billing, stock, and daily cash from one place.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          const Chip(avatar: Icon(Icons.admin_panel_settings, size: 18), label: Text('Signed in as ADMIN')),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 260, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.55),
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final card = cards[index];
              return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(card.icon, color: Theme.of(context).colorScheme.primary), const Spacer(), Text(card.value, style: Theme.of(context).textTheme.headlineSmall), Text(card.label)])));
            },
          ),
          const SizedBox(height: 24),
          Card(child: Column(children: [
            ListTile(leading: const Icon(Icons.point_of_sale), title: const Text('Create print invoice'), subtitle: const Text('SQFT / PCS pricing, add-ons, and split payments'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/erp/invoice')),
            const Divider(height: 1),
            ListTile(leading: const Icon(Icons.print), title: const Text('Print layout settings'), subtitle: const Text('WITH_PAD / WITHOUT_PAD and millimetre margins'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/erp/print-preview')),
          ])),
        ],
      ),
    );
  }
}
