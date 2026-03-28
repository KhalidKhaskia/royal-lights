import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/customer.dart';
import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../models/room.dart';
import '../../models/supplier.dart';
import '../../providers/providers.dart';

class OrderFormScreen extends ConsumerStatefulWidget {
  final String? orderId;
  final Customer? initialCustomer;
  const OrderFormScreen({super.key, this.orderId, this.initialCustomer});

  @override
  ConsumerState<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends ConsumerState<OrderFormScreen> {
  Customer? _selectedCustomer;
  bool _assemblyRequired = false;
  DateTime? _assemblyDate;
  final _notesController = TextEditingController();
  List<_ItemRow> _items = [];
  bool _isLoading = false;
  bool _isEdit = false;
  Order? _existingOrder;
  final _customerSelectorKey = GlobalKey();
  OverlayEntry? _customerOverlayEntry;
  final _customerSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialCustomer != null) {
      _selectedCustomer = widget.initialCustomer;
    }
    if (widget.orderId != null) {
      _isEdit = true;
      _loadOrder();
    } else {
      _items.add(_ItemRow());
    }
  }

  Future<void> _loadOrder() async {
    setState(() => _isLoading = true);
    try {
      final order = await ref
          .read(orderServiceProvider)
          .getById(widget.orderId!);
      setState(() {
        _existingOrder = order;
        _assemblyRequired = order.assemblyRequired;
        _assemblyDate = order.assemblyDate;
        _notesController.text = order.notes ?? '';
        _items = order.items.map((item) {
          final row = _ItemRow();
          row.itemNumberCtrl.text = item.itemNumber ?? '';
          row.nameCtrl.text = item.name;
          row.quantityCtrl.text = item.quantity.toString();
          row.extrasCtrl.text = item.extras ?? '';
          row.notesCtrl.text = item.notes ?? '';
          row.priceCtrl.text = item.price.toString();
          row.assemblyRequired = item.assemblyRequired;
          row.roomId = item.roomId;
          row.supplierId = item.supplierId;
          row.existingInStore = item.existingInStore;
          row.imageUrl = item.imageUrl;
          return row;
        }).toList();
        if (_items.isEmpty) _items.add(_ItemRow());
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  double get _totalPrice {
    double total = 0;
    for (final item in _items) {
      final price = double.tryParse(item.priceCtrl.text) ?? 0;
      final qty = int.tryParse(item.quantityCtrl.text) ?? 1;
      total += price * qty;
    }
    return total;
  }

  void _hideCustomerDropdown() {
    _customerOverlayEntry?.remove();
    _customerOverlayEntry = null;
    setState(() {});
  }

  void _showCustomerPicker(
    BuildContext context,
    List<Customer> customers,
    AppLocalizations? l10n,
  ) {
    if (_customerOverlayEntry != null) {
      _hideCustomerDropdown();
      return;
    }
    _customerSearchController.clear();
    final box = _customerSelectorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    final overlay = Overlay.of(context);
    final searchHint = l10n?.tr('search') ?? 'Search';

    _customerOverlayEntry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // Tap-outside to close
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _hideCustomerDropdown,
            ),
          ),
          Positioned(
            left: pos.dx,
            top: pos.dy + size.height + 4,
            width: size.width,
            height: 320,
            child: Material(
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              color: AppTheme.surfaceContainerLowest,
              child: StatefulBuilder(
                builder: (ctx, setOverlayState) {
                  final query = _customerSearchController.text.trim().toLowerCase();
                  final filtered = query.isEmpty
                      ? customers
                      : customers.where((c) {
                          return c.cardName.toLowerCase().contains(query) ||
                              c.customerName.toLowerCase().contains(query) ||
                              c.phones.any((p) => p.contains(query));
                        }).toList();
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        child: TextField(
                          controller: _customerSearchController,
                          onChanged: (_) {
                            setOverlayState(() {});
                          },
                          style: const TextStyle(color: AppTheme.onSurface),
                          decoration: InputDecoration(
                            hintText: searchHint,
                            hintStyle: TextStyle(color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            prefixIcon: const Icon(
                              Icons.search,
                              size: 20,
                              color: AppTheme.onSurfaceVariant,
                            ),
                            filled: true,
                            fillColor: AppTheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final c = filtered[i];
                            return InkWell(
                              onTap: () {
                                setState(() => _selectedCustomer = c);
                                _hideCustomerDropdown();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Text(
                                  '${c.cardName} - ${c.customerName}',
                                  style: const TextStyle(
                                    color: AppTheme.onSurface,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_customerOverlayEntry!);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final customersAsync = ref.watch(customersProvider);
    final roomsAsync = ref.watch(roomsProvider);
    final suppliersAsync = ref.watch(suppliersProvider);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n?.tr('orders') ?? 'Order')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit
              ? '${l10n?.tr('edit') ?? 'Edit'} #${_existingOrder?.orderNumber ?? ''}'
              : l10n?.tr('newOrder') ?? 'New Order',
        ),
        actions: [
          // Total price display
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Text(
                  '${l10n?.tr('totalPrice') ?? 'Total'}: ',
                  style: const TextStyle(color: AppTheme.onSecondaryContainer, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Text(
                  '₪${_totalPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: AppTheme.onSecondaryContainer,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Save button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: ElevatedButton.icon(
              onPressed: _saveOrder,
              icon: const Icon(Icons.save_rounded, size: 20),
              label: Text(l10n?.tr('save') ?? 'Save'),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  // Customer selector (searchable dropdown)
                  Expanded(
                    flex: 3,
                    child: customersAsync.when(
                      data: (customers) {
                        if (_isEdit &&
                            _existingOrder != null &&
                            _selectedCustomer == null) {
                          _selectedCustomer = customers
                              .where((c) => c.id == _existingOrder!.customerId)
                              .firstOrNull;
                        }
                        return KeyedSubtree(
                          key: _customerSelectorKey,
                          child: InkWell(
                            onTap: () => _showCustomerPicker(
                                context, customers, l10n),
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                            decoration: InputDecoration(
                              labelText:
                                  l10n?.tr('customerName') ?? 'Customer',
                              prefixIcon:
                                  const Icon(Icons.person_outline),
                              suffixIcon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: AppTheme.textSecondary,
                                ),
                            ),
                            child: Text(
                              _selectedCustomer == null
                                  ? ''
                                  : '${_selectedCustomer!.cardName} - ${_selectedCustomer!.customerName}',
                              style: TextStyle(
                                color: _selectedCustomer == null
                                    ? AppTheme.onSurfaceVariant
                                        .withValues(alpha: 0.6)
                                    : AppTheme.onSurface,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        );
                      },
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => const Text('Error loading customers'),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Assembly toggle (fixed width so it never moves)
                  SizedBox(
                    width: 200,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n?.tr('assemblyRequired') ?? 'Assembly',
                          style: const TextStyle(color: AppTheme.onSurfaceVariant),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _assemblyRequired,
                          onChanged: (v) {
                            setState(() {
                              _assemblyRequired = v;
                              for (final item in _items) {
                                item.assemblyRequired = v;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Assembly date (always same space; visibility animated)
                  Expanded(
                    flex: 2,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _assemblyRequired ? 1 : 0,
                      child: IgnorePointer(
                        ignoring: !_assemblyRequired,
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _assemblyDate ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (date != null)
                              setState(() => _assemblyDate = date);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText:
                                  l10n?.tr('assemblyDate') ?? 'Assembly Date',
                              prefixIcon: const Icon(
                                Icons.calendar_today_outlined,
                              ),
                            ),
                            child: Text(
                              _assemblyDate?.toString().split(' ').first ??
                                  'Select date',
                              style: TextStyle(
                                color: _assemblyDate != null
                                    ? AppTheme.onSurface
                                    : AppTheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Notes
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: l10n?.tr('notes') ?? 'Notes',
                        prefixIcon: const Icon(Icons.note_outlined),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Items header
            Row(
              children: [
                Text(
                  l10n?.tr('orderItems') ?? 'Order Items',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _items.add(_ItemRow())),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n?.tr('addItem') ?? 'Add Item'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.2)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: roomsAsync.when(
                  data: (rooms) => suppliersAsync.when(
                    data: (suppliers) =>
                        _buildItemsTable(l10n, rooms, suppliers),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const Text('Error'),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Text('Error'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsTable(
    AppLocalizations? l10n,
    List<Room> rooms,
    List<Supplier> suppliers,
  ) {
    return DataTable(
      headingRowHeight: 52,
      dataRowMinHeight: 56,
      dataRowMaxHeight: 64,
      columnSpacing: 12,
      columns: [
        const DataColumn(label: Text('#')),
        DataColumn(label: Text(l10n?.tr('itemNumber') ?? 'Item #')),
        DataColumn(label: Text(l10n?.tr('itemName') ?? 'Name')),
        DataColumn(label: Text(l10n?.tr('image') ?? 'Image')),
        DataColumn(label: Text(l10n?.tr('quantity') ?? 'Qty')),
        DataColumn(label: Text(l10n?.tr('extras') ?? 'Extras')),
        DataColumn(label: Text(l10n?.tr('notes') ?? 'Notes')),
        DataColumn(label: Text(l10n?.tr('price') ?? 'Price')),
        DataColumn(label: Text(l10n?.tr('assemblyRequired') ?? 'Assembly')),
        DataColumn(label: Text(l10n?.tr('room') ?? 'Room')),
        DataColumn(label: Text(l10n?.tr('supplier') ?? 'Supplier')),
        DataColumn(label: Text(l10n?.tr('existingInStore') ?? 'In Store')),
        const DataColumn(label: Text('')), // Delete
      ],
      rows: List.generate(_items.length, (index) {
        final item = _items[index];
        return DataRow(
          cells: [
            DataCell(
              Text(
                '${index + 1}',
                style: const TextStyle(
                  color: AppTheme.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // 1. Item Number
            DataCell(
              SizedBox(
                width: 100,
                child: TextField(
                  controller: item.itemNumberCtrl,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            // 2. Name
            DataCell(
              SizedBox(
                width: 140,
                child: TextField(
                  controller: item.nameCtrl,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            // 3. Image
            DataCell(
              IconButton(
                icon: Icon(
                  item.imageUrl != null
                      ? Icons.image
                      : Icons.add_a_photo_outlined,
                  color: item.imageUrl != null
                      ? AppTheme.success
                      : AppTheme.textSecondary,
                  size: 20,
                ),
                onPressed: () {
                  // Image picker placeholder
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Camera/Gallery - requires device'),
                    ),
                  );
                },
              ),
            ),
            // 4. Quantity
            DataCell(
              SizedBox(
                width: 60,
                child: TextField(
                  controller: item.quantityCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            // 5. Extras
            DataCell(
              SizedBox(
                width: 100,
                child: TextField(
                  controller: item.extrasCtrl,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            // 6. Notes
            DataCell(
              SizedBox(
                width: 100,
                child: TextField(
                  controller: item.notesCtrl,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            // 7. Price
            DataCell(
              SizedBox(
                width: 80,
                child: TextField(
                  controller: item.priceCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            // 8. Assembly Required
            DataCell(
              Checkbox(
                value: item.assemblyRequired,
                onChanged: (v) =>
                    setState(() => item.assemblyRequired = v ?? false),
                activeColor: AppTheme.secondary,
              ),
            ),
            // 9. Room dropdown
            DataCell(
              SizedBox(
                width: 120,
                child: DropdownButton<String>(
                  value: item.roomId,
                  isExpanded: true,
                  underline: const SizedBox(),
                  hint: Text(
                    l10n?.tr('room') ?? 'Room',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                  items: rooms
                      .map(
                        (r) => DropdownMenuItem(
                          value: r.id,
                          child: Text(
                            r.name,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => item.roomId = v),
                ),
              ),
            ),
            // 10. Supplier dropdown
            DataCell(
              SizedBox(
                width: 140,
                child: DropdownButton<String>(
                  value: item.supplierId,
                  isExpanded: true,
                  underline: const SizedBox(),
                  hint: Text(
                    l10n?.tr('supplier') ?? 'Supplier',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                  items: suppliers
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(
                            s.companyName,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => item.supplierId = v),
                ),
              ),
            ),
            // 11. Existing In Store
            DataCell(
              Checkbox(
                value: item.existingInStore,
                onChanged: (v) =>
                    setState(() => item.existingInStore = v ?? true),
                activeColor: AppTheme.success,
              ),
            ),
            // Delete row
            DataCell(
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppTheme.error,
                  size: 20,
                ),
                onPressed: () {
                  if (_items.length > 1) {
                    setState(() => _items.removeAt(index));
                  }
                },
              ),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _saveOrder() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a customer')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final username = ref.read(currentUsernameProvider);
      final orderItems = _items
          .map(
            (item) => OrderItem(
              itemNumber: item.itemNumberCtrl.text.trim(),
              name: item.nameCtrl.text.trim(),
              imageUrl: item.imageUrl,
              quantity: int.tryParse(item.quantityCtrl.text) ?? 1,
              extras: item.extrasCtrl.text.trim(),
              notes: item.notesCtrl.text.trim(),
              price: double.tryParse(item.priceCtrl.text) ?? 0,
              assemblyRequired: item.assemblyRequired,
              roomId: item.roomId,
              supplierId: item.supplierId,
              existingInStore: item.existingInStore,
              createdBy: username,
              updatedBy: username,
            ),
          )
          .toList();

      if (_isEdit && _existingOrder != null) {
        // Update existing order
        await ref.read(orderServiceProvider).update(_existingOrder!.id, {
          'customer_id': _selectedCustomer!.id,
          'assembly_required': _assemblyRequired,
          'assembly_date': _assemblyDate?.toIso8601String().split('T').first,
          'total_price': _totalPrice,
          'notes': _notesController.text.trim(),
          'updated_by': username,
        });
        await ref
            .read(orderServiceProvider)
            .updateItems(_existingOrder!.id, orderItems, username);
      } else {
        // Create new order
        final order = Order(
          id: '',
          customerId: _selectedCustomer!.id,
          assemblyRequired: _assemblyRequired,
          assemblyDate: _assemblyDate,
          totalPrice: _totalPrice,
          notes: _notesController.text.trim(),
          createdBy: username,
          updatedBy: username,
        );
        await ref.read(orderServiceProvider).create(order, orderItems);
      }

      ref.invalidate(ordersProvider);
      ref.invalidate(customersProvider);

      // WhatsApp Logic: filter items where existingInStore == false
      final nonStoreItems = _items.where((i) => !i.existingInStore).toList();
      if (nonStoreItems.isNotEmpty && mounted) {
        await _handleWhatsApp(nonStoreItems, username);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleWhatsApp(
    List<_ItemRow> nonStoreItems,
    String username,
  ) async {
    // Group items by supplier
    final suppliersAsync = ref.read(suppliersProvider);
    final suppliers = suppliersAsync.value ?? [];

    final Map<String, List<_ItemRow>> grouped = {};
    for (final item in nonStoreItems) {
      final key = item.supplierId ?? 'unknown';
      grouped.putIfAbsent(key, () => []).add(item);
    }

    // Build supplier names for confirmation
    final supplierNames = grouped.keys.map((id) {
      final supplier = suppliers.where((s) => s.id == id).firstOrNull;
      return supplier?.companyName ?? 'Unknown';
    }).toList();

    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.tr('sendToWhatsApp') ?? 'Send to WhatsApp'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n?.tr('whatsAppConfirm') ?? 'Send order via WhatsApp?'),
            const SizedBox(height: 12),
            ...supplierNames.map(
              (name) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.store, color: AppTheme.secondary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n?.tr('cancel') ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n?.tr('confirm') ?? 'Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (final entry in grouped.entries) {
        final supplier = suppliers.where((s) => s.id == entry.key).firstOrNull;
        if (supplier == null ||
            supplier.phone == null ||
            supplier.phone!.isEmpty)
          continue;

        final itemsText = entry.value
            .map((item) {
              return '${item.nameCtrl.text} + ${item.itemNumberCtrl.text} + ${item.quantityCtrl.text}';
            })
            .join('\n');

        final message =
            'שלום, אני $username מחנות royal light טירה מבקש לבצע הזמנה למוצרים הללו:\n$itemsText\nתודה';
        final phone = supplier.phone!.replaceAll(RegExp(r'[^\d+]'), '');
        final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';

        try {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } catch (_) {
          // WhatsApp not available
        }
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _customerSearchController.dispose();
    _hideCustomerDropdown();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }
}

class _ItemRow {
  final itemNumberCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final quantityCtrl = TextEditingController(text: '1');
  final extrasCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final priceCtrl = TextEditingController(text: '0');
  bool assemblyRequired = false;
  String? roomId;
  String? supplierId;
  bool existingInStore = true;
  String? imageUrl;

  void dispose() {
    itemNumberCtrl.dispose();
    nameCtrl.dispose();
    quantityCtrl.dispose();
    extrasCtrl.dispose();
    notesCtrl.dispose();
    priceCtrl.dispose();
  }
}
