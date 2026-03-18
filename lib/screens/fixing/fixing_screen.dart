import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/customer.dart';
import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../models/room.dart';
import '../../models/supplier.dart';
import '../../providers/providers.dart';

class FixingScreen extends ConsumerStatefulWidget {
  const FixingScreen({super.key});

  @override
  ConsumerState<FixingScreen> createState() => _FixingScreenState();
}

class _FixingScreenState extends ConsumerState<FixingScreen> {
  Customer? _selectedCustomer;
  final Map<String, Set<String>> _selectedItemIds = {};
  final List<_ExtraItemRow> _extraItems = [];
  bool _isLoading = false;

  void _showCustomerPicker(
    BuildContext context,
    List<Customer> customers,
    AppLocalizations? l10n,
  ) {
    final searchController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final query = searchController.text.trim().toLowerCase();
          final filtered = query.isEmpty
              ? customers
              : customers.where((c) {
                  return c.cardName.toLowerCase().contains(query) ||
                      c.customerName.toLowerCase().contains(query) ||
                      c.phones.any((p) => p.contains(query));
                }).toList();
          return AlertDialog(
            backgroundColor: AppTheme.surfaceCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.person_search_rounded, color: AppTheme.primaryGold),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n?.tr('selectCustomerFixing') ?? 'Select customer',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: searchController,
                    onChanged: (_) => setDialogState(() {}),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: l10n?.tr('search') ?? 'Search',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppTheme.textSecondary,
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceDark.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final c = filtered[i];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(ctx).pop();
                              setState(() {
                                _selectedCustomer = c;
                                _selectedItemIds.clear();
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: AppTheme.primaryGold
                                        .withValues(alpha: 0.2),
                                    child: Text(
                                      (c.cardName.isNotEmpty
                                              ? c.cardName[0]
                                              : '?')
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: AppTheme.primaryGold,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.cardName,
                                          style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                        if (c.customerName.isNotEmpty)
                                          Text(
                                            c.customerName,
                                            style: const TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 13,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 14,
                                    color: AppTheme.textSecondary
                                        .withValues(alpha: 0.7),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) => searchController.dispose());
  }

  bool _isItemSelected(Order order, OrderItem item) {
    final set = _selectedItemIds[order.id];
    if (set == null) return false;
    return item.id != null && set.contains(item.id);
  }

  void _toggleItem(Order order, OrderItem item) {
    if (item.id == null) return;
    setState(() {
      _selectedItemIds.putIfAbsent(order.id, () => {});
      final set = _selectedItemIds[order.id]!;
      if (set.contains(item.id)) {
        set.remove(item.id);
      } else {
        set.add(item.id!);
      }
    });
  }

  void _selectAllOrderItems(Order order) {
    setState(() {
      _selectedItemIds[order.id] = order.items
          .where((i) => i.id != null)
          .map((i) => i.id!)
          .toSet();
    });
  }

  void _deselectAllOrderItems(Order order) {
    setState(() => _selectedItemIds[order.id] = {});
  }

  int get _totalSelectedFromOrders {
    int n = 0;
    for (final set in _selectedItemIds.values) n += set.length;
    return n;
  }

  int get _totalExtraItemsWithName {
    return _extraItems
        .where((r) => r.nameCtrl.text.trim().isNotEmpty)
        .length;
  }

  List<OrderItem> _collectSelectedItemsFromOrders(List<Order> orders) {
    final list = <OrderItem>[];
    for (final order in orders) {
      final set = _selectedItemIds[order.id];
      if (set == null || set.isEmpty) continue;
      for (final item in order.items) {
        if (item.id != null && set.contains(item.id)) {
          list.add(item.copyWith(id: null, orderId: null));
        }
      }
    }
    return list;
  }

  Future<void> _createFixingOrder() async {
    final l10n = AppLocalizations.of(context);
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.tr('pleaseSelectCustomerFirst') ??
              'Please select a customer first'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    final ordersAsync = ref.read(
        customerOrdersWithItemsProvider(_selectedCustomer!.id));
    final orders = ordersAsync.value ?? [];
    final fromOrders = _collectSelectedItemsFromOrders(orders);
    final extraItems = _extraItems
        .map(
          (row) => OrderItem(
            name: row.nameCtrl.text.trim(),
            itemNumber: row.itemNumberCtrl.text.trim().isEmpty
                ? null
                : row.itemNumberCtrl.text.trim(),
            quantity: int.tryParse(row.quantityCtrl.text) ?? 1,
            notes: row.notesCtrl.text.trim().isEmpty
                ? null
                : row.notesCtrl.text.trim(),
            price: double.tryParse(row.priceCtrl.text) ?? 0,
            assemblyRequired: false,
            roomId: row.roomId,
            supplierId: row.supplierId,
            existingInStore: row.existingInStore,
            createdBy: ref.read(currentUsernameProvider),
            updatedBy: ref.read(currentUsernameProvider),
          ),
        )
        .where((i) => i.name.isNotEmpty)
        .toList();

    if (fromOrders.isEmpty && extraItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.tr('addAtLeastOneItemFixing') ??
              'Add at least one item from orders or additional items'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final username = ref.read(currentUsernameProvider);
      final allItems = [...fromOrders, ...extraItems];
      double total = 0;
      for (final item in allItems) {
        total += item.price * item.quantity;
      }
      final order = Order(
        id: '',
        customerId: _selectedCustomer!.id,
        assemblyRequired: false,
        status: OrderStatus.active,
        totalPrice: total,
        notes: l10n?.tr('fixingOrderNote') ?? 'Fixing',
        createdBy: username,
        updatedBy: username,
      );
      await ref.read(orderServiceProvider).create(order, allItems);
      ref.invalidate(ordersProvider);
      ref.invalidate(customerOrdersWithItemsProvider(_selectedCustomer!.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.tr('fixingOrderCreated') ?? 'Fixing order created'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _selectedItemIds.clear();
          for (final row in _extraItems) {
            row.nameCtrl.clear();
            row.itemNumberCtrl.clear();
            row.quantityCtrl.text = '1';
            row.notesCtrl.clear();
            row.priceCtrl.text = '0';
          }
          _extraItems.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${l10n?.tr('error') ?? 'Error'}: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    for (final row in _extraItems) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final customersAsync = ref.watch(customersProvider);
    final customerId = _selectedCustomer?.id ?? '';
    final ordersAsync = ref.watch(customerOrdersWithItemsProvider(customerId));
    final roomsAsync = ref.watch(roomsProvider);
    final suppliersAsync = ref.watch(suppliersProvider);
    final totalSelected = _totalSelectedFromOrders + _totalExtraItemsWithName;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n?.tr('fixing') ?? 'Fixing'),
            Text(
              l10n?.tr('fixingSubtitle') ?? 'Select customer and items',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: AppTheme.textSecondary.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
        actions: [
          if (_selectedCustomer != null && totalSelected > 0)
            Container(
              margin: const EdgeInsets.only(left: 8, right: 8, top: 12, bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.primaryGold.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 18, color: AppTheme.primaryGold),
                  const SizedBox(width: 6),
                  Text(
                    '${l10n?.tr('selectedItemsCount') ?? 'Selected'} $totalSelected ${l10n?.tr('itemsShort') ?? 'items'}',
                    style: const TextStyle(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          if (_selectedCustomer != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 16, top: 10, bottom: 10),
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _createFixingOrder,
                icon: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black54,
                        ),
                      )
                    : const Icon(Icons.add_task_rounded, size: 20),
                label: Text(l10n?.tr('createFixingOrder') ?? 'Create fixing order'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Step 1: Customer selector ─────────────────────────────
            _SectionHeader(
              icon: Icons.person_rounded,
              title: l10n?.tr('customerName') ?? 'Customer',
            ),
            const SizedBox(height: 10),
            customersAsync.when(
              data: (customers) {
                if (_selectedCustomer == null) {
                  return _EmptyCard(
                    icon: Icons.touch_app_rounded,
                    message: l10n?.tr('selectCustomerFixing') ??
                        'Select customer for fixing',
                    subtitle: l10n?.tr('fixingSubtitle') ??
                        'Select a customer, then pick items...',
                    onTap: () => _showCustomerPicker(context, customers, l10n),
                  );
                }
                return _CustomerCard(
                  customer: _selectedCustomer!,
                  changeLabel: l10n?.tr('changeCustomer') ?? 'Change customer',
                  onTap: () => _showCustomerPicker(context, customers, l10n),
                );
              },
              loading: () => const _LoadingCard(),
              error: (_, __) => _EmptyCard(
                icon: Icons.error_outline_rounded,
                message: l10n?.tr('errorLoadingCustomers') ??
                    'Error loading customers',
                onTap: null,
              ),
            ),

            if (_selectedCustomer != null) ...[
              const SizedBox(height: 28),
              // ─── Step 2: Items from orders ──────────────────────────────
              _SectionHeader(
                icon: Icons.shopping_bag_rounded,
                title: l10n?.tr('itemsFromOrders') ?? 'Items from customer orders',
              ),
              const SizedBox(height: 10),
              ordersAsync.when(
                data: (orders) {
                  if (orders.isEmpty) {
                    return _EmptyCard(
                      icon: Icons.inbox_rounded,
                      message: l10n?.tr('noOrdersForCustomer') ??
                          'This customer has no orders yet.',
                      subtitle: l10n?.tr('addItemsFromOrdersOrExtra') ??
                          'Add additional items below.',
                      onTap: null,
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: orders.map((order) {
                        final selectedCount = (_selectedItemIds[order.id]?.length ?? 0);
                        return Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                            splashColor: AppTheme.primaryGold.withValues(alpha: 0.1),
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: true,
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            collapsedShape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            iconColor: AppTheme.primaryGold,
                            collapsedIconColor: AppTheme.textSecondary,
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  '#${order.orderNumber ?? '–'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryGold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '₪${order.totalPrice.toStringAsFixed(2)} • ${order.items.length} ${l10n?.tr('itemsShort') ?? 'items'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                if (selectedCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryGold
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$selectedCount ${l10n?.tr('selectedItemsCount') ?? 'selected'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primaryGold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            controlAffinity: ListTileControlAffinity.trailing,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 12, right: 12, bottom: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () =>
                                          _selectAllOrderItems(order),
                                      icon: const Icon(Icons.select_all_rounded,
                                          size: 18, color: AppTheme.primaryGold),
                                      label: Text(
                                          l10n?.tr('selectAll') ?? 'Select all'),
                                    ),
                                    TextButton.icon(
                                      onPressed: () =>
                                          _deselectAllOrderItems(order),
                                      icon: Icon(Icons.deselect_rounded,
                                          size: 18,
                                          color: AppTheme.textSecondary),
                                      label: Text(
                                          l10n?.tr('deselectAll') ?? 'Deselect all'),
                                    ),
                                  ],
                                ),
                              ),
                              ...order.items.map((item) {
                                final selected =
                                    _isItemSelected(order, item);
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppTheme.primaryGold
                                            .withValues(alpha: 0.08)
                                        : AppTheme.surfaceLight
                                            .withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected
                                          ? AppTheme.primaryGold
                                              .withValues(alpha: 0.3)
                                          : Colors.transparent,
                                      width: 1,
                                    ),
                                  ),
                                  child: CheckboxListTile(
                                    value: selected,
                                    onChanged: (v) => _toggleItem(order, item),
                                    title: Text(
                                      '${item.name} × ${item.quantity}',
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                    subtitle: item.notes != null &&
                                            item.notes!.isNotEmpty
                                        ? Padding(
                                            padding: const EdgeInsets.only(
                                                top: 4),
                                            child: Text(
                                              item.notes!,
                                              style: const TextStyle(
                                                color: AppTheme.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          )
                                        : null,
                                    secondary: Text(
                                      '₪${(item.price * item.quantity).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: AppTheme.primaryGold,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    activeColor: AppTheme.primaryGold,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 4),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
                loading: () => const _LoadingCard(),
                error: (e, _) => _EmptyCard(
                  icon: Icons.error_outline_rounded,
                  message: '${l10n?.tr('error') ?? 'Error'}: $e',
                  onTap: null,
                ),
              ),

              const SizedBox(height: 28),
              // ─── Step 3: Additional items ─────────────────────────────────
              _SectionHeader(
                icon: Icons.add_circle_outline_rounded,
                title: l10n?.tr('additionalFixingItems') ??
                    'Additional items (not from orders)',
              ),
              const SizedBox(height: 10),
              if (_extraItems.isEmpty)
                _EmptyCard(
                  icon: Icons.add_box_rounded,
                  message: l10n?.tr('noAdditionalItems') ??
                      'No additional items. Tap "Add item" to add fixing items not from any order.',
                  onTap: () => setState(() => _extraItems.add(_ExtraItemRow())),
                  actionLabel: l10n?.tr('addItem') ?? 'Add item',
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ..._extraItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final row = entry.value;
                        return roomsAsync.when(
                          data: (rooms) => suppliersAsync.when(
                            data: (suppliers) => _buildExtraItemRow(
                              l10n,
                              index,
                              row,
                              rooms,
                              suppliers,
                            ),
                            loading: () => const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            error: (_, __) => ListTile(
                              title: Text(l10n?.tr('error') ?? 'Error'),
                            ),
                          ),
                          loading: () => const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (_, __) => ListTile(
                            title: Text(l10n?.tr('error') ?? 'Error'),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _extraItems.add(_ExtraItemRow())),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: Text(l10n?.tr('addItem') ?? 'Add item'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExtraItemRow(
    AppLocalizations? l10n,
    int index,
    _ExtraItemRow row,
    List<Room> rooms,
    List<Supplier> suppliers,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: row.nameCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n?.tr('itemName') ?? 'Name',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppTheme.error, size: 22),
                onPressed: () {
                  setState(() {
                    row.dispose();
                    _extraItems.removeAt(index);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 100,
                child: TextField(
                  controller: row.itemNumberCtrl,
                  decoration: InputDecoration(
                    labelText: l10n?.tr('itemNumber') ?? 'Item #',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: row.quantityCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n?.tr('quantity') ?? 'Qty',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: row.priceCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n?.tr('price') ?? 'Price',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              SizedBox(
                width: 130,
                child: DropdownButtonFormField<String>(
                  value: row.roomId,
                  decoration: InputDecoration(
                    labelText: l10n?.tr('room') ?? 'Room',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: rooms
                      .map(
                        (r) => DropdownMenuItem(
                          value: r.id,
                          child: Text(r.name, style: const TextStyle(fontSize: 13)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => row.roomId = v),
                ),
              ),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(
                  value: row.supplierId,
                  decoration: InputDecoration(
                    labelText: l10n?.tr('supplier') ?? 'Supplier',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: suppliers
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.companyName,
                              style: const TextStyle(fontSize: 13)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => row.supplierId = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
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
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryGold,
          ),
        ),
      ],
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final String changeLabel;
  final VoidCallback onTap;

  const _CustomerCard({
    required this.customer,
    required this.changeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.primaryGold.withValues(alpha: 0.2),
                child: Text(
                  (customer.cardName.isNotEmpty ? customer.cardName[0] : '?')
                      .toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.primaryGold,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.cardName,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    if (customer.customerName.isNotEmpty)
                      Text(
                        customer.customerName,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      changeLabel,
                      style: TextStyle(
                        color: AppTheme.primaryGold.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.edit_rounded,
                color: AppTheme.primaryGold.withValues(alpha: 0.8),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;
  final VoidCallback? onTap;
  final String? actionLabel;

  const _EmptyCard({
    required this.icon,
    required this.message,
    this.subtitle,
    this.onTap,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 48,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.9),
                fontSize: 13,
              ),
            ),
          ],
          if (onTap != null && actionLabel != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
    if (onTap != null && actionLabel == null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: child,
        ),
      );
    }
    return child;
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ExtraItemRow {
  final nameCtrl = TextEditingController();
  final itemNumberCtrl = TextEditingController();
  final quantityCtrl = TextEditingController(text: '1');
  final notesCtrl = TextEditingController();
  final priceCtrl = TextEditingController(text: '0');
  String? roomId;
  String? supplierId;
  bool existingInStore = true;

  void dispose() {
    nameCtrl.dispose();
    itemNumberCtrl.dispose();
    quantityCtrl.dispose();
    notesCtrl.dispose();
    priceCtrl.dispose();
  }
}
