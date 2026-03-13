import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/supplier.dart';
import '../../providers/providers.dart';

class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final suppliersAsync = ref.watch(suppliersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.tr('suppliers') ?? 'Suppliers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSupplierDialog(context, ref, l10n),
        icon: const Icon(Icons.add),
        label: Text(l10n?.tr('newSupplier') ?? 'New Supplier'),
      ),
      body: suppliersAsync.when(
        data: (suppliers) {
          if (suppliers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
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

          return Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.0,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: suppliers.length,
              itemBuilder: (context, index) {
                final supplier = suppliers[index];
                return _SupplierCard(
                  supplier: supplier,
                  l10n: l10n,
                  onEdit: () => _showSupplierDialog(
                    context,
                    ref,
                    l10n,
                    supplier: supplier,
                  ),
                  onDelete: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(l10n?.tr('delete') ?? 'Delete'),
                        content: Text('Delete ${supplier.companyName}?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(l10n?.tr('cancel') ?? 'Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.error,
                            ),
                            child: Text(l10n?.tr('delete') ?? 'Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ref
                          .read(supplierServiceProvider)
                          .delete(supplier.id);
                      ref.invalidate(suppliersProvider);
                    }
                  },
                );
              },
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

  void _showSupplierDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations? l10n, {
    Supplier? supplier,
  }) {
    final companyCtrl = TextEditingController(
      text: supplier?.companyName ?? '',
    );
    final contactCtrl = TextEditingController(
      text: supplier?.contactName ?? '',
    );
    final phoneCtrl = TextEditingController(text: supplier?.phone ?? '');
    final notesCtrl = TextEditingController(text: supplier?.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          supplier != null
              ? (l10n?.tr('edit') ?? 'Edit')
              : (l10n?.tr('newSupplier') ?? 'New Supplier'),
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: companyCtrl,
                  decoration: InputDecoration(
                    labelText: l10n?.tr('companyName') ?? 'Company Name',
                    prefixIcon: const Icon(Icons.business),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contactCtrl,
                  decoration: InputDecoration(
                    labelText: l10n?.tr('contactName') ?? 'Contact Name',
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: l10n?.tr('phone') ?? 'Phone',
                    prefixIcon: const Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
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
              final username = ref.read(currentUsernameProvider);
              if (supplier != null) {
                // Update
                await ref.read(supplierServiceProvider).update(supplier.id, {
                  'company_name': companyCtrl.text.trim(),
                  'contact_name': contactCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'notes': notesCtrl.text.trim(),
                  'updated_by': username,
                });
              } else {
                // Create
                final newSupplier = Supplier(
                  id: '',
                  companyName: companyCtrl.text.trim(),
                  contactName: contactCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  notes: notesCtrl.text.trim(),
                  createdBy: username,
                  updatedBy: username,
                );
                await ref.read(supplierServiceProvider).create(newSupplier);
              }
              ref.invalidate(suppliersProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(l10n?.tr('save') ?? 'Save'),
          ),
        ],
      ),
    );
  }
}

class _SupplierCard extends StatelessWidget {
  final Supplier supplier;
  final AppLocalizations? l10n;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SupplierCard({
    required this.supplier,
    required this.l10n,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppTheme.accentBlue.withValues(alpha: 0.3),
                ),
                child: const Icon(
                  Icons.local_shipping,
                  color: AppTheme.primaryGold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  supplier.companyName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: AppTheme.primaryGold,
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppTheme.error,
                onPressed: onDelete,
              ),
            ],
          ),
          const Spacer(),
          if (supplier.contactName != null && supplier.contactName!.isNotEmpty)
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  supplier.contactName!,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 4),
          if (supplier.phone != null && supplier.phone!.isNotEmpty)
            Row(
              children: [
                Icon(
                  Icons.phone_outlined,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  supplier.phone!,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
