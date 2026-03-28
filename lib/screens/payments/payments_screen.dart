import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/payment.dart';
import '../../models/customer.dart';
import '../../providers/providers.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  bool _showOnlyMine = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final username = ref.watch(currentUsernameProvider);
    final paymentsAsync = ref.watch(
      paymentsProvider(_showOnlyMine ? username : null),
    );

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLowest,
      appBar: AppBar(
        toolbarHeight: 0,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.secondary,
        foregroundColor: AppTheme.onSecondary,
        elevation: 4,
        onPressed: () => showPaymentDialog(context, ref, l10n),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          l10n?.tr('newPayment') ?? 'New Payment',
          style: GoogleFonts.assistant(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Editorial Header
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 32, top: 48, bottom: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n?.tr('payments') ?? 'Payments',
                      style: GoogleFonts.assistant(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color: AppTheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 4,
                      width: 60,
                      decoration: BoxDecoration(
                        color: AppTheme.secondary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
              ],
            ),
          ),

          // Sticky Control Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n?.tr('filter') ?? 'My entries only',
                      style: GoogleFonts.assistant(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurfaceVariant,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Switch(
                      value: _showOnlyMine,
                      onChanged: (v) => setState(() => _showOnlyMine = v),
                      activeColor: AppTheme.secondary,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main Table Area
          Expanded(
            child: paymentsAsync.when(
              data: (payments) {
                if (payments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.payment_outlined,
                          size: 80,
                          color: AppTheme.onSurfaceVariant.withValues(alpha: 0.3),
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
                          AppTheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        ),
                        headingRowHeight: 64,
                        dataRowMinHeight: 64,
                        dataRowMaxHeight: 72,
                        columnSpacing: 24,
                        dividerThickness: 0.5,
                        columns: [
                          _buildColumnHeader(l10n?.tr('date') ?? 'Date'),
                          _buildColumnHeader(l10n?.tr('type') ?? 'Type'),
                          _buildColumnHeader(l10n?.tr('cardName') ?? 'Card Name'),
                          _buildColumnHeader(l10n?.tr('customerName') ?? 'Customer'),
                          _buildColumnHeader(l10n?.tr('amount') ?? 'Amount'),
                          _buildColumnHeader(l10n?.tr('image') ?? 'Receipt'),
                          _buildColumnHeader(l10n?.tr('notes') ?? 'Notes'),
                          _buildColumnHeader(l10n?.tr('username') ?? 'User'),
                        ],
                        rows: payments.map((payment) {
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
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: typeColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(typeIcon, size: 16, color: typeColor),
                                      const SizedBox(width: 8),
                                      Text(
                                        payment.type.dbValue,
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
                                Icon(
                                  payment.imageUrl != null
                                      ? Icons.receipt_long
                                      : Icons.remove,
                                  color: payment.imageUrl != null
                                      ? AppTheme.success
                                      : AppTheme.onSurfaceVariant.withValues(alpha: 0.4),
                                  size: 20,
                                ),
                              ),
                              DataCell(
                                Text(
                                  payment.notes ?? '-',
                                  style: GoogleFonts.assistant(color: AppTheme.onSurfaceVariant),
                                ),
                              ),
                              DataCell(
                                Text(
                                  payment.createdBy ?? '-',
                                  style: GoogleFonts.assistant(color: AppTheme.onSurfaceVariant),
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                  // Customer dropdown
                  DropdownButtonFormField<Customer>(
                    value: selectedCustomer,
                    dropdownColor: AppTheme.surfaceContainerLowest,
                    decoration: InputDecoration(
                      labelText: l10n?.tr('customerName') ?? 'Customer',
                      labelStyle: const TextStyle(color: AppTheme.onSurfaceVariant),
                      prefixIcon: const Icon(Icons.person_outline, color: AppTheme.onSurfaceVariant),
                      filled: true,
                      fillColor: AppTheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: customers
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text('${c.cardName} - ${c.customerName}', style: const TextStyle(color: AppTheme.onSurface)),
                          ),
                        )
                        .toList(),
                    onChanged: initialCustomer != null ? null : (c) =>
                        setDialogState(() => selectedCustomer = c),
                  ),
                  const SizedBox(height: 16),
                  // Payment type
                  DropdownButtonFormField<PaymentType>(
                    value: selectedType,
                    dropdownColor: AppTheme.surfaceContainerLowest,
                    decoration: InputDecoration(
                      labelText: l10n?.tr('type') ?? 'Type',
                      labelStyle: const TextStyle(color: AppTheme.onSurfaceVariant),
                      prefixIcon: const Icon(Icons.payment, color: AppTheme.onSurfaceVariant),
                      filled: true,
                      fillColor: AppTheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: PaymentType.cash,
                        child: Text(l10n?.tr('cash') ?? 'Cash', style: const TextStyle(color: AppTheme.onSurface)),
                      ),
                      DropdownMenuItem(
                        value: PaymentType.credit,
                        child: Text(l10n?.tr('credit') ?? 'Credit', style: const TextStyle(color: AppTheme.onSurface)),
                      ),
                      DropdownMenuItem(
                        value: PaymentType.check,
                        child: Text(l10n?.tr('check') ?? 'Check', style: const TextStyle(color: AppTheme.onSurface)),
                      ),
                    ],
                    onChanged: (v) => setDialogState(
                      () => selectedType = v ?? PaymentType.cash,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Amount
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: InputDecoration(
                      labelText: l10n?.tr('amount') ?? 'Amount',
                      labelStyle: const TextStyle(color: AppTheme.onSurfaceVariant),
                      prefixIcon: const Icon(Icons.attach_money, color: AppTheme.onSurfaceVariant),
                      filled: true,
                      fillColor: AppTheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Receipt image
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                      side: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      foregroundColor: AppTheme.onSurfaceVariant,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Camera - requires device'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text(l10n?.tr('takePhoto') ?? 'Take Photo'),
                  ),
                  const SizedBox(height: 16),
                  // Notes
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: InputDecoration(
                      labelText: l10n?.tr('notes') ?? 'Notes',
                      labelStyle: const TextStyle(color: AppTheme.onSurfaceVariant),
                      filled: true,
                      fillColor: AppTheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
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
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Text(l10n?.tr('cancel') ?? 'Cancel', style: GoogleFonts.assistant(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          if (selectedCustomer == null) return;
                          final username = ref.read(currentUsernameProvider);
                          final payment = Payment(
                            id: '',
                            customerId: selectedCustomer!.id,
                            date: DateTime.now(),
                            type: selectedType,
                            cardName: selectedCustomer!.cardName,
                            customerName: selectedCustomer!.customerName,
                            amount: double.tryParse(amountCtrl.text) ?? 0,
                            notes: notesCtrl.text.trim(),
                            createdBy: username,
                            updatedBy: username,
                          );
                          await ref.read(paymentServiceProvider).create(payment);
                          ref.invalidate(paymentsProvider);
                          ref.invalidate(customersProvider);
                          ref.invalidate(totalUnpaidDebtsProvider);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondary,
                          foregroundColor: AppTheme.onSecondary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(l10n?.tr('save') ?? 'Save', style: GoogleFonts.assistant(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
