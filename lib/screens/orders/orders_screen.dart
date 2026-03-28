import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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
  String _createdByFilter = 'All';
  int _sortColumnIndex = 3;
  bool _sortAscending = false;
  String? _updatingOrderId;
  int _currentPage = 1;
  final int _rowsPerPage = 15;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceContainerLowest,
        scrolledUnderElevation: 0,
        elevation: 0,
        toolbarHeight: 0, // Hide standard appbar to use custom header
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.secondary,
        foregroundColor: AppTheme.onPrimary,
        elevation: 2,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const OrderFormScreen()),
          );
        },
        tooltip: l10n?.tr('newOrder') ?? 'New Order',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Editorial Header ────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.tr('orders') ?? 'ניהול הזמנות',
                  style: GoogleFonts.assistant(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'מעקב וניהול אחר הזמנות הלקוחות' , 
                  style: GoogleFonts.assistant(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          
// removed standalone top bar

          // ─── Orders Table ─────────────────────────────
          Expanded(
            child: ordersAsync.when(
              data: (orders) {
                var filtered = orders.where((o) {
                  if (_statusFilter != 'All' && o.status.dbValue != _statusFilter) {
                    return false;
                  }
                  if (_createdByFilter != 'All' && (o.createdBy ?? '-') != _createdByFilter) {
                    return false;
                  }
                  if (_searchQuery.isNotEmpty) {
                    return (o.cardName ?? '').toLowerCase().contains(_searchQuery) ||
                        (o.customerName ?? '').toLowerCase().contains(_searchQuery) ||
                        (o.orderNumber?.toString() ?? '').contains(_searchQuery);
                  }
                  return true;
                }).toList();

                filtered.sort((a, b) {
                  int comp = 0;
                  switch (_sortColumnIndex) {
                    case 0:
                      comp = (a.orderNumber ?? 0).compareTo(b.orderNumber ?? 0);
                      break;
                    case 1:
                      comp = (a.cardName ?? '').toLowerCase().compareTo((b.cardName ?? '').toLowerCase());
                      break;
                    case 2:
                      comp = (a.customerName ?? '').toLowerCase().compareTo((b.customerName ?? '').toLowerCase());
                      break;
                    case 3:
                      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                      comp = aDate.compareTo(bDate);
                      break;
                    case 4:
                      comp = (a.createdBy ?? '').toLowerCase().compareTo((b.createdBy ?? '').toLowerCase());
                      break;
                    case 5:
                      comp = (a.assemblyRequired ? 1 : 0).compareTo(b.assemblyRequired ? 1 : 0);
                      break;
                    case 6:
                      comp = a.status.dbValue.compareTo(b.status.dbValue);
                      break;
                    case 7:
                      comp = a.totalPrice.compareTo(b.totalPrice);
                      break;
                  }
                  return _sortAscending ? comp : -comp;
                });

                final uniqueCreators = ['All', ...orders.map((o) => o.createdBy ?? '-').where((e) => e != '-').toSet()];
                final totalItems = filtered.length;
                final totalPages = (totalItems / _rowsPerPage).ceil();
                int validCurrentPage = _currentPage;
                if (validCurrentPage > totalPages && totalPages > 0) {
                  validCurrentPage = totalPages;
                }
                final startIndex = (validCurrentPage - 1) * _rowsPerPage;
                final endIndex = (startIndex + _rowsPerPage).clamp(0, totalItems);
                final paginatedFiltered = filtered.isEmpty ? <Order>[] : filtered.sublist(startIndex, endIndex);

                return AnimatedFadeIn(
                  duration: AppAnimations.durationMedium,
                  scaleBegin: 0.98,
                  child: Column(
                    children: [
                      // ─── Search & Filter Control Bar ──────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l10n?.tr('search') ?? 'חיפוש', style: GoogleFonts.assistant(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.onSurfaceVariant)),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: TextField(
                                      onChanged: (v) => setState(() {
                                        _searchQuery = v.toLowerCase();
                                        _currentPage = 1;
                                      }),
                                      style: GoogleFonts.assistant(fontSize: 14, color: AppTheme.onSurface),
                                      decoration: InputDecoration(
                                        hintText: l10n?.tr('search') ?? 'חיפוש חופשי (הזמנה, כרטיס, לקוח)...',
                                        hintStyle: GoogleFonts.assistant(
                                          color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                                        ),
                                        prefixIcon: Icon(Icons.search_rounded, 
                                            size: 20, color: AppTheme.onSurfaceVariant),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n?.tr('createdBy') ?? 'נוצר ע״י', style: GoogleFonts.assistant(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.onSurfaceVariant)),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 140,
                                  height: 44,
                                  child: _buildCreatedByDropdown(uniqueCreators, l10n),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n?.tr('status') ?? 'סטטוס', style: GoogleFonts.assistant(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.onSurfaceVariant)),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 140,
                                  height: 44,
                                  child: _buildStatusDropdown(l10n),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const Divider(height: 1),
                      
                      Expanded(
                        child: filtered.isEmpty 
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.shopping_cart_outlined, size: 64, color: AppTheme.outline.withValues(alpha: 0.3)),
                                    const SizedBox(height: 16),
                                    Text(l10n?.tr('noData') ?? 'לא נמצאו נתונים', style: GoogleFonts.assistant(color: AppTheme.onSurfaceVariant, fontSize: 16)),
                                  ],
                                ),
                              )
                            : SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceContainerLowest,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppTheme.outlineVariant.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        physics: const BouncingScrollPhysics(),
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                          child: DataTable(
                          showCheckboxColumn: false,
                          headingRowHeight: 52,
                          dataRowMinHeight: 60,
                          dataRowMaxHeight: 64,
                          columnSpacing: 32,
                          headingTextStyle: GoogleFonts.assistant(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                          dataTextStyle: GoogleFonts.assistant(
                            color: AppTheme.onSurface,
                            fontSize: 14,
                          ),
                          sortColumnIndex: _sortColumnIndex,
                          sortAscending: _sortAscending,
                          columns: [
                            DataColumn(
                              label: Text(l10n?.tr('orderNumber') ?? 'מספר הזמנה'),
                              onSort: (col, asc) => setState(() { _sortColumnIndex = col; _sortAscending = asc; }),
                            ),
                            DataColumn(
                              label: Text(l10n?.tr('cardName') ?? 'שם כרטיס'),
                              onSort: (col, asc) => setState(() { _sortColumnIndex = col; _sortAscending = asc; }),
                            ),
                            DataColumn(
                              label: Text(l10n?.tr('customerName') ?? 'לקוח'),
                              onSort: (col, asc) => setState(() { _sortColumnIndex = col; _sortAscending = asc; }),
                            ),
                            DataColumn(
                              label: Text(l10n?.tr('creationDate') ?? 'תאריך יצירה'),
                              onSort: (col, asc) => setState(() { _sortColumnIndex = col; _sortAscending = asc; }),
                            ),
                            DataColumn(
                              label: Text(l10n?.tr('createdBy') ?? 'נוצר ע״י'),
                              onSort: (col, asc) => setState(() { _sortColumnIndex = col; _sortAscending = asc; }),
                            ),
                            DataColumn(
                              label: Text(l10n?.tr('assemblyRequired') ?? 'הרכבה'),
                              onSort: (col, asc) => setState(() { _sortColumnIndex = col; _sortAscending = asc; }),
                            ),
                            DataColumn(
                              label: Text(l10n?.tr('status') ?? 'סטטוס'),
                              onSort: (col, asc) => setState(() { _sortColumnIndex = col; _sortAscending = asc; }),
                            ),
                            DataColumn(
                              label: Text(l10n?.tr('totalPrice') ?? 'סה"כ'),
                              onSort: (col, asc) => setState(() { _sortColumnIndex = col; _sortAscending = asc; }),
                            ),
                          ],
                          rows: paginatedFiltered.map((order) {
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
                                  '#${order.orderNumber ?? '-'}',
                                  style: GoogleFonts.assistant(
                                    color: AppTheme.onSurface,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  order.cardName ?? '-',
                                  style: GoogleFonts.assistant(fontWeight: FontWeight.w600),
                                ),
                              ),
                              DataCell(Text(order.customerName ?? '-')),
                              DataCell(
                                Text(
                                  order.createdAt?.toString().split(' ').first ?? '-',
                                  style: GoogleFonts.assistant(color: AppTheme.onSurfaceVariant),
                                ),
                              ),
                              DataCell(
                                Text(
                                  order.createdBy ?? '-',
                                  style: GoogleFonts.assistant(
                                      fontWeight: FontWeight.w600, color: AppTheme.onSurfaceVariant),
                                ),
                              ),
                              DataCell(
                                Icon(
                                  order.assemblyRequired
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded,
                                  color: order.assemblyRequired
                                      ? AppTheme.success
                                      : AppTheme.outline.withValues(alpha: 0.5),
                                  size: 18,
                                ),
                              ),
                              DataCell(
                                PopupMenuButton<String>(
                                  enabled: !isUpdating,
                                  tooltip: l10n?.tr('changeStatus') ?? 'שנה סטטוס',
                                  padding: EdgeInsets.zero,
                                  onSelected: (value) => _updateOrderStatus(order.id, value),
                                  itemBuilder: (context) => OrderStatusExtension.all
                                      .map(
                                        (s) => PopupMenuItem<String>(
                                          value: s.dbValue,
                                          child: Row(
                                            children: [
                                              if (order.status == s)
                                                const Icon(Icons.check_rounded,
                                                    size: 18, color: AppTheme.secondary),
                                              if (order.status == s)
                                                const SizedBox(width: 8),
                                              Text(
                                                _statusLabel(s, l10n),
                                                style: GoogleFonts.assistant(),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20), // Pill shape
                                    ),
                                    child: isUpdating
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _statusLabel(order.status, l10n),
                                                style: GoogleFonts.assistant(
                                                  color: statusColor,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.arrow_drop_down_rounded,
                                                size: 16,
                                                color: statusColor,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '₪${order.totalPrice.toStringAsFixed(0)}',
                                  style: GoogleFonts.assistant(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                const Divider(height: 1),
                _buildPaginationControls(validCurrentPage, totalPages, totalItems),
              ],
            ),
            );
          },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  '${l10n?.tr('error') ?? 'Error'}: $e',
                  style: GoogleFonts.assistant(color: AppTheme.error),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls(int currentPage, int totalPages, int totalItems) {
    if (totalPages <= 1) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: AppTheme.surfaceContainerLowest,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'סה״כ $totalItems רשומות',
            style: GoogleFonts.assistant(
              color: AppTheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: currentPage > 1 ? () => setState(() => _currentPage = currentPage - 1) : null,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$currentPage / $totalPages',
                  style: GoogleFonts.assistant(
                    color: AppTheme.primaryGold,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: currentPage < totalPages ? () => setState(() => _currentPage = currentPage + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreatedByDropdown(List<String> creators, AppLocalizations? l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _createdByFilter,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          style: GoogleFonts.assistant(fontSize: 13, color: AppTheme.onSurface),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() => _createdByFilter = newValue);
            }
          },
          items: creators.map<DropdownMenuItem<String>>((String f) {
            final label = f == 'All' ? (l10n?.tr('all') ?? 'הכל') : f;
            return DropdownMenuItem<String>(
              value: f,
              child: Text(label, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusDropdown(AppLocalizations? l10n) {
    final filters = [
      'All',
      ...OrderStatusExtension.all.map((s) => s.dbValue),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _statusFilter,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          style: GoogleFonts.assistant(fontSize: 13, color: AppTheme.onSurface),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() => _statusFilter = newValue);
            }
          },
          items: filters.map<DropdownMenuItem<String>>((String f) {
            final label = f == 'All'
                ? (l10n?.tr('all') ?? 'הכל')
                : _statusLabel(OrderStatusExtension.fromString(f), l10n);
            return DropdownMenuItem<String>(
              value: f,
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        ),
      ),
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
        return AppTheme.secondaryContainer;
      case OrderStatus.handled:
        return AppTheme.secondary;
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
      await ref.read(orderServiceProvider).updateStatus(orderId, newStatus, username);
      ref.invalidate(ordersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.tr('statusUpdated') ?? 'סטטוס התעדכן',
              style: GoogleFonts.assistant(),
            ),
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
              '${AppLocalizations.of(context)?.tr('error') ?? 'שגיאה'}: $e',
              style: GoogleFonts.assistant(),
            ),
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
