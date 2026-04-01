import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/payment.dart';
import '../../models/customer.dart';
import '../../providers/providers.dart';
import '../../widgets/app_dropdown_styles.dart';
import '../../widgets/app_loading_overlay.dart';
import '../../widgets/editorial_screen_title.dart';

String _localizedPaymentType(AppLocalizations? l10n, PaymentType t) {
  switch (t) {
    case PaymentType.cash:
      return l10n?.tr('cash') ?? 'Cash';
    case PaymentType.credit:
      return l10n?.tr('credit') ?? 'Credit';
    case PaymentType.check:
      return l10n?.tr('check') ?? 'Check';
  }
}

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  final _searchCtrl = TextEditingController();
  final _amountMinCtrl = TextEditingController();
  final _amountMaxCtrl = TextEditingController();

  /// Empty string means all customers.
  String _customerFilterId = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  /// `all` | `cash` | `credit` | `check`
  String _typeFilterKey = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _amountMinCtrl.dispose();
    _amountMaxCtrl.dispose();
    super.dispose();
  }

  List<Payment> _filterPayments(
    List<Payment> payments,
    bool customerAlreadyScoped,
    AppLocalizations? l10n,
  ) {
    Iterable<Payment> it = payments;

    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      it = it.where((p) {
        final notes = p.notes ?? '';
        final user = p.createdBy ?? '';
        final typeLabel = _localizedPaymentType(l10n, p.type).toLowerCase();
        return p.cardName.toLowerCase().contains(q) ||
            p.customerName.toLowerCase().contains(q) ||
            notes.toLowerCase().contains(q) ||
            user.toLowerCase().contains(q) ||
            p.type.dbValue.toLowerCase().contains(q) ||
            typeLabel.contains(q) ||
            p.amount.toString().contains(q);
      });
    }

    if (!customerAlreadyScoped && _customerFilterId.isNotEmpty) {
      it = it.where((p) => p.customerId == _customerFilterId);
    }

    if (_dateFrom != null) {
      final from = DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day);
      it = it.where((p) {
        final d = DateTime(p.date.year, p.date.month, p.date.day);
        return !d.isBefore(from);
      });
    }
    if (_dateTo != null) {
      final to = DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day);
      it = it.where((p) {
        final d = DateTime(p.date.year, p.date.month, p.date.day);
        return !d.isAfter(to);
      });
    }

    final minAmt = double.tryParse(_amountMinCtrl.text.trim());
    if (minAmt != null) {
      it = it.where((p) => p.amount >= minAmt);
    }
    final maxAmt = double.tryParse(_amountMaxCtrl.text.trim());
    if (maxAmt != null) {
      it = it.where((p) => p.amount <= maxAmt);
    }

    if (_typeFilterKey != 'all') {
      final PaymentType? t = switch (_typeFilterKey) {
        'cash' => PaymentType.cash,
        'credit' => PaymentType.credit,
        'check' => PaymentType.check,
        _ => null,
      };
      if (t != null) {
        it = it.where((p) => p.type == t);
      }
    }

    return it.toList();
  }

  void _resetLocalFilters() {
    setState(() {
      _searchCtrl.clear();
      _amountMinCtrl.clear();
      _amountMaxCtrl.clear();
      _customerFilterId = '';
      _dateFrom = null;
      _dateTo = null;
      _typeFilterKey = 'all';
    });
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom ? _dateFrom : _dateTo;
    final picked = await showDatePicker(
      context: context,
      locale: Localizations.localeOf(context),
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
    }
  }

  String _formatDay(DateTime d) {
    final code = Localizations.localeOf(context).languageCode;
    return DateFormat.yMd(code).format(d);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filterCustomer = ref.watch(paymentsCustomerFilterProvider);
    final customersAsync = ref.watch(customersProvider);
    final customers = customersAsync.value ?? [];

    final AsyncValue<List<Payment>> paymentsAsync = filterCustomer != null
        ? ref.watch(customerPaymentsProvider(filterCustomer.id))
        : ref.watch(paymentsProvider(null));

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLowest,
      appBar: AppBar(
        toolbarHeight: 0,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.secondary,
        foregroundColor: AppTheme.onPrimary,
        elevation: 2,
        onPressed: () => showPaymentDialog(
          context,
          ref,
          l10n,
          initialCustomer: ref.read(paymentsCustomerFilterProvider),
        ),
        tooltip: l10n?.tr('newPayment') ?? 'New Payment',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EditorialScreenTitle(
            title: l10n?.tr('payments') ?? 'Payments',
          ),

          // Search & filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (filterCustomer != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      elevation: 0,
                      color: AppTheme.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(22),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_pin_circle_outlined,
                              size: 22,
                              color: AppTheme.secondary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${filterCustomer.cardName} — ${filterCustomer.customerName}',
                                style: GoogleFonts.assistant(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppTheme.onSurface,
                                ),
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () {
                                ref
                                    .read(
                                      paymentsCustomerFilterProvider.notifier,
                                    )
                                    .setFilter(null);
                              },
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: Text(
                                l10n?.tr('clearFilter') ?? 'Clear filter',
                                style: GoogleFonts.assistant(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    AppTheme.surfaceContainerLowest,
                                foregroundColor: AppTheme.secondary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (filterCustomer != null) const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Material(
                        elevation: 2,
                        shadowColor: Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() {}),
                          style:
                              GoogleFonts.assistant(color: AppTheme.onSurface),
                          decoration: InputDecoration(
                            floatingLabelBehavior: FloatingLabelBehavior.auto,
                            floatingLabelAlignment:
                                FloatingLabelAlignment.start,
                            labelText: l10n?.tr('searchPaymentsHint') ??
                                'Search payments…',
                            labelStyle: GoogleFonts.assistant(
                              color: AppTheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            floatingLabelStyle: GoogleFonts.assistant(
                              color: AppTheme.secondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: AppTheme.secondary,
                            ),
                            filled: true,
                            fillColor: AppTheme.surfaceContainerLowest,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: AppTheme.outlineVariant
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: AppTheme.outlineVariant
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(
                                color: AppTheme.secondary,
                                width: 1.6,
                              ),
                            ),
                            contentPadding: const EdgeInsets.fromLTRB(
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
                      onPressed: _resetLocalFilters,
                      icon: const Icon(Icons.restart_alt_rounded, size: 22),
                      label: Text(
                        l10n?.tr('resetFilters') ?? 'Reset filters',
                        style: GoogleFonts.assistant(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        backgroundColor:
                            AppTheme.secondaryContainer.withValues(alpha: 0.45),
                        foregroundColor: AppTheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Theme(
                  data: Theme.of(context).copyWith(
                    inputDecorationTheme: paymentsFilterInputDecorationTheme(),
                  ),
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (filterCustomer == null)
                        SizedBox(
                          width: 300,
                          height: paymentsFilterControlHeight,
                          child: Center(
                            child: DropdownMenu<String>(
                              key: ValueKey(
                                'cust_${_customerFilterId}_${customers.length}',
                              ),
                              initialSelection: _customerFilterId,
                              width: 300,
                              enableFilter: true,
                              requestFocusOnTap: true,
                              leadingIcon: dropdownLeadingSlot(
                                Icon(
                                  Icons.groups_2_rounded,
                                  size: 18,
                                  color: AppTheme.secondary,
                                ),
                              ),
                              label: Text(
                                l10n?.tr('filterCustomer') ?? 'Customer',
                                style: GoogleFonts.assistant(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              hintText: l10n?.tr('all') ?? 'All',
                              menuStyle: appDropdownMenuStyle(),
                              inputDecorationTheme:
                                  paymentsFilterInputDecorationTheme(),
                              textStyle: GoogleFonts.assistant(
                                color: AppTheme.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              trailingIcon: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppTheme.secondary,
                              ),
                              selectedTrailingIcon: Icon(
                                Icons.keyboard_arrow_up_rounded,
                                color: AppTheme.secondary,
                              ),
                              onSelected: (v) =>
                                  setState(() => _customerFilterId = v ?? ''),
                              dropdownMenuEntries: [
                                DropdownMenuEntry(
                                  value: '',
                                  label: l10n?.tr('all') ?? 'All',
                                ),
                                ...customers.map(
                                  (c) => DropdownMenuEntry(
                                    value: c.id,
                                    label: '${c.cardName} — ${c.customerName}',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      FilledButton.tonalIcon(
                        onPressed: () => _pickDate(true),
                        icon: const Icon(Icons.date_range_rounded, size: 20),
                        label: Text(
                          _dateFrom != null
                              ? _formatDay(_dateFrom!)
                              : (l10n?.tr('dateFrom') ?? 'From date'),
                          style: GoogleFonts.assistant(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.surfaceContainerLowest,
                          foregroundColor: AppTheme.onSurface,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: Size(
                            0,
                            paymentsFilterControlHeight,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                              color: AppTheme.outlineVariant
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _pickDate(false),
                        icon: const Icon(Icons.event_note_rounded, size: 20),
                        label: Text(
                          _dateTo != null
                              ? _formatDay(_dateTo!)
                              : (l10n?.tr('dateTo') ?? 'To date'),
                          style: GoogleFonts.assistant(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.surfaceContainerLowest,
                          foregroundColor: AppTheme.onSurface,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: Size(
                            0,
                            paymentsFilterControlHeight,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                              color: AppTheme.outlineVariant
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        height: paymentsFilterControlHeight,
                        child: Center(
                          child: TextField(
                            controller: _amountMinCtrl,
                            onChanged: (_) => setState(() {}),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: GoogleFonts.assistant(
                              color: AppTheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              labelText: l10n?.tr('amountMin') ?? 'Min ₪',
                              prefixText: '₪ ',
                              prefixStyle: GoogleFonts.assistant(
                                color: AppTheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ).applyDefaults(
                              Theme.of(context).inputDecorationTheme,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        height: paymentsFilterControlHeight,
                        child: Center(
                          child: TextField(
                            controller: _amountMaxCtrl,
                            onChanged: (_) => setState(() {}),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: GoogleFonts.assistant(
                              color: AppTheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              labelText: l10n?.tr('amountMax') ?? 'Max ₪',
                              prefixText: '₪ ',
                              prefixStyle: GoogleFonts.assistant(
                                color: AppTheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ).applyDefaults(
                              Theme.of(context).inputDecorationTheme,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 210,
                        height: paymentsFilterControlHeight,
                        child: Builder(
                          builder: (context) {
                            final typeLeading = dropdownLeadingSlot(
                              Icon(
                                Icons.category_rounded,
                                size: 18,
                                color: AppTheme.secondary,
                              ),
                            );
                            return Center(
                              child: DropdownMenu<String>(
                                key: ValueKey('type_$_typeFilterKey'),
                                initialSelection: _typeFilterKey,
                                width: 210,
                                selectOnly: true,
                                enableFilter: false,
                                enableSearch: false,
                                leadingIcon: typeLeading,
                                decorationBuilder:
                                    animatedDropdownDecorationBuilder(
                                  label: Text(
                                    l10n?.tr('type') ?? 'Type',
                                    style: GoogleFonts.assistant(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  leadingIcon: typeLeading,
                                ),
                                menuStyle: appDropdownMenuStyle(),
                                inputDecorationTheme:
                                    paymentsFilterInputDecorationTheme(),
                                textStyle: GoogleFonts.assistant(
                                  color: AppTheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                onSelected: (v) => setState(
                                  () => _typeFilterKey = v ?? 'all',
                                ),
                                dropdownMenuEntries: [
                                  DropdownMenuEntry(
                                    value: 'all',
                                    label: l10n?.tr('allPaymentTypes') ??
                                        'All types',
                                  ),
                                  DropdownMenuEntry(
                                    value: 'cash',
                                    label: l10n?.tr('cash') ?? 'Cash',
                                  ),
                                  DropdownMenuEntry(
                                    value: 'credit',
                                    label: l10n?.tr('credit') ?? 'Credit',
                                  ),
                                  DropdownMenuEntry(
                                    value: 'check',
                                    label: l10n?.tr('check') ?? 'Check',
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Table Area
          Expanded(
            child: paymentsAsync.when(
              data: (payments) {
                final scoped = filterCustomer != null;
                final filtered = _filterPayments(payments, scoped, l10n);

                if (payments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.payment_outlined,
                          size: 80,
                          color:
                              AppTheme.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n?.tr('noData') ?? 'No Data',
                          style: GoogleFonts.assistant(
                            color: AppTheme.onSurfaceVariant,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 80,
                          color:
                              AppTheme.onSurfaceVariant.withValues(alpha: 0.35),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n?.tr('noMatchingResults') ??
                              'No payments match your filters',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.assistant(
                            color: AppTheme.onSurfaceVariant,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Container(
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
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          AppTheme.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                        ),
                        headingRowHeight: 64,
                        dataRowMinHeight: 64,
                        dataRowMaxHeight: 72,
                        columnSpacing: 24,
                        dividerThickness: 0.5,
                        columns: [
                          _buildColumnHeader(l10n?.tr('date') ?? 'Date'),
                          _buildColumnHeader(l10n?.tr('type') ?? 'Type'),
                          _buildColumnHeader(
                              l10n?.tr('cardName') ?? 'Card Name'),
                          _buildColumnHeader(
                              l10n?.tr('customerName') ?? 'Customer'),
                          _buildColumnHeader(l10n?.tr('amount') ?? 'Amount'),
                          _buildColumnHeader(l10n?.tr('image') ?? 'Receipt'),
                          _buildColumnHeader(l10n?.tr('notes') ?? 'Notes'),
                          _buildColumnHeader(l10n?.tr('username') ?? 'User'),
                        ],
                        rows: filtered.map((payment) {
                          IconData typeIcon;
                          Color typeColor;
                          switch (payment.type) {
                            case PaymentType.cash:
                              typeIcon = Icons.money;
                              typeColor = AppTheme.success;
                              break;
                            case PaymentType.credit:
                              typeIcon = Icons.credit_card;
                              typeColor = AppTheme.secondary;
                              break;
                            case PaymentType.check:
                              typeIcon = Icons.description;
                              typeColor = AppTheme.warning;
                              break;
                          }

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  payment.date.toString().split(' ').first,
                                  style: GoogleFonts.assistant(
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.onSurface,
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: typeColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(typeIcon,
                                          size: 16, color: typeColor),
                                      const SizedBox(width: 8),
                                      Text(
                                        _localizedPaymentType(
                                          l10n,
                                          payment.type,
                                        ),
                                        style: GoogleFonts.assistant(
                                          color: typeColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  payment.cardName,
                                  style: GoogleFonts.assistant(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.onSurface,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  payment.customerName,
                                  style: GoogleFonts.assistant(
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '₪${payment.amount.toStringAsFixed(0)}',
                                  style: GoogleFonts.assistant(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.secondary,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              DataCell(
                                _PaymentReceiptTableCell(
                                  imageUrl: payment.imageUrl,
                                  l10n: l10n,
                                ),
                              ),
                              DataCell(
                                Text(
                                  payment.notes ?? '-',
                                  style: GoogleFonts.assistant(
                                      color: AppTheme.onSurfaceVariant),
                                ),
                              ),
                              DataCell(
                                Text(
                                  payment.createdBy ?? '-',
                                  style: GoogleFonts.assistant(
                                      color: AppTheme.onSurfaceVariant),
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
              loading: () => const AppLoadingOverlay(
                isLoading: true,
                child: SizedBox.expand(),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Error: $e',
                  style: GoogleFonts.assistant(color: AppTheme.error),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataColumn _buildColumnHeader(String label) {
    return DataColumn(
      label: Text(
        label,
        style: GoogleFonts.assistant(
          fontWeight: FontWeight.w700,
          color: AppTheme.onSurfaceVariant,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _PaymentReceiptTableCell extends StatelessWidget {
  const _PaymentReceiptTableCell({
    required this.imageUrl,
    required this.l10n,
  });

  final String? imageUrl;
  final AppLocalizations? l10n;

  Future<void> _openUrl() async {
    final uri = Uri.tryParse(imageUrl ?? '');
    if (uri == null || !uri.hasScheme) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Icon(
        Icons.remove,
        color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4),
        size: 20,
      );
    }
    return Tooltip(
      message: l10n?.tr('receipt') ?? 'Receipt',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _openUrl,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: imageUrl!,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              placeholder: (_, __) => SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.secondary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Icon(
                Icons.receipt_long_rounded,
                color: AppTheme.success,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showPaymentDialog(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations? l10n, {
  Customer? initialCustomer,
}) {
  final customersAsync = ref.read(customersProvider);
  final customers = customersAsync.value ?? [];

  Customer? selectedCustomer = initialCustomer;
  PaymentType selectedType = PaymentType.cash;
  final amountCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  Uint8List? receiptImageBytes;
  var isSaving = false;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        Future<void> pickReceipt(ImageSource source) async {
          final picker = ImagePicker();
          final xFile = await picker.pickImage(
            source: source,
            maxWidth: 1600,
            maxHeight: 1600,
            imageQuality: 88,
          );
          if (xFile == null) return;
          final bytes = await xFile.readAsBytes();
          setDialogState(() => receiptImageBytes = bytes);
        }

        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: AppTheme.surfaceContainerLowest,
          elevation: 8,
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n?.tr('newPayment') ?? 'New Payment',
                    style: GoogleFonts.assistant(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: DropdownMenu<Customer>(
                      key: ValueKey(selectedCustomer?.id ?? 'none'),
                      initialSelection: selectedCustomer,
                      enabled: initialCustomer == null,
                      width: 436,
                      enableFilter: true,
                      requestFocusOnTap: true,
                      leadingIcon: dropdownLeadingSlot(
                        Icon(
                          Icons.person_rounded,
                          size: 18,
                          color: AppTheme.secondary,
                        ),
                      ),
                      label: Text(
                        l10n?.tr('customerName') ?? 'Customer',
                        style: GoogleFonts.assistant(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      menuStyle: appDropdownMenuStyle(),
                      inputDecorationTheme: appDropdownInputDecorationTheme(),
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
                      onSelected: initialCustomer != null
                          ? null
                          : (c) => setDialogState(() => selectedCustomer = c),
                      dropdownMenuEntries: customers
                          .map(
                            (c) => DropdownMenuEntry<Customer>(
                              value: c,
                              label: '${c.cardName} — ${c.customerName}',
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: Builder(
                      builder: (context) {
                        final dialogTypeLeading = dropdownLeadingSlot(
                          Icon(
                            Icons.payments_rounded,
                            size: 18,
                            color: AppTheme.secondary,
                          ),
                        );
                        return DropdownMenu<PaymentType>(
                          key: ValueKey(selectedType.name),
                          initialSelection: selectedType,
                          width: 436,
                          selectOnly: true,
                          enableFilter: false,
                          enableSearch: false,
                          leadingIcon: dialogTypeLeading,
                          decorationBuilder: animatedDropdownDecorationBuilder(
                            label: Text(
                              l10n?.tr('type') ?? 'Type',
                              style: GoogleFonts.assistant(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            leadingIcon: dialogTypeLeading,
                          ),
                          menuStyle: appDropdownMenuStyle(),
                          inputDecorationTheme:
                              appDropdownInputDecorationTheme(),
                          textStyle: GoogleFonts.assistant(
                            color: AppTheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (v) => setDialogState(
                            () => selectedType = v ?? PaymentType.cash,
                          ),
                          dropdownMenuEntries: PaymentType.values
                              .map(
                                (t) => DropdownMenuEntry<PaymentType>(
                                  value: t,
                                  label: _localizedPaymentType(l10n, t),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Amount
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: InputDecoration(
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                      floatingLabelAlignment: FloatingLabelAlignment.start,
                      labelText: l10n?.tr('amount') ?? 'Amount',
                      labelStyle:
                          const TextStyle(color: AppTheme.onSurfaceVariant),
                      floatingLabelStyle: const TextStyle(
                        color: AppTheme.secondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      prefixIcon: const Icon(Icons.attach_money,
                          color: AppTheme.onSurfaceVariant),
                      filled: true,
                      fillColor: AppTheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color:
                              AppTheme.outlineVariant.withValues(alpha: 0.35),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color:
                              AppTheme.outlineVariant.withValues(alpha: 0.35),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.secondary,
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n?.tr('receipt') ?? 'Receipt',
                    style: GoogleFonts.assistant(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 18,
                          ),
                          side: BorderSide(
                            color:
                                AppTheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          foregroundColor: AppTheme.onSurfaceVariant,
                        ),
                        onPressed: isSaving
                            ? null
                            : () => pickReceipt(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined, size: 20),
                        label: Text(l10n?.tr('takePhoto') ?? 'Take Photo'),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 18,
                          ),
                          side: BorderSide(
                            color:
                                AppTheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          foregroundColor: AppTheme.onSurfaceVariant,
                        ),
                        onPressed: isSaving
                            ? null
                            : () => pickReceipt(ImageSource.gallery),
                        icon:
                            const Icon(Icons.photo_library_outlined, size: 20),
                        label: Text(l10n?.tr('chooseFromGallery') ?? 'Gallery'),
                      ),
                      if (receiptImageBytes != null)
                        TextButton.icon(
                          onPressed: isSaving
                              ? null
                              : () => setDialogState(
                                  () => receiptImageBytes = null),
                          icon: Icon(Icons.close_rounded,
                              color: AppTheme.error.withValues(alpha: 0.9)),
                          label: Text(
                            l10n?.tr('delete') ?? 'Remove',
                            style: GoogleFonts.assistant(
                              color: AppTheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (receiptImageBytes != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 436,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.memory(
                          receiptImageBytes!,
                          height: 140,
                          width: 436,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Notes
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: InputDecoration(
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                      floatingLabelAlignment: FloatingLabelAlignment.start,
                      labelText: l10n?.tr('notes') ?? 'Notes',
                      labelStyle:
                          const TextStyle(color: AppTheme.onSurfaceVariant),
                      floatingLabelStyle: const TextStyle(
                        color: AppTheme.secondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color:
                              AppTheme.outlineVariant.withValues(alpha: 0.35),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color:
                              AppTheme.outlineVariant.withValues(alpha: 0.35),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.secondary,
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.onSurfaceVariant,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        child: Text(l10n?.tr('cancel') ?? 'Cancel',
                            style: GoogleFonts.assistant(
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: isSaving || selectedCustomer == null
                            ? null
                            : () async {
                                final username =
                                    ref.read(currentUsernameProvider);
                                setDialogState(() => isSaving = true);
                                try {
                                  final payment = Payment(
                                    id: '',
                                    customerId: selectedCustomer!.id,
                                    date: DateTime.now(),
                                    type: selectedType,
                                    cardName: selectedCustomer!.cardName,
                                    customerName:
                                        selectedCustomer!.customerName,
                                    amount:
                                        double.tryParse(amountCtrl.text) ?? 0,
                                    notes: notesCtrl.text.trim().isEmpty
                                        ? null
                                        : notesCtrl.text.trim(),
                                    createdBy: username,
                                    updatedBy: username,
                                  );
                                  final created = await ref
                                      .read(paymentServiceProvider)
                                      .create(payment);
                                  if (receiptImageBytes != null &&
                                      receiptImageBytes!.isNotEmpty) {
                                    try {
                                      final url = await ref
                                          .read(paymentServiceProvider)
                                          .uploadReceiptPhoto(
                                            created.id,
                                            receiptImageBytes!,
                                          );
                                      await ref
                                          .read(paymentServiceProvider)
                                          .update(created.id, {
                                        'image_url': url,
                                        'updated_by': username,
                                      });
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${l10n?.tr('error') ?? 'Error'}: '
                                              '${l10n?.tr('receipt') ?? 'Receipt'} upload failed. $e',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                  ref.invalidate(paymentsProvider);
                                  ref.invalidate(
                                    customerPaymentsProvider(
                                      selectedCustomer!.id,
                                    ),
                                  );
                                  ref.invalidate(customersProvider);
                                  ref.invalidate(totalUnpaidDebtsProvider);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                } finally {
                                  if (ctx.mounted) {
                                    setDialogState(() => isSaving = false);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondary,
                          foregroundColor: AppTheme.onSecondary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppTheme.onSecondary,
                                ),
                              )
                            : Text(
                                l10n?.tr('save') ?? 'Save',
                                style: GoogleFonts.assistant(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
