import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/customer.dart';
import '../../models/order.dart';
import '../../models/payment.dart';
import '../../providers/providers.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final Customer customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  ConsumerState<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = widget.customer;

    return Scaffold(
      appBar: AppBar(
        title: Text(c.cardName),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryGold,
          labelColor: AppTheme.primaryGold,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: [
            Tab(text: l10n?.tr('customerName') ?? 'Info'),
            Tab(text: l10n?.tr('customerOrders') ?? 'Orders'),
            Tab(text: l10n?.tr('customerPayments') ?? 'Payments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _InfoTab(customer: c, l10n: l10n),
          _OrdersTab(customerId: c.id, l10n: l10n),
          _PaymentsTab(customerId: c.id, l10n: l10n),
        ],
      ),
    );
  }
}

class _InfoTab extends StatelessWidget {
  final Customer customer;
  final AppLocalizations? l10n;
  const _InfoTab({required this.customer, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Customer info card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  Icons.badge_outlined,
                  l10n?.tr('cardName') ?? 'Card Name',
                  customer.cardName,
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  Icons.person_outline,
                  l10n?.tr('customerName') ?? 'Name',
                  customer.customerName,
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  Icons.phone_outlined,
                  l10n?.tr('phones') ?? 'Phones',
                  customer.phones.isNotEmpty ? customer.phones.join(', ') : '-',
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  Icons.location_on_outlined,
                  l10n?.tr('location') ?? 'Location',
                  customer.location ?? '-',
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  Icons.note_outlined,
                  l10n?.tr('notes') ?? 'Notes',
                  customer.notes ?? '-',
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  Icons.account_balance_wallet_outlined,
                  l10n?.tr('remainingDebt') ?? 'Remaining Debt',
                  '₪${customer.remainingDebt.toStringAsFixed(2)}',
                  valueColor: customer.remainingDebt > 0
                      ? AppTheme.error
                      : AppTheme.success,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow(this.icon, this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryGold),
        const SizedBox(width: 12),
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _OrdersTab extends ConsumerWidget {
  final String customerId;
  final AppLocalizations? l10n;
  const _OrdersTab({required this.customerId, required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(customerOrdersProvider(customerId));

    return ordersAsync.when(
      data: (orders) {
        if (orders.isEmpty) {
          return Center(
            child: Text(
              l10n?.tr('noData') ?? 'No Data',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return _OrderTile(order: order, l10n: l10n);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final Order order;
  final AppLocalizations? l10n;
  const _OrderTile({required this.order, required this.l10n});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (order.status) {
      case OrderStatus.active:
        statusColor = AppTheme.success;
        break;
      case OrderStatus.inAssembly:
        statusColor = AppTheme.warning;
        break;
      case OrderStatus.handled:
        statusColor = AppTheme.primaryGold;
        break;
      case OrderStatus.canceled:
        statusColor = AppTheme.error;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(
          '#${order.orderNumber ?? '-'}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '₪${order.totalPrice.toStringAsFixed(2)} • ${order.status.dbValue}',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            order.status.dbValue,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentsTab extends ConsumerWidget {
  final String customerId;
  final AppLocalizations? l10n;
  const _PaymentsTab({required this.customerId, required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(customerPaymentsProvider(customerId));

    return paymentsAsync.when(
      data: (payments) {
        if (payments.isEmpty) {
          return Center(
            child: Text(
              l10n?.tr('noData') ?? 'No Data',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: payments.length,
          itemBuilder: (context, index) {
            final payment = payments[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: Icon(
                  payment.type == PaymentType.cash
                      ? Icons.money
                      : payment.type == PaymentType.credit
                      ? Icons.credit_card
                      : Icons.description,
                  color: AppTheme.primaryGold,
                ),
                title: Text(
                  '₪${payment.amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${payment.type.dbValue} • ${payment.date.toString().split(' ').first}',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
