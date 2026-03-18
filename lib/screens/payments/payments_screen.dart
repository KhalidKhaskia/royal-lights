import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      appBar: AppBar(
        title: Text(l10n?.tr('payments') ?? 'Payments'),
        actions: [
          // Filter toggle
          Row(
            children: [
              Text(
                l10n?.tr('filter') ?? 'My entries only',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: _showOnlyMine,
                onChanged: (v) => setState(() => _showOnlyMine = v),
              ),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPaymentDialog(context, ref, l10n),
        tooltip: l10n?.tr('newPayment') ?? 'New Payment',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: paymentsAsync.when(
        data: (payments) {
          if (payments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.payment_outlined,
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
            child: SizedBox(
              width: double.infinity,
              child: DataTable(
                headingRowHeight: 56,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 60,
                columnSpacing: 24,
                columns: [
                  DataColumn(label: Text(l10n?.tr('date') ?? 'Date')),
                  DataColumn(label: Text(l10n?.tr('type') ?? 'Type')),
                  DataColumn(label: Text(l10n?.tr('cardName') ?? 'Card Name')),
                  DataColumn(
                    label: Text(l10n?.tr('customerName') ?? 'Customer'),
                  ),
                  DataColumn(label: Text(l10n?.tr('amount') ?? 'Amount')),
                  DataColumn(label: Text(l10n?.tr('image') ?? 'Receipt')),
                  DataColumn(label: Text(l10n?.tr('notes') ?? 'Notes')),
                  DataColumn(label: Text(l10n?.tr('username') ?? 'User')),
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
                      typeColor = AppTheme.primaryGold;
                      break;
                    case PaymentType.check:
                      typeIcon = Icons.description;
                      typeColor = AppTheme.warning;
                      break;
                  }

                  return DataRow(
                    cells: [
                      DataCell(Text(payment.date.toString().split(' ').first)),
                      DataCell(
                        Row(
                          children: [
                            Icon(typeIcon, size: 18, color: typeColor),
                            const SizedBox(width: 6),
                            Text(
                              payment.type.dbValue,
                              style: TextStyle(
                                color: typeColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Text(
                          payment.cardName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(Text(payment.customerName)),
                      DataCell(
                        Text(
                          '₪${payment.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryGold,
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
                              : AppTheme.textSecondary,
                          size: 20,
                        ),
                      ),
                      DataCell(
                        Text(
                          payment.notes ?? '-',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                      DataCell(
                        Text(
                          payment.createdBy ?? '-',
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
            'Error: $e',
            style: const TextStyle(color: AppTheme.error),
          ),
        ),
      ),
    );
  }

  void _showPaymentDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations? l10n,
  ) {
    final customersAsync = ref.read(customersProvider);
    final customers = customersAsync.value ?? [];

    Customer? selectedCustomer;
    PaymentType selectedType = PaymentType.cash;
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n?.tr('newPayment') ?? 'New Payment'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Customer dropdown
                  DropdownButtonFormField<Customer>(
                    value: selectedCustomer,
                    decoration: InputDecoration(
                      labelText: l10n?.tr('customerName') ?? 'Customer',
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    items: customers
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text('${c.cardName} - ${c.customerName}'),
                          ),
                        )
                        .toList(),
                    onChanged: (c) =>
                        setDialogState(() => selectedCustomer = c),
                  ),
                  const SizedBox(height: 16),
                  // Payment type
                  DropdownButtonFormField<PaymentType>(
                    value: selectedType,
                    decoration: InputDecoration(
                      labelText: l10n?.tr('type') ?? 'Type',
                      prefixIcon: const Icon(Icons.payment),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: PaymentType.cash,
                        child: Text(l10n?.tr('cash') ?? 'Cash'),
                      ),
                      DropdownMenuItem(
                        value: PaymentType.credit,
                        child: Text(l10n?.tr('credit') ?? 'Credit'),
                      ),
                      DropdownMenuItem(
                        value: PaymentType.check,
                        child: Text(l10n?.tr('check') ?? 'Check'),
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
                    decoration: InputDecoration(
                      labelText: l10n?.tr('amount') ?? 'Amount',
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Receipt image
                  OutlinedButton.icon(
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
                    decoration: InputDecoration(
                      labelText: l10n?.tr('notes') ?? 'Notes',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n?.tr('cancel') ?? 'Cancel'),
            ),
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
              child: Text(l10n?.tr('save') ?? 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
