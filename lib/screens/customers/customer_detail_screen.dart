import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/customer.dart';
import '../../models/order.dart';
import '../../models/payment.dart';
import '../../providers/providers.dart';
import '../orders/order_form_screen.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final Customer customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  ConsumerState<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  late Customer _customer;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
  }

  void _onCustomerUpdated(Customer c) {
    setState(() => _customer = c);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_customer.cardName),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(customersProvider);
          ref.invalidate(customerOrdersProvider(_customer.id));
          ref.invalidate(customerPaymentsProvider(_customer.id));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderCard(
                customer: _customer,
                l10n: l10n,
                onCustomerUpdated: _onCustomerUpdated,
              ),
              const SizedBox(height: 24),
              _Section(
                title: l10n?.tr('customerName') ?? 'Details',
                icon: Icons.person_outline_rounded,
                child: _DetailsSection(customer: _customer, l10n: l10n),
              ),
              const SizedBox(height: 24),
              _Section(
                title: l10n?.tr('customerOrders') ?? 'Orders',
                icon: Icons.shopping_bag_outlined,
                child: _OrdersSection(customerId: _customer.id, l10n: l10n),
              ),
              const SizedBox(height: 24),
              _Section(
                title: l10n?.tr('customerPayments') ?? 'Payments',
                icon: Icons.payment_rounded,
                child: _PaymentsSection(customerId: _customer.id, l10n: l10n),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable section: title + icon + content card.
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppTheme.primaryGold),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _HeaderCard extends ConsumerStatefulWidget {
  final Customer customer;
  final AppLocalizations? l10n;
  final void Function(Customer) onCustomerUpdated;

  const _HeaderCard({
    required this.customer,
    required this.l10n,
    required this.onCustomerUpdated,
  });

  @override
  ConsumerState<_HeaderCard> createState() => _HeaderCardState();
}

class _HeaderCardState extends ConsumerState<_HeaderCard> {
  bool _uploadingPhoto = false;

  Future<void> _changePhoto() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (xFile == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await xFile.readAsBytes();
      final service = ref.read(customerServiceProvider);
      final username = ref.read(currentUsernameProvider);
      final url = await service.uploadPhoto(widget.customer.id, bytes);
      await service.update(
        widget.customer.id,
        {'image_url': url, 'updated_by': username},
      );
      widget.onCustomerUpdated(widget.customer.copyWith(imageUrl: url));
      ref.invalidate(customersProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.l10n?.tr('error') ?? 'Error'}: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;
    final l10n = widget.l10n;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: customer.imageUrl != null &&
                        customer.imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: customer.imageUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _placeholder(200),
                        errorWidget: (_, __, ___) => _placeholder(200),
                      )
                    : _placeholder(200),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Material(
                  color: AppTheme.primaryGold,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _uploadingPhoto ? null : _changePhoto,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _uploadingPhoto
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.black,
                              size: 24,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.cardName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
                if (customer.customerName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    customer.customerName,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: (customer.remainingDebt > 0
                            ? AppTheme.error
                            : AppTheme.success)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (customer.remainingDebt > 0
                              ? AppTheme.error
                              : AppTheme.success)
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 24,
                        color: customer.remainingDebt > 0
                            ? AppTheme.error
                            : AppTheme.success,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n?.tr('remainingDebt') ?? 'Remaining Debt',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '₪${customer.remainingDebt.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: customer.remainingDebt > 0
                              ? AppTheme.error
                              : AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(double height) {
    return Container(
      height: height,
      width: double.infinity,
      color: AppTheme.surfaceDark,
      child: Center(
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryGold,
                AppTheme.primaryGold.withValues(alpha: 0.7),
              ],
            ),
          ),
          child: Center(
            child: Text(
              widget.customer.cardName.isNotEmpty
                  ? widget.customer.cardName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  final Customer customer;
  final AppLocalizations? l10n;

  const _DetailsSection({required this.customer, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          _InfoRow(
            Icons.badge_outlined,
            l10n?.tr('cardName') ?? 'Card Name',
            customer.cardName,
          ),
          const SizedBox(height: 14),
          _InfoRow(
            Icons.person_outline_rounded,
            l10n?.tr('customerName') ?? 'Name',
            customer.customerName,
          ),
          const SizedBox(height: 14),
          _InfoRow(
            Icons.phone_outlined,
            l10n?.tr('phones') ?? 'Phones',
            customer.phones.isNotEmpty ? customer.phones.join(', ') : '-',
          ),
          const SizedBox(height: 14),
          _InfoRow(
            Icons.location_on_outlined,
            l10n?.tr('location') ?? 'Location',
            customer.location ?? '-',
          ),
          const SizedBox(height: 14),
          _InfoRow(
            Icons.note_outlined,
            l10n?.tr('notes') ?? 'Notes',
            customer.notes ?? '-',
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
  // Kept for hot reload compatibility and optional colored values (e.g. debt).
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
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
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

class _OrdersSection extends ConsumerWidget {
  final String customerId;
  final AppLocalizations? l10n;

  const _OrdersSection({required this.customerId, required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(customerOrdersProvider(customerId));

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  l10n?.tr('noData') ?? 'No Data',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            );
          }
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final order = orders[index];
              return _OrderTile(order: order, l10n: l10n);
            },
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '${l10n?.tr('error') ?? 'Error'}: $e',
            style: const TextStyle(color: AppTheme.error),
          ),
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final Order order;
  final AppLocalizations? l10n;

  const _OrderTile({required this.order, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      title: Text(
        '#${order.orderNumber ?? '-'}',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        '₪${order.totalPrice.toStringAsFixed(2)} • ${order.status.dbValue}',
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderFormScreen(orderId: order.id),
          ),
        );
      }
    );
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.active:
        return AppTheme.success;
      case OrderStatus.preparing:
        return const Color(0xFF2196F3);
      case OrderStatus.inAssembly:
        return AppTheme.warning;
      case OrderStatus.awaitingShipping:
        return const Color(0xFF9C27B0);
      case OrderStatus.handled:
        return AppTheme.primaryGold;
      case OrderStatus.delivered:
        return AppTheme.success;
      case OrderStatus.canceled:
        return AppTheme.error;
    }
  }
}

class _PaymentsSection extends ConsumerWidget {
  final String customerId;
  final AppLocalizations? l10n;

  const _PaymentsSection({required this.customerId, required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(customerPaymentsProvider(customerId));

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: paymentsAsync.when(
        data: (payments) {
          if (payments.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  l10n?.tr('noData') ?? 'No Data',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            );
          }
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            itemCount: payments.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final payment = payments[index];
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    payment.type == PaymentType.cash
                        ? Icons.money_rounded
                        : payment.type == PaymentType.credit
                            ? Icons.credit_card_rounded
                            : Icons.description_rounded,
                    color: AppTheme.primaryGold,
                    size: 22,
                  ),
                ),
                title: Text(
                  '₪${payment.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                subtitle: Text(
                  '${payment.type.dbValue} • ${payment.date.toString().split(' ').first}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '${l10n?.tr('error') ?? 'Error'}: $e',
            style: const TextStyle(color: AppTheme.error),
          ),
        ),
      ),
    );
  }
}
