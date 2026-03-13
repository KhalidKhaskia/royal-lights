import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const OrderFormScreen()));
        },
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: Text(l10n?.tr('newOrder') ?? 'New Order'),
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

          return SingleChildScrollView(
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

                  return DataRow(
                    onSelectChanged: (_) {
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
                          style: TextStyle(
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
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
    final filters = ['All', 'Active', 'In Assembly', 'Handled', 'Canceled'];
    final labels = {
      'All': l10n?.tr('all') ?? 'All',
      'Active': l10n?.tr('active') ?? 'Active',
      'In Assembly': l10n?.tr('inAssembly') ?? 'In Assembly',
      'Handled': l10n?.tr('handled') ?? 'Handled',
      'Canceled': l10n?.tr('canceled') ?? 'Canceled',
    };

    return filters.map((f) {
      final isSelected = _statusFilter == f;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: FilterChip(
          label: Text(labels[f]!, style: TextStyle(fontSize: 12)),
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
}
