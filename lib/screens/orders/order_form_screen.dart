import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/customer.dart';
import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../models/room.dart';
import '../../models/supplier.dart';
import '../../providers/providers.dart';
import '../../widgets/app_dropdown_styles.dart';
import '../../widgets/app_loading_overlay.dart';
import '../../widgets/app_round_checkbox.dart';

class OrderFormScreen extends ConsumerStatefulWidget {
  final String? orderId;
  final Customer? initialCustomer;
  const OrderFormScreen({super.key, this.orderId, this.initialCustomer});

  @override
  ConsumerState<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends ConsumerState<OrderFormScreen>
    with SingleTickerProviderStateMixin {
  Customer? _selectedCustomer;
  bool _assemblyRequired = false;
  DateTime? _assemblyDate;
  DateTime? _deliveryDate;
  final _assemblyPriceController = TextEditingController();
  final _notesController = TextEditingController();
  List<_ItemRow> _items = [];
  bool _isLoading = false;
  bool _hasUnsavedChanges = false;
  bool _isEdit = false;
  Order? _existingOrder;
  bool get _isReadOnly =>
      _existingOrder != null &&
      (_existingOrder!.status == OrderStatus.sentToSupplier ||
          _existingOrder!.status == OrderStatus.canceled);

  bool get _canSendToSupplier =>
      _existingOrder != null && _existingOrder!.status == OrderStatus.active;

  bool get _waitingSupplierConfirmation =>
      _existingOrder != null &&
      _existingOrder!.status == OrderStatus.sentToSupplier;

  ({String label, Color color, IconData icon}) _orderSaveStatusPill(
    BuildContext context,
    AppLocalizations? l10n,
  ) {
    if (_hasUnsavedChanges) {
      return (
        label: _orderTableColumnLabel(
          context,
          l10n,
          'notSaved',
          en: 'Not saved',
          he: 'לא נשמרה',
          ar: 'غير محفوظ',
        ),
        color: AppTheme.warning,
        icon: Icons.edit_outlined,
      );
    }
    final o = _existingOrder;
    if (o == null) {
      return (
        label: _orderTableColumnLabel(
          context,
          l10n,
          'notSaved',
          en: 'Not saved',
          he: 'לא נשמרה',
          ar: 'غير محفوظ',
        ),
        color: AppTheme.outline,
        icon: Icons.edit_outlined,
      );
    }

    switch (o.status) {
      case OrderStatus.canceled:
        return (
          label: _orderTableColumnLabel(
            context,
            l10n,
            'canceled',
            en: 'Canceled',
            he: 'מבוטלת',
            ar: 'ملغي',
          ),
          color: AppTheme.error,
          icon: Icons.cancel_rounded,
        );
      case OrderStatus.sentToSupplier:
        return (
          label: _orderTableColumnLabel(
            context,
            l10n,
            'sentToSupplier',
            en: 'Sent to supplier',
            he: 'נשלח לספק',
            ar: 'تم الإرسال للمورد',
          ),
          color: AppTheme.secondary,
          icon: Icons.send_rounded,
        );
      default:
        return (
          label: _orderTableColumnLabel(
            context,
            l10n,
            'saved',
            en: 'Saved',
            he: 'נשמרה',
            ar: 'تم الحفظ',
          ),
          color: AppTheme.success,
          icon: Icons.check_circle_rounded,
        );
    }
  }

  void _markDirty() {
    if (_isReadOnly) return;
    if (_hasUnsavedChanges) return;
    setState(() => _hasUnsavedChanges = true);
  }

  final _customerSelectorKey = GlobalKey();
  OverlayEntry? _customerOverlayEntry;
  final _customerTextController = TextEditingController();
  final _customerFocusNode = FocusNode();
  late final AnimationController _bottomDrawerController;
  final ScrollController _itemsTableHorizontalScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _bottomDrawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: 0,
    );
    if (widget.initialCustomer != null) {
      _selectedCustomer = widget.initialCustomer;
      final c = widget.initialCustomer!;
      _customerTextController.text = '${c.cardName} - ${c.customerName}';
    }
    _notesController.addListener(_markDirty);
    _assemblyPriceController.addListener(_markDirty);
    _customerFocusNode.addListener(_onCustomerFocusChange);
    if (widget.orderId != null) {
      _isEdit = true;
      _loadOrder();
    } else {
      _items.add(_ItemRow());
    }
  }

  @override
  void didUpdateWidget(covariant OrderFormScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId) {
      _bottomDrawerController.reset();
    }
  }

  Future<void> _loadOrder() async {
    setState(() => _isLoading = true);
    try {
      final order =
          await ref.read(orderServiceProvider).getById(widget.orderId!);
      setState(() {
        _existingOrder = order;
        _hasUnsavedChanges = false;
        _assemblyRequired = order.assemblyRequired;
        _assemblyDate = order.assemblyDate;
        _deliveryDate = order.deliveryDate;
        _assemblyPriceController.text =
            order.assemblyPrice > 0 ? order.assemblyPrice.toString() : '';
        _notesController.text = order.notes ?? '';
        _items = order.items.map((item) {
          final row = _ItemRow();
          row.itemNumberCtrl.text = item.itemNumber ?? '';
          row.nameCtrl.text = item.name;
          row.quantityCtrl.text = item.quantity.toString();
          row.extrasCtrl.text = item.extras ?? '';
          row.priceCtrl.text = item.price.toString();
          row.extrasPriceCtrl.text =
              item.extrasPrice == 0 ? '' : item.extrasPrice.toString();
          row.assemblyRequired = item.assemblyRequired;
          row.roomId = item.roomId;
          row.supplierId = item.supplierId;
          row.existingInStore = item.existingInStore;
          row.warrantyYears = item.warrantyYears;
          row.imageUrl = item.imageUrl;
          return row;
        }).toList();
        // If any line item requires assembly, force the order-level switch on.
        if (!_assemblyRequired && _items.any((r) => r.assemblyRequired)) {
          _assemblyRequired = true;
        }
        if (_items.isEmpty) _items.add(_ItemRow());
        _isLoading = false;
      });
      _bottomDrawerController.reset();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  double _lineTotal(_ItemRow item) {
    final qty = int.tryParse(item.quantityCtrl.text) ?? 1;
    final unitText = item.priceCtrl.text.trim().replaceAll(',', '.');
    final extrasText = item.extrasPriceCtrl.text.trim().replaceAll(',', '.');
    final unit = double.tryParse(unitText) ?? 0;
    final extrasAmt = double.tryParse(extrasText) ?? 0;

    // Both unit price and add-ons price should scale with quantity.
    return qty * (unit + extrasAmt);
  }

  double get _linesSubtotal {
    double total = 0;
    for (final item in _items) {
      total += _lineTotal(item);
    }
    return total;
  }

  /// Installation fee when assembly is required (admin input).
  double get _assemblyInstallPrice {
    if (!_assemblyRequired) return 0;
    final t = _assemblyPriceController.text.trim().replaceAll(',', '.');
    return double.tryParse(t) ?? 0;
  }

  /// Line items + installation (when required). Stored in DB as `total_price`.
  double get _totalPrice => _linesSubtotal + _assemblyInstallPrice;

  /// Pre-VAT amount for display (same as persisted `total_price`).
  double get _subtotalExVat => _totalPrice;
  static const double _vatRate = 0.18;
  double get _vatAmount => _subtotalExVat * _vatRate;
  double get _grandTotalWithVat => _subtotalExVat + _vatAmount;

  void _hideCustomerDropdown() {
    _customerOverlayEntry?.remove();
    _customerOverlayEntry = null;
    setState(() {});
  }

  void _onCustomerFocusChange() {
    if (!_customerFocusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 180), () {
        if (!mounted || _customerFocusNode.hasFocus) return;
        _hideCustomerDropdown();
      });
    }
  }

  Future<void> _pickAssemblyDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final first = today.subtract(const Duration(days: 365));
    final last = today.add(const Duration(days: 365 * 3));
    var initial = _assemblyDate ?? today;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (date != null && mounted) {
      _markDirty();
      setState(() => _assemblyDate = date);
    }
  }

  Future<void> _pickDeliveryDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final first = today.subtract(const Duration(days: 365 * 2));
    final last = today.add(const Duration(days: 365 * 5));
    var initial = _deliveryDate ?? today;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (date != null && mounted) {
      _markDirty();
      setState(() => _deliveryDate = date);
    }
  }

  void _showCustomerPicker(
    BuildContext context,
    List<Customer> customers,
    AppLocalizations? l10n,
  ) {
    if (_customerOverlayEntry != null) return;
    final box =
        _customerSelectorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    final overlay = Overlay.of(context);

    _customerOverlayEntry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
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
              child: Builder(
                builder: (ctx) {
                  final query =
                      _customerTextController.text.trim().toLowerCase();
                  final filtered = query.isEmpty
                      ? customers
                      : customers.where((c) {
                          return c.cardName.toLowerCase().contains(query) ||
                              c.customerName.toLowerCase().contains(query) ||
                              c.phones.any(
                                (p) => p.toLowerCase().contains(query),
                              );
                        }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    l10n?.tr('noMatchingResults') ??
                                        'No matches',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.assistant(
                                      color: AppTheme.onSurfaceVariant,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: filtered.length,
                                itemBuilder: (context, i) {
                                  final c = filtered[i];
                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedCustomer = c;
                                        _customerTextController.text =
                                            '${c.cardName} - ${c.customerName}';
                                      });
                                      _hideCustomerDropdown();
                                      _customerFocusNode.unfocus();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit
              ? '${l10n?.tr('edit') ?? 'Edit'} #${_existingOrder?.orderNumber ?? ''}'
              : l10n?.tr('newOrder') ?? 'New Order',
        ),
        actions: [],
      ),
      body: AppLoadingOverlay(
        isLoading: _isLoading,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order header
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.outlineVariant.withValues(alpha: 0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
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
                                      final c = customers
                                          .where(
                                            (x) =>
                                                x.id ==
                                                _existingOrder!.customerId,
                                          )
                                          .firstOrNull;
                                      _selectedCustomer = c;
                                      if (c != null) {
                                        _customerTextController.text =
                                            '${c.cardName} - ${c.customerName}';
                                      }
                                    }
                                    return KeyedSubtree(
                                      key: _customerSelectorKey,
                                      child: TextField(
                                        controller: _customerTextController,
                                        focusNode: _customerFocusNode,
                                        enabled: !_isReadOnly,
                                        readOnly: _isReadOnly,
                                        onChanged: (value) {
                                          final sel = _selectedCustomer;
                                          if (sel != null) {
                                            final expected =
                                                '${sel.cardName} - ${sel.customerName}';
                                            if (value != expected) {
                                              _selectedCustomer = null;
                                            }
                                          }
                                          setState(() {});
                                          _customerOverlayEntry
                                              ?.markNeedsBuild();
                                          if (_customerOverlayEntry == null) {
                                            _showCustomerPicker(
                                              context,
                                              customers,
                                              l10n,
                                            );
                                          }
                                        },
                                        onTap: () {
                                          if (_customerOverlayEntry == null) {
                                            _showCustomerPicker(
                                              context,
                                              customers,
                                              l10n,
                                            );
                                          }
                                        },
                                        style: GoogleFonts.assistant(
                                          fontSize: 16,
                                          color: AppTheme.onSurface,
                                        ),
                                        decoration: InputDecoration(
                                          labelText: _orderTableColumnLabel(
                                            context,
                                            l10n,
                                            'customerName',
                                            en: 'Customer Name',
                                            he: 'שם לקוח',
                                            ar: 'اسم العميل',
                                          ),
                                          labelStyle: GoogleFonts.assistant(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.onSurfaceVariant,
                                          ),
                                          floatingLabelStyle:
                                              GoogleFonts.assistant(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.secondary,
                                          ),
                                          prefixIcon: dropdownLeadingSlot(
                                            const Icon(
                                              Icons.person_outline,
                                              size: 18,
                                              color: AppTheme.secondary,
                                            ),
                                          ),
                                          suffixIcon: Icon(
                                            Icons.arrow_drop_down_rounded,
                                            color: AppTheme.secondary
                                                .withValues(alpha: 0.85),
                                          ),
                                          filled: true,
                                          fillColor: AppTheme
                                              .surfaceContainerHighest
                                              .withValues(alpha: 0.55),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            borderSide: BorderSide(
                                              color: AppTheme.outlineVariant
                                                  .withValues(alpha: 0.22),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            borderSide: BorderSide(
                                              color: AppTheme.outlineVariant
                                                  .withValues(alpha: 0.22),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            borderSide: const BorderSide(
                                              color: AppTheme.secondary,
                                              width: 1.8,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 14,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  loading: () =>
                                      const CircularProgressIndicator(),
                                  error: (_, __) =>
                                      const Text('Error loading customers'),
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
                                      _orderTableColumnLabel(
                                        context,
                                        l10n,
                                        'assemblyRequired',
                                        en: 'Assembly Required',
                                        he: 'דרוש הרכבה',
                                        ar: 'يتطلب تركيب',
                                      ),
                                      style: GoogleFonts.assistant(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IgnorePointer(
                                      ignoring: _isReadOnly,
                                      child: _AssemblyGoldSwitch(
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
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              // Assembly date + installation price (admin)
                              Expanded(
                                flex: 3,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: _assemblyRequired ? 1 : 0,
                                  child: IgnorePointer(
                                    ignoring: !_assemblyRequired || _isReadOnly,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: InkWell(
                                            onTap: _pickAssemblyDate,
                                            child: InputDecorator(
                                              isEmpty: _assemblyDate == null,
                                              decoration: InputDecoration(
                                                labelText:
                                                    _orderTableColumnLabel(
                                                  context,
                                                  l10n,
                                                  'assemblyDate',
                                                  en: 'Assembly Date',
                                                  he: 'תאריך הרכבה',
                                                  ar: 'تاريخ التركيب',
                                                ),
                                                labelStyle:
                                                    GoogleFonts.assistant(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      AppTheme.onSurfaceVariant,
                                                ),
                                                floatingLabelStyle:
                                                    GoogleFonts.assistant(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppTheme.secondary,
                                                ),
                                                prefixIcon: const Icon(
                                                  Icons.calendar_today_outlined,
                                                  color: AppTheme.secondary,
                                                ),
                                                filled: true,
                                                fillColor: AppTheme
                                                    .surfaceContainerHighest
                                                    .withValues(alpha: 0.55),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                  borderSide: BorderSide(
                                                    color: AppTheme
                                                        .outlineVariant
                                                        .withValues(
                                                            alpha: 0.22),
                                                  ),
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                  borderSide: BorderSide(
                                                    color: AppTheme
                                                        .outlineVariant
                                                        .withValues(
                                                            alpha: 0.22),
                                                  ),
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                  borderSide: const BorderSide(
                                                    color: AppTheme.secondary,
                                                    width: 1.8,
                                                  ),
                                                ),
                                                hintText: _assemblyDate == null
                                                    ? _orderTableColumnLabel(
                                                        context,
                                                        l10n,
                                                        'selectDate',
                                                        en: 'Select date',
                                                        he: 'בחר תאריך',
                                                        ar: 'اختر التاريخ',
                                                      )
                                                    : null,
                                                hintStyle:
                                                    GoogleFonts.assistant(
                                                  fontSize: 16,
                                                  color:
                                                      AppTheme.onSurfaceVariant,
                                                ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 14,
                                                ),
                                              ),
                                              child: Text(
                                                _assemblyDate == null
                                                    ? ''
                                                    : _assemblyDate!
                                                        .toString()
                                                        .split(' ')
                                                        .first,
                                                style: GoogleFonts.assistant(
                                                  fontSize: 16,
                                                  color: AppTheme.onSurface,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          flex: 2,
                                          child: TextField(
                                            controller:
                                                _assemblyPriceController,
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            inputFormatters: [
                                              FilteringTextInputFormatter.allow(
                                                RegExp(r'[0-9.,]'),
                                              ),
                                            ],
                                            onChanged: (_) {
                                              _markDirty();
                                              setState(() {});
                                            },
                                            style: GoogleFonts.assistant(
                                              fontSize: 16,
                                              color: AppTheme.onSurface,
                                            ),
                                            decoration: InputDecoration(
                                              labelText: _orderTableColumnLabel(
                                                context,
                                                l10n,
                                                'assemblyInstallationPrice',
                                                en: 'Installation price',
                                                he: 'מחיר התקנה',
                                                ar: 'سعر التركيب',
                                              ),
                                              hintText: _orderTableColumnLabel(
                                                context,
                                                l10n,
                                                'assemblyInstallationPriceHint',
                                                en: '0',
                                                he: '0',
                                                ar: '0',
                                              ),
                                              labelStyle: GoogleFonts.assistant(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    AppTheme.onSurfaceVariant,
                                              ),
                                              floatingLabelStyle:
                                                  GoogleFonts.assistant(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.secondary,
                                              ),
                                              prefixText: '₪ ',
                                              prefixStyle:
                                                  GoogleFonts.assistant(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.secondary,
                                              ),
                                              filled: true,
                                              fillColor: AppTheme
                                                  .surfaceContainerHighest
                                                  .withValues(alpha: 0.55),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                                borderSide: BorderSide(
                                                  color: AppTheme.outlineVariant
                                                      .withValues(alpha: 0.22),
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                                borderSide: BorderSide(
                                                  color: AppTheme.outlineVariant
                                                      .withValues(alpha: 0.22),
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                                borderSide: const BorderSide(
                                                  color: AppTheme.secondary,
                                                  width: 1.8,
                                                ),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Items header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          l10n?.tr('orderItems') ?? 'Order Items',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 248,
                          child: IgnorePointer(
                            ignoring: _isReadOnly,
                            child: InkWell(
                              onTap: _pickDeliveryDate,
                              borderRadius: BorderRadius.circular(18),
                              child: InputDecorator(
                                isEmpty: _deliveryDate == null,
                                decoration: InputDecoration(
                                  labelText: _orderTableColumnLabel(
                                    context,
                                    l10n,
                                    'deliveryDate',
                                    en: 'Delivery date',
                                    he: 'תאריך משלוח',
                                    ar: 'تاريخ التسليم',
                                  ),
                                  labelStyle: GoogleFonts.assistant(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                                  floatingLabelStyle: GoogleFonts.assistant(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.secondary,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.local_shipping_outlined,
                                    color: AppTheme.secondary,
                                    size: 22,
                                  ),
                                  suffixIcon: _deliveryDate != null &&
                                          !_isReadOnly
                                      ? IconButton(
                                          onPressed: () => setState(
                                            () => _deliveryDate = null,
                                          ),
                                          icon: Icon(
                                            Icons.close_rounded,
                                            size: 20,
                                            color: AppTheme.onSurfaceVariant
                                                .withValues(alpha: 0.7),
                                          ),
                                          tooltip:
                                              MaterialLocalizations.of(context)
                                                  .deleteButtonTooltip,
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: AppTheme.surfaceContainerHighest
                                      .withValues(alpha: 0.55),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide(
                                      color: AppTheme.outlineVariant
                                          .withValues(alpha: 0.22),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide(
                                      color: AppTheme.outlineVariant
                                          .withValues(alpha: 0.22),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: const BorderSide(
                                      color: AppTheme.secondary,
                                      width: 1.8,
                                    ),
                                  ),
                                  hintText: _deliveryDate == null
                                      ? _orderTableColumnLabel(
                                          context,
                                          l10n,
                                          'selectDate',
                                          en: 'Select date',
                                          he: 'בחר תאריך',
                                          ar: 'اختر التاريخ',
                                        )
                                      : null,
                                  hintStyle: GoogleFonts.assistant(
                                    fontSize: 15,
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(
                                  _deliveryDate == null
                                      ? ''
                                      : _deliveryDate!
                                          .toString()
                                          .split(' ')
                                          .first,
                                  style: GoogleFonts.assistant(
                                    fontSize: 15,
                                    color: AppTheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Builder(
                          builder: (context) {
                            final pill = _orderSaveStatusPill(context, l10n);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: pill.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: pill.color.withValues(alpha: 0.18),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    pill.icon,
                                    size: 18,
                                    color: pill.color,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    pill.label,
                                    style: GoogleFonts.assistant(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: pill.color,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _isReadOnly
                              ? null
                              : () => setState(() {
                                    _markDirty();
                                    _items.add(_ItemRow());
                                  }),
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(l10n?.tr('addItem') ?? 'Add Item'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.outlineVariant.withValues(alpha: 0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Scrollbar(
                              controller: _itemsTableHorizontalScrollCtrl,
                              thumbVisibility: true,
                              interactive: true,
                              child: SingleChildScrollView(
                                controller: _itemsTableHorizontalScrollCtrl,
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsetsDirectional.only(
                                  start: 16,
                                  end: 16,
                                  top: 10,
                                  bottom: 16,
                                ),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: (constraints.maxWidth - 32)
                                        .clamp(0.0, double.infinity),
                                  ),
                                  child: roomsAsync.when(
                                    data: (rooms) => suppliersAsync.when(
                                      data: (suppliers) => _buildItemsTable(
                                        context,
                                        l10n,
                                        rooms,
                                        suppliers,
                                        readOnly: _isReadOnly,
                                      ),
                                      loading: () => const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(24),
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                      error: (_, __) => const Text('Error'),
                                    ),
                                    loading: () => const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(24),
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                    error: (_, __) => const Text('Error'),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            _buildOrderBottomDrawer(context, l10n),
          ],
        ),
      ),
    );
  }

  /// Collapsible bottom panel: peek shows tops of notes + totals; expanded fills height.
  Widget _buildOrderBottomDrawer(
    BuildContext context,
    AppLocalizations? l10n,
  ) {
    final media = MediaQuery.sizeOf(context);
    // Very compact drawer (~24% height) with a slightly higher cap
    // so the bottom actions (Save + Send) don't overflow.
    final expandedContentH = (media.height * 0.24).clamp(180.0, 292.0);
    const peekContentH = 52.0;
    final range = expandedContentH - peekContentH;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.14),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 6),
          child: AnimatedBuilder(
            animation: _bottomDrawerController,
            builder: (context, _) {
              final t = Curves.easeInOutCubic.transform(
                _bottomDrawerController.value,
              );
              final contentH = lerpDouble(peekContentH, expandedContentH, t)!;
              final drawerOpen = _bottomDrawerController.value > 0.5;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (details) {
                        if (range <= 0) return;
                        _bottomDrawerController.value =
                            (_bottomDrawerController.value -
                                    details.delta.dy / range)
                                .clamp(0.0, 1.0);
                      },
                      onVerticalDragEnd: (details) {
                        final v = details.velocity.pixelsPerSecond.dy;
                        if (v < -240) {
                          _bottomDrawerController.forward();
                        } else if (v > 240) {
                          _bottomDrawerController.reverse();
                        } else if (_bottomDrawerController.value > 0.5) {
                          _bottomDrawerController.forward();
                        } else {
                          _bottomDrawerController.reverse();
                        }
                      },
                      onTap: () {
                        if (_bottomDrawerController.value < 0.5) {
                          _bottomDrawerController.forward();
                        } else {
                          _bottomDrawerController.reverse();
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 0),
                            child: Center(
                              child: Container(
                                width: 36,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppTheme.outlineVariant
                                      .withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                          Icon(
                            drawerOpen
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.keyboard_arrow_up_rounded,
                            size: 22,
                            color: AppTheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 2),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: contentH,
                    child: ClipRect(
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                          child: SizedBox(
                            height: expandedContentH,
                            child: _buildOrderBottomBar(
                              context,
                              l10n,
                              stretchForDrawer: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Notes (gray) + totals/VAT/save (black). Drawer mode uses fixed height + stretched notes.
  Widget _buildOrderBottomBar(
    BuildContext context,
    AppLocalizations? l10n, {
    bool stretchForDrawer = false,
  }) {
    final notesCard = _buildOrderNotesBottomCard(
      context,
      l10n,
      expands: stretchForDrawer,
    );
    final summaryCard = _buildOrderSummaryBottomCard(
      context,
      l10n,
      fillVertical: stretchForDrawer,
    );

    if (stretchForDrawer) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: notesCard),
          const SizedBox(width: 10),
          Expanded(child: summaryCard),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 760;
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              summaryCard,
              const SizedBox(height: 16),
              notesCard,
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: notesCard),
              const SizedBox(width: 20),
              Expanded(child: summaryCard),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderNotesBottomCard(
    BuildContext context,
    AppLocalizations? l10n, {
    bool expands = false,
  }) {
    final decoration = InputDecoration(
      labelText: _orderTableColumnLabel(
        context,
        l10n,
        'orderNotesTitle',
        en: 'Order notes',
        he: 'הערות להזמנה',
        ar: 'ملاحظات الطلب',
      ),
      labelStyle: GoogleFonts.assistant(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppTheme.onSurfaceVariant,
      ),
      floatingLabelStyle: GoogleFonts.assistant(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppTheme.secondary,
      ),
      hintText: _orderTableColumnLabel(
        context,
        l10n,
        'orderNotesHint',
        en: 'Internal notes, delivery details…',
        he: 'הערות פנימיות, אספקה…',
        ar: 'ملاحظات داخلية، التسليم…',
      ),
      hintStyle: GoogleFonts.assistant(
        color: AppTheme.onSurfaceVariant.withValues(alpha: 0.55),
        fontSize: 14,
      ),
      alignLabelWithHint: true,
      filled: true,
      fillColor: AppTheme.surfaceContainerLowest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: AppTheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: AppTheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: AppTheme.secondary,
          width: 1.8,
        ),
      ),
      contentPadding: EdgeInsets.all(expands ? 8 : 16),
    );

    final field = TextField(
      controller: _notesController,
      expands: expands,
      enabled: !_isReadOnly,
      minLines: expands ? null : 5,
      maxLines: expands ? null : 8,
      textAlignVertical: expands ? TextAlignVertical.top : null,
      style: GoogleFonts.assistant(
        fontSize: 15,
        color: AppTheme.onSurface,
        height: 1.4,
      ),
      decoration: decoration,
    );

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
      padding: EdgeInsets.all(expands ? 8 : 20),
      child: expands ? SizedBox.expand(child: field) : field,
    );
  }

  Widget _buildOrderSummaryBottomCard(
    BuildContext context,
    AppLocalizations? l10n, {
    bool fillVertical = false,
  }) {
    final subtle = AppTheme.onPrimary.withValues(alpha: 0.72);
    final sub = _subtotalExVat;
    final vat = _vatAmount;
    final grand = _grandTotalWithVat;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: fillVertical
          ? const EdgeInsets.fromLTRB(16, 8, 16, 8)
          : const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  _orderTableColumnLabel(
                    context,
                    l10n,
                    'totalBeforeVat',
                    en: 'Total before VAT',
                    he: 'סה"כ לפני מע"מ',
                    ar: 'الإجمالي قبل الضريبة',
                  ),
                  style: GoogleFonts.assistant(
                    fontSize: fillVertical ? 12 : 14,
                    fontWeight: FontWeight.w600,
                    color: subtle,
                  ),
                ),
              ),
              Text(
                '₪${sub.toStringAsFixed(2)}',
                style: GoogleFonts.assistant(
                  fontSize: fillVertical ? 12 : 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: fillVertical ? 4 : 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  _orderTableColumnLabel(
                    context,
                    l10n,
                    'vatWithRate',
                    en: 'VAT (18%)',
                    he: 'מע"מ (18%)',
                    ar: 'ضريبة القيمة المضافة (18٪)',
                  ),
                  style: GoogleFonts.assistant(
                    fontSize: fillVertical ? 12 : 14,
                    fontWeight: FontWeight.w600,
                    color: subtle,
                  ),
                ),
              ),
              Text(
                '₪${vat.toStringAsFixed(2)}',
                style: GoogleFonts.assistant(
                  fontSize: fillVertical ? 12 : 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: fillVertical ? 5 : 20),
          Divider(
            height: 1,
            color: AppTheme.onPrimary.withValues(alpha: 0.2),
          ),
          SizedBox(height: fillVertical ? 5 : 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _orderTableColumnLabel(
                        context,
                        l10n,
                        'totalToPay',
                        en: 'Total to pay',
                        he: 'סה"כ לתשלום',
                        ar: 'الإجمالي للدفع',
                      ),
                      style: GoogleFonts.assistant(
                        fontSize: fillVertical ? 15 : 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onPrimary,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: fillVertical ? 0 : 4),
                    Text(
                      _orderTableColumnLabel(
                        context,
                        l10n,
                        'includesEverything',
                        en: 'Includes everything',
                        he: 'כולל הכל',
                        ar: 'شامل كل شيء',
                      ),
                      style: GoogleFonts.assistant(
                        fontSize: fillVertical ? 10 : 12,
                        fontWeight: FontWeight.w500,
                        color: subtle,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '₪${grand.toStringAsFixed(2)}',
                style: GoogleFonts.assistant(
                  fontSize: fillVertical ? 19 : 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: fillVertical ? 8 : 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isLoading || _isReadOnly ? null : _saveOrder,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: AppTheme.onSecondary,
                disabledBackgroundColor:
                    AppTheme.secondary.withValues(alpha: 0.5),
                padding: EdgeInsets.symmetric(
                  vertical: fillVertical ? 8 : 16,
                  horizontal: fillVertical ? 12 : 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                _orderTableColumnLabel(
                  context,
                  l10n,
                  'saveOrder',
                  en: 'Save order',
                  he: 'שמור הזמנה',
                  ar: 'حفظ الطلب',
                ),
                style: GoogleFonts.assistant(
                  fontSize: fillVertical ? 15 : 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (!_waitingSupplierConfirmation) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (_isLoading || !_canSendToSupplier)
                    ? null
                    : _sendOrderToSuppliers,
                icon: Icon(
                  Icons.send_rounded,
                  size: 18,
                  color: _canSendToSupplier
                      ? AppTheme.onPrimary
                      : AppTheme.onPrimary.withValues(alpha: 0.45),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _canSendToSupplier
                      ? AppTheme.onPrimary
                      : AppTheme.onPrimary.withValues(alpha: 0.45),
                  side: BorderSide(
                    color: AppTheme.secondary.withValues(
                      alpha: _canSendToSupplier ? 0.95 : 0.4,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: fillVertical ? 7 : 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                label: Text(
                  _orderTableColumnLabel(
                    context,
                    l10n,
                    'sendToSupplier',
                    en: 'Send to supplier',
                    he: 'שלח לספק',
                    ar: 'إرسال إلى المورد',
                  ),
                  style: GoogleFonts.assistant(
                    fontSize: fillVertical ? 14 : 15,
                    fontWeight: FontWeight.w800,
                    color: _canSendToSupplier
                        ? null
                        : AppTheme.onPrimary.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
          ],
          if (_waitingSupplierConfirmation) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _cancelSupplierWaitingOrder,
                icon: const Icon(Icons.cancel_rounded, size: 18),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  side:
                      BorderSide(color: AppTheme.error.withValues(alpha: 0.75)),
                  padding: EdgeInsets.symmetric(
                    vertical: fillVertical ? 7 : 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                label: Text(
                  l10n?.tr('cancel') ?? 'Cancel',
                  style: GoogleFonts.assistant(
                    fontSize: fillVertical ? 14 : 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Resolves ARB labels; if the bundle is stale and returns the key, use locale fallbacks.
  String _orderTableColumnLabel(
    BuildContext context,
    AppLocalizations? l10n,
    String key, {
    required String en,
    required String he,
    required String ar,
  }) {
    final t = l10n?.tr(key) ?? '';
    if (t.isNotEmpty && t != key) return t;
    return switch (Localizations.localeOf(context).languageCode) {
      'he' => he,
      'ar' => ar,
      _ => en,
    };
  }

  Widget _orderTableHeader(
    BuildContext context,
    AppLocalizations? l10n,
    String key, {
    required String en,
    required String he,
    required String ar,
  }) {
    final label =
        _orderTableColumnLabel(context, l10n, key, en: en, he: he, ar: ar);
    return Text(
      label,
      style: GoogleFonts.assistant(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: AppTheme.onSurfaceVariant,
        letterSpacing: 0.15,
        height: 1.2,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildItemsTable(BuildContext context, AppLocalizations? l10n,
      List<Room> rooms, List<Supplier> suppliers,
      {bool readOnly = false}) {
    final cellStyle = GoogleFonts.assistant(
      color: AppTheme.onSurface,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    );
    final lineTotalDecoration = BoxDecoration(
      color: AppTheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: AppTheme.outlineVariant.withValues(alpha: 0.22),
      ),
    );

    final headerTopRadius = BorderRadiusDirectional.only(
      topStart: const Radius.circular(20),
      topEnd: const Radius.circular(20),
    ).resolve(Directionality.of(context));

    return ClipRRect(
      borderRadius: headerTopRadius,
      clipBehavior: Clip.antiAlias,
      child: DataTable(
        headingRowHeight: 56,
        dataRowMinHeight: 56,
        dataRowMaxHeight: 84,
        columnSpacing: 12,
        headingRowColor: WidgetStateProperty.all(
          AppTheme.surfaceContainerHighest.withValues(alpha: 0.35),
        ),
        columns: [
          DataColumn(
            label: Text(
              '#',
              style: GoogleFonts.assistant(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ),
          DataColumn(
            label: _orderTableHeader(
              context,
              l10n,
              'orderFormTableProductCode',
              en: 'Product code',
              he: 'קוד גוף',
              ar: 'رمز المنتج',
            ),
          ),
          DataColumn(
            label: _orderTableHeader(
              context,
              l10n,
              'orderFormTableItemName',
              en: 'Item name',
              he: 'שם גוף',
              ar: 'اسم الصنف',
            ),
          ),
          DataColumn(
            label: _orderTableHeader(
              context,
              l10n,
              'image',
              en: 'Image',
              he: 'תמונה',
              ar: 'صورة',
            ),
          ),
          DataColumn(
            label: _orderTableHeader(
              context,
              l10n,
              'quantity',
              en: 'Qty',
              he: 'כמות',
              ar: 'الكمية',
            ),
          ),
          DataColumn(
            label: _orderTableHeader(
              context,
              l10n,
              'unitPrice',
              en: 'Unit price',
              he: 'מחיר ליחידה',
              ar: 'سعر الوحدة',
            ),
          ),
          DataColumn(
            label: _orderTableHeader(
              context,
              l10n,
              'extras',
              en: 'Extras',
              he: 'תוספות',
              ar: 'إضافات',
            ),
          ),
          DataColumn(
            label: _orderTableHeader(
              context,
              l10n,
              'extrasPrice',
              en: 'Add-ons price',
              he: 'מחיר תוספות',
              ar: 'سعر الإضافات',
            ),
          ),
          DataColumn(
            label: _orderTableHeader(
              context,
              l10n,
              'assemblyRequired',
              en: 'Assembly',
              he: 'דרוש הרכבה',
              ar: 'التجميع',
            ),
          ),
          DataColumn(
            label: _orderTableHeader(
              context,
              l10n,
              'warranty',
              en: 'Warranty',
              he: 'אחריות',
              ar: 'الضمان',
            ),
          ),
          DataColumn(
            label: _orderTableHeader(
              context,
              l10n,
              'room',
              en: 'Room',
              he: 'חדר',
              ar: 'الغرفة',
            ),
          ),
          DataColumn(
            label: _orderTableHeader(
              context,
              l10n,
              'supplier',
              en: 'Supplier',
              he: 'ספק',
              ar: 'المورد',
            ),
          ),
          DataColumn(
            label: _orderTableHeader(
              context,
              l10n,
              'lineTotal',
              en: 'Line total',
              he: 'סה"כ שורה',
              ar: 'إجمالي السطر',
            ),
          ),
          const DataColumn(label: SizedBox.shrink()),
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
              DataCell(
                SizedBox(
                  width: 108,
                  child: TextField(
                    controller: item.itemNumberCtrl,
                    enabled: !readOnly,
                    decoration: orderTableCellDecoration(),
                    style: cellStyle,
                  ),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 148,
                  child: TextField(
                    controller: item.nameCtrl,
                    enabled: !readOnly,
                    decoration: orderTableCellDecoration(),
                    style: cellStyle,
                  ),
                ),
              ),
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
                  onPressed: readOnly
                      ? null
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Camera/Gallery - requires device'),
                            ),
                          );
                        },
                ),
              ),
              DataCell(
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: item.quantityCtrl,
                    keyboardType: TextInputType.text,
                    enabled: !readOnly,
                    onChanged: (_) {
                      _markDirty();
                      setState(() {});
                    },
                    decoration: orderTableCellDecoration(),
                    style: cellStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: item.priceCtrl,
                    keyboardType: TextInputType.text,
                    enabled: !readOnly,
                    onChanged: (_) {
                      _markDirty();
                      setState(() {});
                    },
                    decoration: orderTableCellDecoration(),
                    style: cellStyle,
                  ),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: item.extrasCtrl,
                    enabled: !readOnly,
                    onChanged: (_) {
                      _markDirty();
                      setState(() {});
                    },
                    decoration: orderTableCellDecoration(),
                    style: cellStyle,
                  ),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: item.extrasPriceCtrl,
                    keyboardType: TextInputType.text,
                    enabled: !readOnly,
                    onChanged: (_) {
                      _markDirty();
                      setState(() {});
                    },
                    decoration: orderTableCellDecoration(),
                    style: cellStyle,
                  ),
                ),
              ),
              DataCell(
                AppAnimatedSquareCheckbox(
                  value: item.assemblyRequired,
                  onChanged: readOnly
                      ? null
                      : (v) => setState(() {
                            _markDirty();
                            final next = v ?? false;
                            item.assemblyRequired = next;
                            if (next && !_assemblyRequired) {
                              _assemblyRequired = true;
                            }
                          }),
                  activeColor: AppTheme.secondary,
                ),
              ),
              DataCell(
                SizedBox(
                  width: 124,
                  child: DropdownMenu<int>(
                    key: ValueKey('of_warranty_${index}_${item.warrantyYears}'),
                    enabled: !readOnly,
                    initialSelection:
                        item.warrantyYears == 3 || item.warrantyYears == 5
                            ? item.warrantyYears
                            : 0,
                    width: 124,
                    selectOnly: true,
                    enableFilter: false,
                    enableSearch: false,
                    menuStyle: appDropdownMenuStyle(),
                    inputDecorationTheme: appDropdownInputDecorationTheme(),
                    decorationBuilder: animatedDropdownDecorationBuilder(
                      label: Text(
                        _orderTableColumnLabel(
                          context,
                          l10n,
                          'warranty',
                          en: 'Warranty',
                          he: 'אחריות',
                          ar: 'الضمان',
                        ),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      iconSize: 18,
                    ),
                    textStyle: cellStyle.copyWith(fontSize: 12),
                    onSelected: (v) => setState(() {
                      _markDirty();
                      item.warrantyYears = v ?? 0;
                    }),
                    dropdownMenuEntries: [
                      DropdownMenuEntry<int>(
                        value: 0,
                        label: _orderTableColumnLabel(
                          context,
                          l10n,
                          'warrantyNone',
                          en: 'No warranty',
                          he: 'ללא אחריות',
                          ar: 'بدون ضمان',
                        ),
                      ),
                      DropdownMenuEntry<int>(
                        value: 3,
                        label: _orderTableColumnLabel(
                          context,
                          l10n,
                          'warranty3Years',
                          en: '3 years',
                          he: '3 שנים',
                          ar: '3 سنوات',
                        ),
                      ),
                      DropdownMenuEntry<int>(
                        value: 5,
                        label: _orderTableColumnLabel(
                          context,
                          l10n,
                          'warranty5Years',
                          en: '5 years',
                          he: '5 שנים',
                          ar: '5 سنوات',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 128,
                  child: DropdownMenu<String?>(
                    key: ValueKey(
                      'of_room_${index}_${item.roomId}_${rooms.length}',
                    ),
                    enabled: !readOnly,
                    initialSelection: item.roomId,
                    width: 128,
                    selectOnly: true,
                    enableFilter: false,
                    enableSearch: false,
                    menuStyle: appDropdownMenuStyle(),
                    inputDecorationTheme: appDropdownInputDecorationTheme(),
                    decorationBuilder: animatedDropdownDecorationBuilder(
                      label: Text(
                        l10n?.tr('room') ?? 'Room',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      iconSize: 18,
                    ),
                    textStyle: cellStyle.copyWith(fontSize: 12),
                    onSelected: (v) => setState(() {
                      _markDirty();
                      item.roomId = v;
                    }),
                    dropdownMenuEntries: [
                      const DropdownMenuEntry<String?>(
                        value: null,
                        label: '—',
                      ),
                      ...rooms.map(
                        (r) => DropdownMenuEntry<String?>(
                          value: r.id,
                          label: r.name,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 148,
                  child: DropdownMenu<String?>(
                    key: ValueKey(
                      'of_sup_${index}_${item.supplierId}_${suppliers.length}',
                    ),
                    enabled: !readOnly,
                    initialSelection: item.supplierId,
                    width: 148,
                    selectOnly: true,
                    enableFilter: false,
                    enableSearch: false,
                    menuStyle: appDropdownMenuStyle(),
                    inputDecorationTheme: appDropdownInputDecorationTheme(),
                    decorationBuilder: animatedDropdownDecorationBuilder(
                      label: Text(
                        l10n?.tr('supplier') ?? 'Supplier',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      iconSize: 18,
                    ),
                    textStyle: cellStyle.copyWith(fontSize: 12),
                    onSelected: (v) => setState(() {
                      _markDirty();
                      item.supplierId = v;
                    }),
                    dropdownMenuEntries: [
                      const DropdownMenuEntry<String?>(
                        value: null,
                        label: '—',
                      ),
                      ...suppliers.map(
                        (s) => DropdownMenuEntry<String?>(
                          value: s.id,
                          label: s.companyName,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              DataCell(
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: lineTotalDecoration,
                  child: Text(
                    '₪${_lineTotal(item).toStringAsFixed(0)}',
                    style: GoogleFonts.assistant(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface,
                    ),
                  ),
                ),
              ),
              DataCell(
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppTheme.error,
                    size: 20,
                  ),
                  onPressed: readOnly
                      ? null
                      : () {
                          if (_items.length > 1) {
                            setState(() => _items.removeAt(index));
                          }
                        },
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Future<void> _saveOrder() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a customer')));
      return;
    }

    if (_isReadOnly) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Order is locked. Only cancel is allowed.')),
      );
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
              notes: null,
              price: double.tryParse(item.priceCtrl.text) ?? 0,
              extrasPrice: double.tryParse(item.extrasPriceCtrl.text) ?? 0,
              assemblyRequired: item.assemblyRequired,
              roomId: item.roomId,
              supplierId: item.supplierId,
              existingInStore: item.existingInStore,
              warrantyYears: item.warrantyYears,
              createdBy: username,
              updatedBy: username,
            ),
          )
          .toList();

      if (_isEdit && _existingOrder != null) {
        // Update existing order
        final updatedOrder = await ref.read(orderServiceProvider).update(
          _existingOrder!.id,
          {
            'customer_id': _selectedCustomer!.id,
            'assembly_required': _assemblyRequired,
            'assembly_date': _assemblyDate?.toIso8601String().split('T').first,
            'delivery_date': _deliveryDate?.toIso8601String().split('T').first,
            'assembly_price': _assemblyRequired ? _assemblyInstallPrice : 0,
            'total_price': _totalPrice,
            'notes': _notesController.text.trim(),
            'updated_by': username,
          },
        );
        await ref
            .read(orderServiceProvider)
            .updateItems(_existingOrder!.id, orderItems, username);

        _existingOrder = updatedOrder;
      } else {
        // Create new order
        final order = Order(
          id: '',
          customerId: _selectedCustomer!.id,
          assemblyRequired: _assemblyRequired,
          assemblyDate: _assemblyDate,
          deliveryDate: _deliveryDate,
          assemblyPrice: _assemblyRequired ? _assemblyInstallPrice : 0,
          totalPrice: _totalPrice,
          notes: _notesController.text.trim(),
          createdBy: username,
          updatedBy: username,
        );
        _existingOrder =
            await ref.read(orderServiceProvider).create(order, orderItems);
        _isEdit = true;
      }

      if (mounted) {
        setState(() => _hasUnsavedChanges = false);
      }
      ref.invalidate(ordersProvider);
      ref.invalidate(customersProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendOrderToSuppliers() async {
    if (_existingOrder == null) return;
    if (!_canSendToSupplier) return;

    setState(() => _isLoading = true);
    try {
      final username = ref.read(currentUsernameProvider);
      final suppliers = await ref.read(suppliersProvider.future);

      final Map<String, List<_ItemRow>> grouped = {};
      for (final item in _items) {
        final supplierId = item.supplierId;
        if (supplierId == null || supplierId.isEmpty) continue;
        grouped.putIfAbsent(supplierId, () => []).add(item);
      }

      if (grouped.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No suppliers selected for any product.',
              ),
            ),
          );
        }
        return;
      }

      // Send a WhatsApp message per supplier, with all that supplier's products.
      for (final entry in grouped.entries) {
        final supplier = suppliers.where((s) => s.id == entry.key).firstOrNull;
        if (supplier == null ||
            supplier.phone == null ||
            supplier.phone!.isEmpty) {
          continue;
        }

        final itemsText = entry.value.map((item) {
          final code = item.itemNumberCtrl.text.trim();
          final name = item.nameCtrl.text.trim();
          final qty = item.quantityCtrl.text.trim();
          return '($code)\n($name)\n($qty)';
        }).join('\n\n');

        final message = 'ניסוח לספקים\n$itemsText\n\nנא לאשר שקבלת';

        final phone = supplier.phone!.replaceAll(RegExp(r'[^\d+]'), '');
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

      // Lock order: disable editing until admin changes status after confirmation.
      await ref.read(orderServiceProvider).updateStatus(
            _existingOrder!.id,
            OrderStatus.sentToSupplier.dbValue,
            username,
          );

      setState(() {
        _existingOrder = _existingOrder!.copyWith(
          status: OrderStatus.sentToSupplier,
        );
      });

      ref.invalidate(ordersProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelSupplierWaitingOrder() async {
    if (_existingOrder == null) return;
    if (!_waitingSupplierConfirmation) return;

    setState(() => _isLoading = true);
    try {
      final username = ref.read(currentUsernameProvider);
      await ref.read(orderServiceProvider).cancelOrder(
            _existingOrder!.id,
            username,
          );

      setState(() {
        _existingOrder = _existingOrder!.copyWith(
          status: OrderStatus.canceled,
        );
      });

      ref.invalidate(ordersProvider);
      ref.invalidate(customersProvider);
      ref.invalidate(totalUnpaidDebtsProvider);
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

  @override
  void dispose() {
    _customerFocusNode.removeListener(_onCustomerFocusChange);
    _notesController.removeListener(_markDirty);
    _assemblyPriceController.removeListener(_markDirty);
    _notesController.dispose();
    _assemblyPriceController.dispose();
    _customerTextController.dispose();
    _customerFocusNode.dispose();
    _bottomDrawerController.dispose();
    _itemsTableHorizontalScrollCtrl.dispose();
    _hideCustomerDropdown();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }
}

/// Gold track + fixed-size thumb (same on/off); subtle scale pulse when turning on.
class _AssemblyGoldSwitch extends StatefulWidget {
  const _AssemblyGoldSwitch({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<_AssemblyGoldSwitch> createState() => _AssemblyGoldSwitchState();
}

class _AssemblyGoldSwitchState extends State<_AssemblyGoldSwitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _knobScale;

  static const double _trackW = 52;
  static const double _trackH = 32;
  static const double _knobSize = 24;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _knobScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.14)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 38,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.14, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 62,
      ),
    ]).animate(_pulse);
  }

  @override
  void didUpdateWidget(covariant _AssemblyGoldSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.value && widget.value) {
      _pulse.forward(from: 0);
    } else if (oldWidget.value && !widget.value) {
      _pulse.reset();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trackOn = AppTheme.secondaryContainer;
    final trackOff = AppTheme.surfaceContainerHighest;
    final borderOn = AppTheme.secondary.withValues(alpha: 0.42);
    final borderOff = AppTheme.outlineVariant.withValues(alpha: 0.65);

    return Semantics(
      toggled: widget.value,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onChanged(!widget.value),
          borderRadius: BorderRadius.circular(_trackH / 2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            width: _trackW,
            height: _trackH,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_trackH / 2),
              color: widget.value ? trackOn : trackOff,
              border: Border.all(
                color: widget.value ? borderOn : borderOff,
                width: 1,
              ),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment: widget.value
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  final scale = widget.value ? _knobScale.value : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: Container(
                  width: _knobSize,
                  height: _knobSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.surfaceContainerLowest,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemRow {
  final itemNumberCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final quantityCtrl = TextEditingController(text: '1');
  final extrasCtrl = TextEditingController();
  final priceCtrl = TextEditingController(text: '0');
  final extrasPriceCtrl = TextEditingController();
  bool assemblyRequired = false;
  String? roomId;
  String? supplierId;
  bool existingInStore = false;
  int warrantyYears = 0;
  String? imageUrl;

  void dispose() {
    itemNumberCtrl.dispose();
    nameCtrl.dispose();
    quantityCtrl.dispose();
    extrasCtrl.dispose();
    priceCtrl.dispose();
    extrasPriceCtrl.dispose();
  }
}
