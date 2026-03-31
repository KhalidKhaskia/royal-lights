import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_animations.dart';
import '../../config/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/customer.dart';
import '../../models/order.dart';
import '../../providers/providers.dart';
import '../../theme/order_status_colors.dart';
import '../../widgets/app_dropdown_styles.dart';
import '../../widgets/editorial_screen_title.dart';
import 'order_form_screen.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _statusFilter = 'All';
  String _createdByFilter = 'All';
  int _sortColumnIndex = 3;
  bool _sortAscending = false;
  String? _updatingOrderId;
  int _currentPage = 1;
  final int _rowsPerPage = 15;

  static const String _cancelAndNotifyValue = '__cancel_and_notify__';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _searchQuery => _searchCtrl.text.trim().toLowerCase();

  void _resetFilters() {
    ref.read(ordersCustomerFilterProvider.notifier).setFilter(null);
    setState(() {
      _searchCtrl.clear();
      _statusFilter = 'All';
      _createdByFilter = 'All';
      _currentPage = 1;
    });
  }

  /// Localized orders search label; falls back if ARB key is missing (e.g. stale bundle).
  String _ordersSearchFieldLabel() {
    final l10n = AppLocalizations.of(context);
    final t = l10n?.tr('searchOrdersHint');
    if (t != null && t.isNotEmpty && t != 'searchOrdersHint') return t;
    return switch (Localizations.localeOf(context).languageCode) {
      'ar' => 'بحث برقم الطلب أو البطاقة أو اسم العميل…',
      'en' => 'Search by order #, card name, customer…',
      _ => 'חיפוש לפי מספר הזמנה, כרטיס, שם לקוח…',
    };
  }

  String _t(AppLocalizations? l10n, String key, String fallback) {
    final v = l10n?.tr(key);
    if (v != null && v.isNotEmpty && v != key) return v;
    return fallback;
  }

  String _cancelSupplierMessageTemplate({
    required String languageCode,
    required Order order,
    required String itemsText,
  }) {
    final orderNo = order.orderNumber?.toString() ?? '-';
    return switch (languageCode) {
      'en' =>
        'Order cancellation notice\nOrder #$orderNo\n\n$itemsText\n\nPlease confirm cancellation.',
      'ar' =>
        'إشعار إلغاء الطلب\nرقم الطلب #$orderNo\n\n$itemsText\n\nيرجى تأكيد الإلغاء.',
      _ =>
        'הודעת ביטול הזמנה\nהזמנה #$orderNo\n\n$itemsText\n\nנא לאשר ביטול.',
    };
  }

  Future<void> _notifySuppliersOrderCanceled(Order order) async {
    final lang = Localizations.localeOf(context).languageCode;

    // Group items by supplier phone (one WhatsApp message per supplier).
    final Map<String, List<dynamic>> byPhone = {};
    for (final item in order.items) {
      final phone = (item.supplierPhone ?? '').trim();
      if (phone.isEmpty) continue;
      (byPhone[phone] ??= []).add(item);
    }

    for (final entry in byPhone.entries) {
      final phone = entry.key.replaceAll(RegExp(r'[^\d+]'), '');
      if (phone.isEmpty) continue;

      final itemsText = entry.value.map((dynamic it) {
        final item = it as dynamic;
        final code = (item.itemNumber as String?)?.trim();
        final name = (item.name as String?)?.trim() ?? '';
        final qty = (item.quantity as int?) ?? 1;
        final codePart = (code != null && code.isNotEmpty) ? '($code)\n' : '';
        return '$codePart$name\nQty: $qty';
      }).join('\n\n');

      final message = _cancelSupplierMessageTemplate(
        languageCode: lang,
        order: order,
        itemsText: itemsText,
      );

      final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';
      try {
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        // WhatsApp not available / error launching URL.
      }
    }
  }

  Future<void> _cancelOrderAndNotifySuppliers(String orderId) async {
    final l10n = AppLocalizations.of(context);
    if (_updatingOrderId != null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            _t(l10n, 'cancelOrder', 'Cancel order'),
            style: GoogleFonts.assistant(fontWeight: FontWeight.w800),
          ),
          content: Text(
            _t(
              l10n,
              'confirmCancelOrder',
              'This will cancel the order and open a WhatsApp message to the supplier(s) with the canceled items.',
            ),
            style: GoogleFonts.assistant(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_t(l10n, 'cancel', 'Cancel')),
            ),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.cancel_rounded, size: 18),
              label: Text(_t(l10n, 'cancelAndNotifySupplier', 'Cancel & notify supplier')),
            ),
          ],
        );
      },
    );
    if (ok != true) return;

    setState(() => _updatingOrderId = orderId);
    try {
      final service = ref.read(orderServiceProvider);
      final fullOrder = await service.getById(orderId);

      // Open WhatsApp chats (user still taps "Send" in WhatsApp).
      await _notifySuppliersOrderCanceled(fullOrder);

      final username = ref.read(currentUsernameProvider);
      await service.cancelOrder(orderId, username);

      ref.invalidate(ordersProvider);
      ref.invalidate(customersProvider);
      ref.invalidate(totalUnpaidDebtsProvider);
      final fc = ref.read(ordersCustomerFilterProvider);
      if (fc != null) {
        ref.invalidate(customerOrdersProvider(fc.id));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(l10n, 'canceled', 'Canceled'),
            style: GoogleFonts.assistant(),
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_t(l10n, 'error', 'Error')}: $e',
            style: GoogleFonts.assistant(),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingOrderId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ordersCustomerFilter = ref.watch(ordersCustomerFilterProvider);
    final customersAsync = ref.watch(customersProvider);
    final ordersAsync = ordersCustomerFilter != null
        ? ref.watch(customerOrdersProvider(ordersCustomerFilter.id))
        : ref.watch(ordersProvider);

    ref.listen<Customer?>(ordersCustomerFilterProvider, (previous, next) {
      if (previous?.id == next?.id || !mounted) return;
      setState(() => _currentPage = 1);
    });

    final customers = customersAsync.value ?? [];

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
          EditorialScreenTitle(
            title: l10n?.tr('orders') ?? 'Orders',
          ),

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
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (ordersCustomerFilter != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person_pin_circle_outlined,
                                      size: 22,
                                      color: AppTheme.secondary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '${ordersCustomerFilter.cardName} — ${ordersCustomerFilter.customerName}',
                                        style: GoogleFonts.assistant(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: AppTheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () {
                                        ref
                                            .read(
                                              ordersCustomerFilterProvider
                                                  .notifier,
                                            )
                                            .setFilter(null);
                                        setState(() {
                                          _currentPage = 1;
                                        });
                                      },
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                      ),
                                      label: Text(
                                        l10n?.tr('clearFilter') ??
                                            'Clear filter',
                                        style: GoogleFonts.assistant(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppTheme.secondary,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Material(
                                    elevation: 2,
                                    shadowColor:
                                        Colors.black.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(20),
                                    child: TextField(
                                      controller: _searchCtrl,
                                      onChanged: (_) => setState(() {
                                        _currentPage = 1;
                                      }),
                                      style: GoogleFonts.assistant(
                                        color: AppTheme.onSurface,
                                      ),
                                      decoration: InputDecoration(
                                        floatingLabelBehavior:
                                            FloatingLabelBehavior.auto,
                                        floatingLabelAlignment:
                                            FloatingLabelAlignment.start,
                                        labelText: _ordersSearchFieldLabel(),
                                        labelStyle: GoogleFonts.assistant(
                                          color: AppTheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                        floatingLabelStyle:
                                            GoogleFonts.assistant(
                                          color: AppTheme.secondary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.search_rounded,
                                          color: AppTheme.secondary,
                                        ),
                                        filled: true,
                                        fillColor:
                                            AppTheme.surfaceContainerLowest,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          borderSide: BorderSide(
                                            color: AppTheme.outlineVariant
                                                .withValues(alpha: 0.35),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          borderSide: BorderSide(
                                            color: AppTheme.outlineVariant
                                                .withValues(alpha: 0.35),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          borderSide: const BorderSide(
                                            color: AppTheme.secondary,
                                            width: 1.6,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.fromLTRB(
                                          8,
                                          14,
                                          12,
                                          14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                FilledButton.tonalIcon(
                                  onPressed: _resetFilters,
                                  icon: const Icon(
                                      Icons.restart_alt_rounded, size: 22),
                                  label: Text(
                                    l10n?.tr('resetFilters') ??
                                        'Reset filters',
                                    style: GoogleFonts.assistant(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    backgroundColor: AppTheme.secondaryContainer
                                        .withValues(alpha: 0.45),
                                    foregroundColor: AppTheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SizedBox(
                                  width: 280,
                                  child: _buildCardNameFilterDropdown(
                                    customers,
                                    ordersCustomerFilter,
                                    l10n,
                                  ),
                                ),
                                SizedBox(
                                  width: 220,
                                  child: _buildCreatedByDropdown(
                                      uniqueCreators, l10n),
                                ),
                                SizedBox(
                                  width: 240,
                                  child: _buildStatusDropdown(l10n),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
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
                                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      physics: const BouncingScrollPhysics(),
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                            minWidth: constraints.maxWidth),
                                        child: ClipRRect(
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(16),
                                            topRight: Radius.circular(16),
                                          ),
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
                          final statusColor = orderStatusColor(order.status);
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
                                  popUpAnimationStyle: AnimationStyle(
                                    curve: Curves.easeOutCubic,
                                    reverseCurve: Curves.easeInCubic,
                                    duration: const Duration(milliseconds: 280),
                                    reverseDuration:
                                        const Duration(milliseconds: 220),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: AppTheme.outlineVariant
                                          .withValues(alpha: 0.2),
                                    ),
                                  ),
                                  color: AppTheme.surfaceContainerLowest,
                                  elevation: 12,
                                  shadowColor:
                                      Colors.black.withValues(alpha: 0.12),
                                  onSelected: (value) {
                                    if (value == _cancelAndNotifyValue) {
                                      _cancelOrderAndNotifySuppliers(order.id);
                                      return;
                                    }
                                    _updateOrderStatus(order.id, value);
                                  },
                                  itemBuilder: (context) {
                                    final entries = <PopupMenuEntry<String>>[
                                      ...OrderStatusExtension.all.map(
                                        (s) => PopupMenuItem<String>(
                                          padding: EdgeInsets.zero,
                                          value: s.dbValue,
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: order.status == s
                                                  ? orderStatusColor(s)
                                                      .withValues(alpha: 0.12)
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              children: [
                                                dropdownMenuEntryStatusDot(s),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    orderStatusLocalizedLabel(
                                                        s, l10n),
                                                    style: GoogleFonts.assistant(
                                                      fontWeight:
                                                          order.status == s
                                                              ? FontWeight.w800
                                                              : FontWeight.w500,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                if (order.status == s)
                                                  Icon(
                                                    Icons.check_rounded,
                                                    size: 18,
                                                    color: AppTheme.secondary,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ];

                                    if (order.status == OrderStatus.sentToSupplier) {
                                      entries.add(const PopupMenuDivider(height: 10));
                                      entries.add(
                                        PopupMenuItem<String>(
                                          value: _cancelAndNotifyValue,
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.cancel_rounded,
                                                size: 18,
                                                color: AppTheme.error,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  _t(
                                                    l10n,
                                                    'cancelAndNotifySupplier',
                                                    'Cancel & notify supplier',
                                                  ),
                                                  style: GoogleFonts.assistant(
                                                    fontWeight: FontWeight.w700,
                                                    color: AppTheme.error,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }

                                    return entries;
                                  },
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
                                                orderStatusLocalizedLabel(
                                                    order.status, l10n),
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
                                        )),
                                      ),
                                    );
                                  },
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

  Widget _buildCardNameFilterDropdown(
    List<Customer> customers,
    Customer? selected,
    AppLocalizations? l10n,
  ) {
    final sorted = [...customers]
      ..sort(
        (a, b) => a.cardName.toLowerCase().compareTo(b.cardName.toLowerCase()),
      );

    return DropdownMenu<String>(
      key: ValueKey('card_filter_${selected?.id ?? 'all'}'),
      initialSelection: selected?.id ?? '',
      width: 280,
      enableFilter: true,
      requestFocusOnTap: true,
      leadingIcon: dropdownLeadingSlot(
        Icon(
          selected == null ? Icons.badge_outlined : Icons.badge_rounded,
          size: 18,
          color: AppTheme.secondary,
        ),
      ),
      label: Text(
        l10n?.tr('cardName') ?? 'שם כרטיס',
        style: GoogleFonts.assistant(
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      menuStyle: appDropdownMenuStyle(),
      inputDecorationTheme:
          appDropdownInputDecorationTheme().copyWith(fillColor: Colors.white),
      textStyle: GoogleFonts.assistant(
        color: AppTheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      trailingIcon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppTheme.secondary,
      ),
      selectedTrailingIcon: Icon(
        Icons.keyboard_arrow_up_rounded,
        color: AppTheme.secondary,
      ),
      onSelected: (id) {
        if (id == null) return;
        if (id.isEmpty) {
          ref.read(ordersCustomerFilterProvider.notifier).setFilter(null);
        } else {
          final match = sorted.where((c) => c.id == id);
          if (match.isEmpty) return;
          ref.read(ordersCustomerFilterProvider.notifier).setFilter(match.first);
        }
        setState(() => _currentPage = 1);
      },
      dropdownMenuEntries: [
        DropdownMenuEntry<String>(
          value: '',
          label: l10n?.tr('all') ?? 'All',
          leadingIcon: dropdownLeadingSlot(
            Icon(
              Icons.groups_outlined,
              size: 16,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ),
        ...sorted.map(
          (c) => DropdownMenuEntry<String>(
            value: c.id,
            label: '${c.cardName} — ${c.customerName}',
            leadingIcon: dropdownLeadingSlot(
              Icon(
                Icons.badge_outlined,
                size: 16,
                color: AppTheme.secondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreatedByDropdown(List<String> creators, AppLocalizations? l10n) {
    final createdByLeading = dropdownLeadingSlot(
      Icon(
        _createdByFilter == 'All'
            ? Icons.people_outline_rounded
            : Icons.person_rounded,
        size: 18,
        color: AppTheme.secondary,
      ),
    );
    return DropdownMenu<String>(
      key: ValueKey('creator_${_createdByFilter}_${creators.length}'),
      initialSelection: _createdByFilter,
      width: 220,
      selectOnly: true,
      enableFilter: false,
      enableSearch: false,
      leadingIcon: createdByLeading,
      decorationBuilder: animatedDropdownDecorationBuilder(
        label: Text(
          l10n?.tr('createdBy') ?? 'Created by',
          style: GoogleFonts.assistant(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        leadingIcon: createdByLeading,
      ),
      menuStyle: appDropdownMenuStyle(),
      inputDecorationTheme:
          appDropdownInputDecorationTheme().copyWith(fillColor: Colors.white),
      textStyle: GoogleFonts.assistant(
        color: AppTheme.onSurface,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      onSelected: (v) {
        if (v != null) {
          setState(() {
            _createdByFilter = v;
            _currentPage = 1;
          });
        }
      },
      dropdownMenuEntries: creators.map((f) {
        final label = f == 'All' ? (l10n?.tr('all') ?? 'All') : f;
        return DropdownMenuEntry<String>(
          value: f,
          label: label,
          leadingIcon: dropdownLeadingSlot(
            f == 'All'
                ? Icon(
                    Icons.groups_outlined,
                    size: 16,
                    color: AppTheme.onSurfaceVariant,
                  )
                : Icon(
                    Icons.person_outline_rounded,
                    size: 18,
                    color: AppTheme.secondary,
                  ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusDropdown(AppLocalizations? l10n) {
    final filters = [
      'All',
      ...OrderStatusExtension.all.map((s) => s.dbValue),
    ];
    final statusLeading = leadingIconForStatusFilterValue(_statusFilter);
    return DropdownMenu<String>(
      key: ValueKey('ord_stat_$_statusFilter'),
      initialSelection: _statusFilter,
      width: 240,
      selectOnly: true,
      enableFilter: false,
      enableSearch: false,
      leadingIcon: statusLeading,
      decorationBuilder: animatedDropdownDecorationBuilder(
        label: Text(
          l10n?.tr('status') ?? 'Status',
          style: GoogleFonts.assistant(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        leadingIcon: statusLeading,
      ),
      menuStyle: appDropdownMenuStyle(),
      inputDecorationTheme:
          appDropdownInputDecorationTheme().copyWith(fillColor: Colors.white),
      textStyle: GoogleFonts.assistant(
        color: AppTheme.onSurface,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      onSelected: (v) {
        if (v != null) {
          setState(() {
            _statusFilter = v;
            _currentPage = 1;
          });
        }
      },
      dropdownMenuEntries: filters.map((f) {
        final label = f == 'All'
            ? (l10n?.tr('all') ?? 'All')
            : orderStatusLocalizedLabel(
                OrderStatusExtension.fromString(f),
                l10n,
              );
        return DropdownMenuEntry<String>(
          value: f,
          label: label,
          leadingIcon: leadingIconForStatusFilterValue(f),
        );
      }).toList(),
    );
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    setState(() => _updatingOrderId = orderId);
    try {
      final username = ref.read(currentUsernameProvider);
      await ref
          .read(orderServiceProvider)
          .updateStatus(orderId, newStatus, username);

      // If delivery begins or status becomes Delivered, start warranty counting.
      await ref.read(orderServiceProvider).startWarrantyIfEligible(
            orderId,
            username,
          );
      ref.invalidate(ordersProvider);
      ref.invalidate(customersProvider);
      ref.invalidate(totalUnpaidDebtsProvider);
      final fc = ref.read(ordersCustomerFilterProvider);
      if (fc != null) {
        ref.invalidate(customerOrdersProvider(fc.id));
      }
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
