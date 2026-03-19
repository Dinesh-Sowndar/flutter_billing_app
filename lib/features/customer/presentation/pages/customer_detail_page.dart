import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../billing/data/models/transaction_model.dart';
import '../../../billing/domain/repositories/billing_repository.dart';
import '../../domain/entities/customer_entity.dart';
import '../../data/models/customer_model.dart';

class CustomerDetailPage extends StatelessWidget {
  final CustomerEntity customer;
  const CustomerDetailPage({super.key, required this.customer});

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );

    try {
      final launched = await launchUrl(
        launchUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open dialer.')),
        );
      }
    } on PlatformException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone integration not ready. Restart the app once.'),
          ),
        );
      }
    }
  }

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
                title: Text(
                  'Customer Details',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: false,
                iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
                actions: [
                  if (ledgerDue > 0)
                    TextButton.icon(
                      onPressed: () =>
                          _showPaymentDialog(context, currentCustomer, ledgerDue),
                      icon: const Icon(Icons.payments_rounded, color: Color(0xFF10B981)),
                      label: const Text('Pay Due',
                          style: TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w700)),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => context.push(
                  '/customers/${currentCustomer.id}/purchase',
                  extra: currentCustomer,
                ),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text(
                  'Add Bill',
                  style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              body: Column(
                children: [
                  // Modern Header Banner
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withValues(alpha: 0.9),
                          AppTheme.primaryColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            currentCustomer.name.isNotEmpty
                                ? currentCustomer.name[0].toUpperCase()
                                : '?',
                            style: GoogleFonts.spaceGrotesk(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 28),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentCustomer.name,
                                style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 22,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () =>
                                    _makePhoneCall(context, currentCustomer.phone),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.call_rounded, size: 16, color: Colors.white70),
                                      const SizedBox(width: 6),
                                      Text(
                                        currentCustomer.phone,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: const Icon(Icons.edit_rounded, color: Colors.white),
                            onPressed: () {
                              context.push('/customers/${currentCustomer.id}/edit', extra: currentCustomer);
                            },
                            tooltip: 'Edit Customer',
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stats Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(child: _buildStatCard('Total Spent', totalSpent, Icons.shopping_bag_rounded, Colors.purple)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('Due Balance', ledgerDue, Icons.account_balance_wallet_rounded, ledgerDue > 0 ? Colors.red : Colors.green)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Transaction History',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ),

                  // Purchase history list
                  Expanded(
                    child: transactions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      )
                                    ],
                                  ),
                                  child: const Icon(Icons.receipt_long_rounded, size: 48, color: Color(0xFFCBD5E1)),
                                ),
                                const SizedBox(height: 16),
                                Text('No history yet',
                                    style: GoogleFonts.spaceGrotesk(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF94A3B8))),
                                const SizedBox(height: 6),
                                const Text('Tap "Add Bill" to start',
                                    style: TextStyle(color: Color(0xFF94A3B8))),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            itemCount: transactions.length,
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

  Widget _buildStatCard(String title, double amount, IconData icon, MaterialColor color) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: color.shade600),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            currencyFormat.format(amount),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color.shade700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  double _calculateCurrentDue(List<TransactionModel> transactions) {
    double totalBilled = 0;
    double totalPaid = 0;

    for (var tx in transactions) {
      if (tx.items.isNotEmpty) {
        totalBilled += tx.totalAmount;
        totalPaid += tx.amountPaid;
      } else {
        totalPaid += tx.amountPaid;
      }
    }
    return totalBilled - totalPaid;
  }

  Widget _buildTransactionTile(TransactionModel tx) {
    final dueForTx = tx.totalAmount - tx.amountPaid;
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF64748B)),
        ),
        title: Text(
          DateFormat('MMM dd, yyyy • hh:mm a').format(tx.date),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${tx.items.length} items',
            style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              currencyFormat.format(tx.totalAmount),
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Color(0xFF0F172A)),
            ),
            if (dueForTx > 0)
              Text(
                'Due ${currencyFormat.format(dueForTx)}',
                style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              )
            else if (tx.amountPaid > 0)
              const Text(
                'Paid',
                style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTile(TransactionModel tx) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4), // Light green tint
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCFCE7)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFD1FAE5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.payments_rounded, color: Color(0xFF10B981)),
        ),
        title: const Text('Due Amount Kept',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF065F46))),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            DateFormat('MMM dd, yyyy • hh:mm a').format(tx.date),
            style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w500),
          ),
        ),
        trailing: Text(
          '+ ${currencyFormat.format(tx.amountPaid)}',
          style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color(0xFF10B981)),
        ),
      ),
    );
  }

  void _showPaymentDialog(
      BuildContext context, CustomerEntity customer, double due) {
    final amountController =
      TextEditingController(text: due.toStringAsFixed(2));
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.bold)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Current Due: ₹${due.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount to Pay',
                      prefixText: '₹ ',
                      helperText: 'Defaulted to full due amount',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter amount';
                      final val = double.tryParse(v);
                      if (val == null || val <= 0) return 'Invalid amount';
                      if (val > due) return 'Amount cannot exceed due';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              if (!isSaving)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setState(() => isSaving = true);
                        final amount = double.parse(amountController.text);
                        final paymentTx = TransactionModel(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          customerId: customer.id,
                          customerName: customer.name,
                          items: [],
                          totalAmount: 0.0,
                          amountPaid: amount,
                          paymentMethod: 'cash',
                          date: DateTime.now(),
                          pendingSync: true,
                        );

                        await sl<BillingRepository>()
                            .saveTransaction(paymentTx);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text('Payment recorded successfully')),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}