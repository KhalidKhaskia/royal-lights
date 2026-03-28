import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:image_picker/image_picker.dart';
import '../../config/app_animations.dart';
import '../../config/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/customer.dart';
import '../../models/order.dart';
import '../../providers/providers.dart';
import 'customer_detail_screen.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final customersAsync = ref.watch(customersProvider);
    final ordersAsync = ref.watch(ordersProvider);

    final Map<String, int> activeOrdersMap = {};
    final Map<String, int> totalOrdersMap = {};

    if (ordersAsync.hasValue) {
      for (final o in ordersAsync.value!) {
        totalOrdersMap[o.customerId] = (totalOrdersMap[o.customerId] ?? 0) + 1;
        if (o.status != OrderStatus.delivered && o.status != OrderStatus.canceled) {
          activeOrdersMap[o.customerId] = (activeOrdersMap[o.customerId] ?? 0) + 1;
        }
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: customersAsync.when(
        data: (customers) {
          final filtered = customers.where((c) {
            if (_searchQuery.isEmpty) return true;
            return c.cardName.toLowerCase().contains(_searchQuery) ||
                c.customerName.toLowerCase().contains(_searchQuery) ||
                c.phones.any((p) => p.contains(_searchQuery));
          }).toList();

          return CustomScrollView(
            slivers: [
              // ─── Page Header ───────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        l10n?.tr('customers') ?? 'Customers',
                        style: GoogleFonts.assistant(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'סה״כ לקוחות: ${customers.length}',
                        style: GoogleFonts.assistant(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),

                      const SizedBox(height: 16),
                      // ─── Search bar + filter row ───
                      Row(
                        children: [
                          // Search field
                          Expanded(
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: AppTheme.outlineVariant
                                      .withValues(alpha: 0.15),
                                ),
                              ),
                              child: TextField(
                                onChanged: (v) => setState(
                                    () => _searchQuery = v.toLowerCase()),
                                style: GoogleFonts.assistant(
                                  fontSize: 14,
                                  color: AppTheme.onSurface,
                                ),
                                decoration: InputDecoration(
                                  hintText: l10n?.tr('search') ?? 'Search...',
                                  hintStyle: TextStyle(
                                    color: AppTheme.outline
                                        .withValues(alpha: 0.4),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    size: 20,
                                    color: AppTheme.outline,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Add Customer button
                          Material(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(100),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(100),
                              onTap: () =>
                                  _showCustomerDialog(context, ref, l10n),
                              child: Container(
                                height: 38,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add_rounded,
                                        size: 20,
                                        color: AppTheme.onPrimary),
                                    const SizedBox(width: 8),
                                    Text(
                                      l10n?.tr('newCustomer') ??
                                          'New Customer',
                                      style: GoogleFonts.assistant(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.onPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              // ─── Customer Grid ─────────────────────────────────────
              if (filtered.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: AppTheme.outline.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n?.tr('noData') ?? 'No Data',
                          style: GoogleFonts.assistant(
                            color: AppTheme.onSurfaceVariant,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.crossAxisExtent;
                      final cols = width > 900 ? 4 : width > 600 ? 3 : 2;
                      return SliverGrid(
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      childAspectRatio: 0.62,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final customer = filtered[index];
                        return StaggeredFadeIn(
                          index: index,
                          stepMilliseconds: 55,
                          child: _CustomerCard(
                            customer: customer,
                            index: index,
                            activeOrders: activeOrdersMap[customer.id] ?? 0,
                            totalOrders: totalOrdersMap[customer.id] ?? 0,
                            l10n: l10n,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CustomerDetailScreen(
                                      customer: customer),
                                ),
                              );
                            },
                          ),
                        );
                      },
                      childCount: filtered.length,
                    ),
                      );
                    },
                  ),
                ),
              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            '${l10n?.tr('error') ?? 'Error'}: $e',
            style: const TextStyle(color: AppTheme.error),
          ),
        ),
      ),
    );
  }

  void _showCustomerDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations? l10n,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => CustomerFormDialog(
        ref: ref,
        l10n: l10n,
        onCustomerSaved: (createdCustomer) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CustomerDetailScreen(customer: createdCustomer),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NEW CUSTOMER DIALOG — Clean, editorial style
// ─────────────────────────────────────────────────────────────────────────────
class CustomerFormDialog extends StatefulWidget {
  final WidgetRef ref;
  final AppLocalizations? l10n;
  final Customer? existingCustomer;
  final Function(Customer)? onCustomerSaved;

  const CustomerFormDialog({
    super.key,
    required this.ref,
    required this.l10n,
    this.existingCustomer,
    this.onCustomerSaved,
  });

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  final _cardNameCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  Uint8List? _pickedImageBytes;
  bool _deleteExistingPhoto = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingCustomer != null) {
      final c = widget.existingCustomer!;
      _cardNameCtrl.text = c.cardName;
      _nameCtrl.text = c.customerName;
      _phoneCtrl.text = c.phones.join(', ');
      _locationCtrl.text = c.location ?? '';
      _notesCtrl.text = c.notes ?? '';
    }
  }

  @override
  void dispose() {
    _cardNameCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _showPhotoPicker() async {
    final l10n = widget.l10n;
    final hasExisting = widget.existingCustomer?.imageUrl != null && !_deleteExistingPhoto;
    final hasPicked = _pickedImageBytes != null;

    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n?.tr('selectImageSource') ?? 'Select Image Source', style: GoogleFonts.assistant(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.camera_alt_outlined, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  Text(l10n?.tr('camera') ?? 'Camera', style: GoogleFonts.assistant(fontSize: 16)),
                ],
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.photo_library_outlined, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  Text(l10n?.tr('gallery') ?? 'Gallery', style: GoogleFonts.assistant(fontSize: 16)),
                ],
              ),
            ),
          ),
          if (hasExisting || hasPicked)
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _pickedImageBytes = null;
                  _deleteExistingPhoto = true;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: AppTheme.error),
                    const SizedBox(width: 12),
                    Text(l10n?.tr('deletePhoto') ?? 'Delete Photo', style: GoogleFonts.assistant(fontSize: 16, color: AppTheme.error)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    if (source != null) {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (xFile == null || !mounted) return;
      final bytes = await xFile.readAsBytes();
      if (mounted) {
        setState(() {
          _pickedImageBytes = bytes;
          _deleteExistingPhoto = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final cardName = _cardNameCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (cardName.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(widget.l10n?.tr('error') ??
                'Please fill required fields')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final username = widget.ref.read(currentUsernameProvider);
      final phones = _phoneCtrl.text
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      if (widget.existingCustomer == null) {
        // Create new
        final customer = Customer(
          id: '',
          cardName: cardName,
          customerName: name,
          phones: phones,
          location: _locationCtrl.text.trim(),
          notes: _notesCtrl.text.trim(),
          createdBy: username,
          updatedBy: username,
        );
        var created = await widget.ref.read(customerServiceProvider).create(customer);
        if (_pickedImageBytes != null) {
          final url = await widget.ref.read(customerServiceProvider).uploadPhoto(created.id, _pickedImageBytes!);
          created = created.copyWith(imageUrl: url);
          await widget.ref.read(customerServiceProvider).update(created.id, {'image_url': url, 'updated_by': username});
        }
        widget.ref.invalidate(customersProvider);
        if (mounted) {
          Navigator.of(context).pop();
          widget.onCustomerSaved?.call(created);
        }
      } else {
        // Update existing
        var customer = widget.existingCustomer!.copyWith(
          cardName: cardName,
          customerName: name,
          phones: phones,
          location: _locationCtrl.text.trim(),
          notes: _notesCtrl.text.trim(),
          updatedBy: username,
        );
        final updates = {
          'card_name': customer.cardName,
          'customer_name': customer.customerName,
          'phones': customer.phones,
          'location': customer.location,
          'notes': customer.notes,
          'updated_by': username,
        };
        await widget.ref.read(customerServiceProvider).update(customer.id, updates);

        if (_pickedImageBytes != null) {
          final url = await widget.ref.read(customerServiceProvider).uploadPhoto(customer.id, _pickedImageBytes!);
          customer = customer.copyWith(imageUrl: url);
          await widget.ref.read(customerServiceProvider).update(customer.id, {'image_url': url});
        } else if (_deleteExistingPhoto) {
          await widget.ref.read(customerServiceProvider).deletePhoto(customer.id);
          customer = customer.copyWith(imageUrl: null);
          // deletePhoto already sets image_url to null in db
        }
        widget.ref.invalidate(customersProvider);
        if (mounted) {
          Navigator.of(context).pop();
          widget.onCustomerSaved?.call(customer);
        }
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.contains('23505') || msg.contains('duplicate key')) {
          msg = widget.l10n?.tr('customerExistsError') ?? 'A customer with this Card Name already exists.';
        } else {
          msg = '${widget.l10n?.tr('error') ?? 'Error'}: $e';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return Dialog(
      backgroundColor: AppTheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existingCustomer == null 
                    ? (l10n?.tr('newCustomer') ?? 'לקוח חדש')
                    : (l10n?.tr('editCustomer') ?? 'עריכת פרטי לקוח'),
                style: GoogleFonts.assistant(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              // Photo picker
              GestureDetector(
                onTap: _saving ? null : _showPhotoPicker,
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                  child: _pickedImageBytes == null
                      ? ((widget.existingCustomer?.imageUrl != null && !_deleteExistingPhoto)
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: widget.existingCustomer!.imageUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo_outlined,
                                  size: 32,
                                  color: AppTheme.outline,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l10n?.tr('image') ?? 'Add photo',
                                  style: GoogleFonts.assistant(
                                    color: AppTheme.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ))
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                _pickedImageBytes!,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Material(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: const CircleBorder(),
                                child: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                                  onPressed: () {
                                    setState(() => _pickedImageBytes = null);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
              _buildDialogField(
                controller: _cardNameCtrl,
                label: l10n?.tr('cardName') ?? 'Card Name',
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 14),
              _buildDialogField(
                controller: _nameCtrl,
                label: l10n?.tr('customerName') ?? 'Customer Name',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 14),
              _buildDialogField(
                controller: _phoneCtrl,
                label: l10n?.tr('phones') ?? 'Phones',
                icon: Icons.phone_outlined,
                hint: 'Comma separated',
              ),
              const SizedBox(height: 14),
              _buildDialogField(
                controller: _locationCtrl,
                label: l10n?.tr('location') ?? 'Location',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 14),
              _buildDialogField(
                controller: _notesCtrl,
                label: l10n?.tr('notes') ?? 'Notes',
                icon: Icons.note_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: Text(
                      l10n?.tr('cancel') ?? 'Cancel',
                      style: GoogleFonts.assistant(
                        color: AppTheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: AppTheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            l10n?.tr('save') ?? 'Save',
                            style: GoogleFonts.assistant(
                                fontWeight: FontWeight.w600),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.assistant(fontSize: 14, color: AppTheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: AppTheme.onSurfaceVariant,
            fontSize: 13,
          ),
          hintText: hint,
          hintStyle: TextStyle(color: AppTheme.outline.withValues(alpha: 0.4)),
          prefixIcon: Icon(icon, size: 20, color: AppTheme.outline),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.secondary, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOMER CARD — Matches Stitch "Customers (Final)" screen
// Large photo top, name + subtitle + status dot at bottom
// ─────────────────────────────────────────────────────────────────────────────
class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final int index;
  final int activeOrders;
  final int totalOrders;
  final AppLocalizations? l10n;
  final VoidCallback onTap;

  const _CustomerCard({
    required this.customer,
    required this.index,
    required this.activeOrders,
    required this.totalOrders,
    required this.l10n,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPaid = customer.remainingDebt <= 0;
    
    // Header Color alternating matching reference image (Dark Blue vs Orange)
    final topColor = (index % 2 == 0) ? const Color(0xFF263248) : const Color(0xFFE2870F);

    // Active status
    final bool isActive = activeOrders > 0;
    final String activeLabel = isActive ? 'פעיל' : 'לא פעיל';
    final Color activeColor = isActive ? AppTheme.success : AppTheme.outline;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.12),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(26, 28, 28, 0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top Banner & Avatar Area ──
              SizedBox(
                height: 100,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    Container(
                      height: 60,
                      decoration: BoxDecoration(color: topColor),
                    ),
                    Positioned(
                      top: 30,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.surfaceContainerLowest,
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.surfaceContainerHighest,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _buildPhoto(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // ── Badge & Card ID Row ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPaid ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.warning.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isPaid ? 'שולם' : 'חלקי',
                            style: GoogleFonts.assistant(
                              color: isPaid ? AppTheme.success : AppTheme.warning.withValues(alpha: 0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            customer.cardName,
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.assistant(
                              color: AppTheme.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                  ),
                ),
              ),
              
              const SizedBox(height: 8),

              // ── Name & Phone Center ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Text(
                      customer.customerName,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.assistant(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customer.phones.isNotEmpty ? customer.phones.first : '-',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.assistant(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Orders Status ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: activeColor),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$activeLabel • $activeOrders / $totalOrders הזמנות פתוחות',
                          style: GoogleFonts.assistant(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ── Divider ──
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: AppTheme.outlineVariant.withValues(alpha: 0.15),
              ),
              
              // ── Bottom Area: Debt ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '₪',
                            style: GoogleFonts.assistant(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isPaid ? AppTheme.onSurface : AppTheme.error,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPaid ? '0.00' : customer.remainingDebt.toStringAsFixed(2),
                            style: GoogleFonts.assistant(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isPaid ? AppTheme.onSurface : AppTheme.error,
                            ),
                          ),
                        ],
                      ),
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text(
                          l10n?.tr('remainingDebt') ?? 'יתרה לתשלום',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.assistant(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoto() {
    if (customer.imageUrl != null && customer.imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: customer.imageUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => _photoPlaceholder(),
        errorWidget: (_, __, ___) => _photoPlaceholder(),
      );
    }
    return _photoPlaceholder();
  }

  Widget _photoPlaceholder() {
    return Container(
      color: AppTheme.surfaceContainer,
      child: Center(
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.secondary.withValues(alpha: 0.15),
          ),
          child: Center(
            child: Text(
              customer.cardName.isNotEmpty
                  ? customer.cardName[0].toUpperCase()
                  : '?',
              style: GoogleFonts.assistant(
                color: AppTheme.secondary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
