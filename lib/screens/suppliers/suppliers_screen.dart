import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
        onPressed: () => _showSupplierDialog(context, ref, l10n),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          l10n?.tr('newSupplier') ?? 'New Supplier',
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
                      l10n?.tr('suppliers') ?? 'Suppliers',
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

          Expanded(
            child: suppliersAsync.when(
              data: (suppliers) {
                if (suppliers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_shipping_outlined,
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

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.2,
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
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
                              backgroundColor: AppTheme.surfaceContainerLowest,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: Text(l10n?.tr('delete') ?? 'Delete', style: GoogleFonts.assistant(fontWeight: FontWeight.w700)),
                              content: Text('Delete ${supplier.companyName}?', style: GoogleFonts.assistant(fontSize: 16)),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(l10n?.tr('cancel') ?? 'Cancel', style: GoogleFonts.assistant(color: AppTheme.onSurfaceVariant)),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.error,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                  ),
                                  child: Text(l10n?.tr('delete') ?? 'Delete', style: GoogleFonts.assistant(fontWeight: FontWeight.w700)),
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
                  style: GoogleFonts.assistant(color: AppTheme.error),
                ),
              ),
            ),
          ),
        ],
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
      builder: (ctx) => Dialog(
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
                  supplier != null
                      ? (l10n?.tr('edit') ?? 'Edit Supplier')
                      : (l10n?.tr('newSupplier') ?? 'New Supplier'),
                  style: GoogleFonts.assistant(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: companyCtrl,
                  style: GoogleFonts.assistant(color: AppTheme.onSurface),
                  decoration: InputDecoration(
                    labelText: l10n?.tr('companyName') ?? 'Company Name',
                    labelStyle: const TextStyle(color: AppTheme.onSurfaceVariant),
                    prefixIcon: const Icon(Icons.business, color: AppTheme.onSurfaceVariant),
                    filled: true,
                    fillColor: AppTheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contactCtrl,
                  style: GoogleFonts.assistant(color: AppTheme.onSurface),
                  decoration: InputDecoration(
                    labelText: l10n?.tr('contactName') ?? 'Contact Name',
                    labelStyle: const TextStyle(color: AppTheme.onSurfaceVariant),
                    prefixIcon: const Icon(Icons.person_outline, color: AppTheme.onSurfaceVariant),
                    filled: true,
                    fillColor: AppTheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.assistant(color: AppTheme.onSurface),
                  decoration: InputDecoration(
                    labelText: l10n?.tr('phone') ?? 'Phone',
                    labelStyle: const TextStyle(color: AppTheme.onSurfaceVariant),
                    prefixIcon: const Icon(Icons.phone, color: AppTheme.onSurfaceVariant),
                    filled: true,
                    fillColor: AppTheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  style: GoogleFonts.assistant(color: AppTheme.onSurface),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: AppTheme.secondaryContainer,
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: AppTheme.secondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  supplier.companyName,
                  style: GoogleFonts.assistant(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppTheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: AppTheme.onSurfaceVariant,
                onPressed: onEdit,
              ),
              const SizedBox(width: 4),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.error.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
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
                  size: 16,
                  color: AppTheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  supplier.contactName!,
                  style: GoogleFonts.assistant(
                    color: AppTheme.onSurfaceVariant,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          if (supplier.phone != null && supplier.phone!.isNotEmpty)
            Row(
              children: [
                Icon(
                  Icons.phone_outlined,
                  size: 16,
                  color: AppTheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  supplier.phone!,
                  style: GoogleFonts.assistant(
                    color: AppTheme.onSurfaceVariant,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
