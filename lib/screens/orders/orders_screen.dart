import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_animations.dart';
import '../../config/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/order.dart';
import '../../providers/providers.dart';
import 'order_form_screen.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  String _searchQuery = '';
  String _statusFilter = 'All';
  String? _updatingOrderId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.tr('orders') ?? 'Orders'),
        actions: [
          // Status filter chips
          ..._buildFilterChips(l10n),
          const SizedBox(width: 8),
          // Search
          SizedBox(
            width: 250,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: TextField(
                onChanged: (v) =>
                    setState(() => _searchQuery = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: l10n?.tr('search') ?? 'Search...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceLight,
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const OrderFormScreen()),
          );
        },
        tooltip: l10n?.tr('newOrder') ?? 'New Order',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: ordersAsync.when(
        data: (orders) {
          var filtered = orders.where((o) {
            if (_statusFilter != 'All' && o.status.dbValue != _statusFilter)
              return false;
            if (_searchQuery.isNotEmpty) {
              return (o.cardName ?? '').toLowerCase().contains(_searchQuery) ||
                  (o.customerName ?? '').toLowerCase().contains(_searchQuery) ||
                  (o.orderNumber?.toString() ?? '').contains(_searchQuery);
            }
            return true;
          }).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: AppTheme.textSecondary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n?.tr('noData') ?? 'No Data',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            );
          }

          return AnimatedFadeIn(
            duration: AppAnimations.durationMedium,
            scaleBegin: 0.98,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              scrollDirection: Axis.vertical,
              child: SizedBox(
                width: double.infinity,
                child: DataTable(
                headingRowHeight: 56,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 60,
                columnSpacing: 24,
                columns: [
                  DataColumn(label: Text(l10n?.tr('cardName') ?? 'Card Name')),
                  DataColumn(
                    label: Text(l10n?.tr('customerName') ?? 'Customer'),
                  ),
                  DataColumn(label: Text(l10n?.tr('orderNumber') ?? 'Order #')),
                  DataColumn(
                    label: Text(l10n?.tr('creationDate') ?? 'Created'),
                  ),
                  DataColumn(
                    label: Text(l10n?.tr('assemblyRequired') ?? 'Assembly'),
                  ),
                  DataColumn(
                    label: Text(l10n?.tr('assemblyDate') ?? 'Asm. Date'),
                  ),
                  DataColumn(label: Text(l10n?.tr('status') ?? 'Status')),
                  DataColumn(label: Text(l10n?.tr('totalPrice') ?? 'Total')),
                  DataColumn(label: Text(l10n?.tr('username') ?? 'User')),
                ],
                rows: filtered.map((order) {
                  final statusColor = _statusColor(order.status);
                  final isUpdating = _updatingOrderId == order.id;

                  return DataRow(
                    onSelectChanged: (_) {
                      if (_updatingOrderId != null) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => OrderFormScreen(orderId: order.id),
                        ),
                      );
                    },
                    cells: [
                      DataCell(
                        Text(
                          order.cardName ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(Text(order.customerName ?? '-')),
                      DataCell(
                        Text(
                          '#${order.orderNumber ?? '-'}',
                          style: const TextStyle(
                            color: AppTheme.primaryGold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          order.createdAt?.toString().split(' ').first ?? '-',
                        ),
                      ),
                      DataCell(
                        Icon(
                          order.assemblyRequired
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: order.assemblyRequired
                              ? AppTheme.success
                              : AppTheme.textSecondary,
                          size: 20,
                        ),
                      ),
                      DataCell(
                        Text(
                          order.assemblyDate?.toString().split(' ').first ??
                              '-',
                        ),
                      ),
                      DataCell(
                        PopupMenuButton<String>(
                          enabled: !isUpdating,
                          tooltip: l10n?.tr('changeStatus') ?? 'Change status',
                          padding: EdgeInsets.zero,
                          onSelected: (value) =>
                              _updateOrderStatus(order.id, value),
                          itemBuilder: (context) => OrderStatusExtension.all
                              .map(
                                (s) => PopupMenuItem<String>(
                                  value: s.dbValue,
                                  child: Row(
                                    children: [
                                      if (order.status == s)
                                        const Icon(Icons.check_rounded,
                                            size: 20, color: AppTheme.primaryGold),
                                      if (order.status == s)
                                        const SizedBox(width: 8),
                                      Text(_statusLabel(s, l10n)),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: isUpdating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        order.status.dbValue,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_drop_down_rounded,
                                        size: 18,
                                        color: statusColor,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          '₪${order.totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataCell(
                        Text(
                          order.createdBy ?? '-',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            '${l10n?.tr('error') ?? 'Error'}: $e',
            style: const TextStyle(color: AppTheme.error),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFilterChips(AppLocalizations? l10n) {
    final filters = [
      'All',
      ...OrderStatusExtension.all.map((s) => s.dbValue),
    ];
    return filters.map((f) {
      final isSelected = _statusFilter == f;
      final label = f == 'All'
          ? (l10n?.tr('all') ?? 'All')
          : _statusLabel(OrderStatusExtension.fromString(f), l10n);
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: FilterChip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          selected: isSelected,
          onSelected: (selected) {
            setState(() => _statusFilter = f);
          },
          selectedColor: AppTheme.primaryGold.withValues(alpha: 0.2),
          checkmarkColor: AppTheme.primaryGold,
          backgroundColor: AppTheme.surfaceLight,
          side: BorderSide(
            color: isSelected ? AppTheme.primaryGold : Colors.white10,
          ),
        ),
      );
    }).toList();
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

  String _statusLabel(OrderStatus status, AppLocalizations? l10n) {
    switch (status) {
      case OrderStatus.active:
        return l10n?.tr('active') ?? 'Active';
      case OrderStatus.preparing:
        return l10n?.tr('preparing') ?? 'Preparing';
      case OrderStatus.inAssembly:
        return l10n?.tr('inAssembly') ?? 'In Assembly';
      case OrderStatus.awaitingShipping:
        return l10n?.tr('awaitingShipping') ?? 'Awaiting Shipping';
      case OrderStatus.handled:
        return l10n?.tr('handled') ?? 'Handled';
      case OrderStatus.delivered:
        return l10n?.tr('delivered') ?? 'Delivered';
      case OrderStatus.canceled:
        return l10n?.tr('canceled') ?? 'Canceled';
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    setState(() => _updatingOrderId = orderId);
    try {
      final username = ref.read(currentUsernameProvider);
      await ref
          .read(orderServiceProvider)
          .updateStatus(orderId, newStatus, username);
      ref.invalidate(ordersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context)?.tr('statusUpdated') ?? 'Status updated'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${AppLocalizations.of(context)?.tr('error') ?? 'Error'}: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingOrderId = null);
    }
  }
}
