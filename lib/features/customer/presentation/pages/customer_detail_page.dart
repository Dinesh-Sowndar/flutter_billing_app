import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/service_locator.dart';
import '../../../billing/data/models/transaction_model.dart';
import '../../../billing/domain/repositories/billing_repository.dart';
import '../../domain/entities/customer_entity.dart';
import '../../data/models/customer_model.dart';
import '../../domain/repositories/customer_repository.dart';
import '../bloc/customer_bloc.dart';
import '../bloc/customer_event.dart';

class CustomerDetailPage extends StatelessWidget {
  final CustomerEntity customer;
  const CustomerDetailPage({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: HiveDatabase.customerBox.listenable(),
      builder: (context, Box<CustomerModel> box, _) {
        final currentCustomerModel = box.get(customer.id);
        final currentCustomer = currentCustomerModel?.toEntity() ?? customer;

        return ValueListenableBuilder(
          valueListenable: HiveDatabase.transactionBox.listenable(),
          builder: (context, Box<TransactionModel> txBox, _) {
            final transactions = txBox.values
                .where((t) => t.customerId == currentCustomer.id)
                .toList()
              ..sort((a, b) => b.date.compareTo(a.date));
            final ledgerDue = _calculateCurrentDue(transactions);

            final totalSpent = transactions.fold(0.0,
                (sum, t) => sum + (t.items.isNotEmpty ? t.totalAmount : 0));

            return Scaffold(
              backgroundColor: const Color(0xFFF8FAFC),
              appBar: AppBar(
                title: Text(currentCustomer.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1E293B),
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                actions: [
                  if (ledgerDue > 0)
                    TextButton.icon(
                      onPressed: () =>
                          _showPaymentDialog(context, currentCustomer, ledgerDue),
                      icon:
                          const Icon(Icons.payments, color: Color(0xFF10B981)),
                      label: const Text('Pay Due',
                          style: TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => context.push(
                  '/customers/${currentCustomer.id}/purchase',
                  extra: currentCustomer,
                ),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Buy',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              body: Column(
                children: [
                  // Customer info + stats header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border:
                          Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor:
                              const Color(0xFF6C63FF).withValues(alpha: 0.1),
                          child: Text(
                            currentCustomer.name.isNotEmpty
                                ? currentCustomer.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Color(0xFF6C63FF),
                                fontWeight: FontWeight.bold,
                                fontSize: 24),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(currentCustomer.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.phone_outlined,
                                      size: 14, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 4),
                                  Text(currentCustomer.phone,
                                      style: const TextStyle(
                                          color: Color(0xFF64748B))),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${ledgerDue.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: ledgerDue > 0
                                    ? Colors.red
                                    : const Color(0xFF10B981),
                              ),
                            ),
                            const Text('Due Balance',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF94A3B8))),
                            const SizedBox(height: 4),
                            Text('₹${totalSpent.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF10B981))),
                            const Text('total spent',
                                style: TextStyle(
                                    fontSize: 11, color: Color(0xFF94A3B8))),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Purchase history list
                  Expanded(
                    child: transactions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.receipt_long_rounded,
                                    size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                const Text('No history yet',
                                    style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF94A3B8))),
                                const SizedBox(height: 6),
                                const Text('Tap Buy to start',
                                    style: TextStyle(color: Color(0xFFCBD5E1))),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                            itemCount: transactions.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final tx = transactions[index];
                              final isPayment =
                                  tx.items.isEmpty && tx.amountPaid > 0;

                              if (isPayment) {
                                return _buildPaymentTile(tx);
                              }

                              return _buildTransactionTile(tx);
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentTile(TransactionModel tx) {
    final safePaid = tx.amountPaid < 0 ? 0.0 : tx.amountPaid;
    return Container(
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child:
              const Icon(Icons.payments_rounded, color: Colors.green, size: 20),
        ),
        title: const Text('Due Payment Received',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        subtitle: Text(_formatDate(tx.date),
            style: TextStyle(color: Colors.green.shade700, fontSize: 12)),
        trailing: Text(
          '+ ₹${safePaid.toStringAsFixed(2)}',
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
        ),
      ),
    );
  }

  Widget _buildTransactionTile(TransactionModel tx) {
    final paid = tx.amountPaid.clamp(0.0, tx.totalAmount).toDouble();
    final due = tx.totalAmount - paid;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.receipt_rounded,
              color: Color(0xFF6C63FF), size: 20),
        ),
        title: Text(
          '₹${tx.totalAmount.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_formatDate(tx.date),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            if (due > 0)
              Text('Balance Amount: ₹${due.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tx.pendingSync)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Pending',
                    style: TextStyle(
                        color: Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            Text('${tx.items.length} item(s)',
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            const Icon(Icons.expand_more_rounded, color: Color(0xFF94A3B8)),
          ],
        ),
        children: tx.items
            .map((item) => Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(item.productName,
                              style: const TextStyle(fontSize: 14))),
                      Text('x${item.quantity}',
                          style: const TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 13)),
                      const SizedBox(width: 16),
                      Text('₹${item.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  double _calculateCurrentDue(List<TransactionModel> transactions) {
    var due = 0.0;
    for (final tx in transactions) {
      final safePaid = tx.amountPaid < 0 ? 0.0 : tx.amountPaid;
      if (tx.items.isEmpty) {
        due -= safePaid;
      } else {
        final paidAtSale = safePaid.clamp(0.0, tx.totalAmount).toDouble();
        due += (tx.totalAmount - paidAtSale);
      }
    }
    return due.clamp(0.0, double.infinity).toDouble();
  }

  Future<void> _showPaymentDialog(
      BuildContext context, CustomerEntity customerEntity, double currentDue) async {
    final controller =
        TextEditingController(text: currentDue.toStringAsFixed(2));
    String method = 'cash';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Receive Payment'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      'Current Due: ₹${currentDue.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount Received',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: method,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'upi', child: Text('UPI')),
                      DropdownMenuItem(value: 'card', child: Text('Card')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => method = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(controller.text) ?? 0.0;
                    if (amount <= 0) return;
                    if (amount > currentDue) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Amount cannot exceed current due.')));
                      }
                      return;
                    }

                    final billingRepo = sl<BillingRepository>();
                    final customerRepo = sl<CustomerRepository>();

                    // Create dummy payment transaction
                    final paymentTx = TransactionModel(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      date: DateTime.now(),
                      totalAmount: 0.0,
                      amountPaid: amount,
                      paymentMethod: method,
                      items: [],
                      customerId: customerEntity.id,
                      customerName: customerEntity.name,
                    );

                    await billingRepo.saveTransaction(paymentTx);

                    // Reduce balance
                    final newBalance =
                      (currentDue - amount).clamp(0.0, double.infinity).toDouble();
                    await customerRepo.updateCustomer(
                        customerEntity.copyWith(balance: newBalance));

                    if (context.mounted) {
                      context.read<CustomerBloc>().add(LoadCustomersEvent());
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Payment of ₹$amount recorded!')));
                    }
                  },
                  child: const Text('Save Payment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final h = date.hour > 12
        ? date.hour - 12
        : date.hour == 0
            ? 12
            : date.hour;
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final m = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year}  •  $h:$m $ampm';
  }
}
