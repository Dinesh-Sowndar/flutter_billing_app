import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../bloc/billing_bloc.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({
    super.key,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  bool _isFinishing = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (
        bool didPop,
        dynamic result,
      ) {
        if (didPop) {
          return;
        }

        context.read<BillingBloc>().add(
              ClearCartEvent(),
            );

        context.go('/');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'الفاتورة',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            tooltip: 'العودة',
            icon: const Icon(
              Icons.arrow_forward_ios,
              size: 20,
            ),
            onPressed: () {
              context.read<BillingBloc>().add(
                    ClearCartEvent(),
                  );

              context.go('/');
            },
          ),
        ),

        body: BlocConsumer<BillingBloc, BillingState>(
          listener: (context, state) {
            if (state.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.error!,
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },

          builder: (context, billingState) {
            if (billingState.cartItems.isEmpty) {
              return _buildEmptyInvoice(context);
            }

            return SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        16,
                      ),
                      child: Column(
                        children: [
                          _buildInvoiceHeader(
                            context,
                            billingState,
                          ),

                          const SizedBox(
                            height: 16,
                          ),

                          _buildProductsCard(
                            context,
                            billingState,
                          ),

                          const SizedBox(
                            height: 16,
                          ),

                          _buildSummaryCard(
                            context,
                            billingState,
                          ),

                          const SizedBox(
                            height: 20,
                          ),
                        ],
                      ),
                    ),
                  ),

                  _buildFinishSection(
                    context,
                    billingState,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInvoiceHeader(
    BuildContext context,
    BillingState state,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(
              alpha: 0.82,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.18,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long,
              color: Colors.white,
              size: 28,
            ),
          ),

          const SizedBox(
            width: 14,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'فاتورة البيع',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  '${state.totalQuantity} قطعة • ${state.cartItems.length} منتجات',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsCard(
    BuildContext context,
    BillingState state,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.04,
            ),
            blurRadius: 12,
            offset: const Offset(
              0,
              4,
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              12,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(
                  width: 8,
                ),
                const Text(
                  'المنتجات',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const Divider(
            height: 1,
          ),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.cartItems.length,
            separatorBuilder: (_, __) {
              return Divider(
                height: 1,
                color: Colors.grey.shade100,
              );
            },
            itemBuilder: (context, index) {
              final item = state.cartItems[index];

              return _buildInvoiceItem(
                context,
                item,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceItem(
    BuildContext context,
    CartItem item,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(
                alpha: 0.10,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: AppTheme.primaryColor,
              size: 22,
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  '${item.quantity} × ${_formatMoney(item.product.price)} DZD',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            width: 8,
          ),

          Flexible(
            child: Text(
              '${_formatMoney(item.total)} DZD',
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    BillingState state,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          _summaryRow(
            title: 'عدد المنتجات',
            value: '${state.cartItems.length}',
          ),

          const SizedBox(
            height: 10,
          ),

          _summaryRow(
            title: 'عدد القطع',
            value: '${state.totalQuantity}',
          ),

          const Padding(
            padding: EdgeInsets.symmetric(
              vertical: 14,
            ),
            child: Divider(
              height: 1,
            ),
          ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text(
                  'المجموع الكلي',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              Flexible(
                child: Text(
                  '${_formatMoney(state.totalAmount)} DZD',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow({
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFinishSection(
    BuildContext context,
    BillingState state,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.08,
            ),
            blurRadius: 15,
            offset: const Offset(
              0,
              -4,
            ),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'المجموع',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(
                    height: 2,
                  ),
                  Text(
                    '${_formatMoney(state.totalAmount)} DZD',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              width: 8,
            ),

            Expanded(
              flex: 2,
              child: PrimaryButton(
                onPressed: _isFinishing
                    ? null
                    : () => _finishInvoice(context),
                label: 'إنهاء وحفظ الفاتورة',
                icon: Icons.check_circle_outline,
                isLoading: _isFinishing,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyInvoice(
    BuildContext context,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(
                  alpha: 0.10,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 45,
                color: AppTheme.primaryColor,
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            const Text(
              'لا توجد منتجات في الفاتورة',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            const Text(
              'أضف منتجات إلى السلة أولاً ثم افتح شاشة الفاتورة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),

            const SizedBox(
              height: 24,
            ),

            ElevatedButton.icon(
              onPressed: () {
                context.go('/');
              },
              icon: const Icon(
                Icons.arrow_forward,
              ),
              label: const Text(
                'العودة للكاشير',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finishInvoice(
    BuildContext context,
  ) async {
    if (_isFinishing) {
      return;
    }

    setState(() {
      _isFinishing = true;
    });

    // نعطي Flutter لحظة قصيرة لإظهار حالة التنفيذ
    // بشكل سلس على الهواتف الضعيفة.
    await Future<void>.delayed(
      const Duration(
        milliseconds: 250,
      ),
    );

    if (!mounted) {
      return;
    }

    final billingBloc = context.read<BillingBloc>();

    billingBloc.add(
      ClearCartEvent(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.white,
            ),
            SizedBox(
              width: 10,
            ),
            Expanded(
              child: Text(
                'تم إنهاء وحفظ الفاتورة بنجاح',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(
          seconds: 2,
        ),
      ),
    );

    await Future<void>.delayed(
      const Duration(
        milliseconds: 350,
      ),
    );

    if (!mounted) {
      return;
    }

    context.go('/');
  }

  String _formatMoney(
    double value,
  ) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2);
  }
}
