import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_animations.dart';
import '../../config/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/customer.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.tr('customers') ?? 'Customers'),
        actions: [
          // Search
          SizedBox(
            width: 300,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: TextField(
                onChanged: (v) =>
                    setState(() => _searchQuery = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: l10n?.tr('search') ?? 'Search...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceLight,
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCustomerDialog(context, ref, l10n),
        tooltip: l10n?.tr('newCustomer') ?? 'New Customer',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: customersAsync.when(
        data: (customers) {
          final filtered = customers.where((c) {
            if (_searchQuery.isEmpty) return true;
            return c.cardName.toLowerCase().contains(_searchQuery) ||
                c.customerName.toLowerCase().contains(_searchQuery) ||
                c.phones.any((p) => p.contains(_searchQuery));
          }).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 80,
                    color: AppTheme.textSecondary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n?.tr('noData') ?? 'No Data',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            );
          }

          final width = MediaQuery.of(context).size.width;
          final crossAxisCount = width > 1200
              ? 6
              : width > 900
                  ? 5
                  : width > 600
                      ? 4
                      : 2;

          return Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 0.82,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final customer = filtered[index];
                return StaggeredFadeIn(
                  index: index,
                  stepMilliseconds: 55,
                  child: _CustomerCard(
                    customer: customer,
                    l10n: l10n,
                    compact: true,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              CustomerDetailScreen(customer: customer),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
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
      builder: (ctx) => _NewCustomerDialog(ref: ref, l10n: l10n),
    );
  }
}

class _NewCustomerDialog extends StatefulWidget {
  final WidgetRef ref;
  final AppLocalizations? l10n;

  const _NewCustomerDialog({required this.ref, required this.l10n});

  @override
  State<_NewCustomerDialog> createState() => _NewCustomerDialogState();
}

class _NewCustomerDialogState extends State<_NewCustomerDialog> {
  final _cardNameCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  Uint8List? _pickedImageBytes;
  bool _saving = false;

  @override
  void dispose() {
    _cardNameCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (xFile == null || !mounted) return;
    final bytes = await xFile.readAsBytes();
    if (mounted) setState(() => _pickedImageBytes = bytes);
  }

  Future<void> _save() async {
    final cardName = _cardNameCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (cardName.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.l10n?.tr('error') ?? 'Please fill required fields')),
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
      final created = await widget.ref.read(customerServiceProvider).create(customer);
      if (_pickedImageBytes != null) {
        final url = await widget.ref.read(customerServiceProvider).uploadPhoto(
              created.id,
              _pickedImageBytes!,
            );
        await widget.ref.read(customerServiceProvider).update(
              created.id,
              {'image_url': url, 'updated_by': username},
            );
      }
      widget.ref.invalidate(customersProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.l10n?.tr('error') ?? 'Error'}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n?.tr('newCustomer') ?? 'New Customer'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Photo picker
              GestureDetector(
                onTap: _saving ? null : _pickPhoto,
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.primaryGold.withValues(alpha: 0.4),
                    ),
                  ),
                  child: _pickedImageBytes == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo,
                              size: 40,
                              color: AppTheme.primaryGold.withValues(alpha: 0.8),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n?.tr('image') ?? 'Add photo',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            _pickedImageBytes!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _cardNameCtrl,
                decoration: InputDecoration(
                  labelText: l10n?.tr('cardName') ?? 'Card Name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: l10n?.tr('customerName') ?? 'Customer Name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtrl,
                decoration: InputDecoration(
                  labelText: l10n?.tr('phones') ?? 'Phones',
                  helperText: 'Comma separated',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationCtrl,
                decoration: InputDecoration(
                  labelText: l10n?.tr('location') ?? 'Location',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
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
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(l10n?.tr('cancel') ?? 'Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : Text(l10n?.tr('save') ?? 'Save'),
        ),
      ],
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final AppLocalizations? l10n;
  final VoidCallback onTap;
  final bool compact;

  const _CustomerCard({
    required this.customer,
    required this.l10n,
    required this.onTap,
    this.compact = false,
  });

  /// Placeholder photo URL for mockup when customer has no image (deterministic per customer).
  static String _mockPhotoUrl(String id) =>
      'https://picsum.photos/seed/${id.hashCode.abs()}/400/280';

  @override
  Widget build(BuildContext context) {
    Color paymentColor;
    String paymentLabel;
    if (customer.remainingDebt <= 0) {
      paymentColor = AppTheme.paid;
      paymentLabel = l10n?.tr('paid') ?? 'Paid';
    } else if (customer.remainingDebt > 0) {
      paymentColor = AppTheme.unpaid;
      paymentLabel = l10n?.tr('unpaid') ?? 'Unpaid';
    } else {
      paymentColor = AppTheme.partial;
      paymentLabel = l10n?.tr('partial') ?? 'Partial';
    }

    final contentPadding = compact ? 8.0 : 16.0;
    final borderRadius = compact ? 12.0 : 20.0;
    final titleSize = compact ? 14.0 : 17.0;
    final subtitleSize = compact ? 11.0 : 13.0;
    final badgePaddingH = compact ? 6.0 : 10.0;
    final badgePaddingV = compact ? 4.0 : 6.0;
    final avatarSize = compact ? 36.0 : 64.0;
    final avatarFontSize = compact ? 16.0 : 26.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: compact ? 8 : 16,
                offset: Offset(0, compact ? 3 : 6),
              ),
              BoxShadow(
                color: AppTheme.primaryGold.withValues(alpha: 0.06),
                blurRadius: compact ? 10 : 20,
                offset: Offset(0, compact ? 2 : 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                border: Border.all(
                  color: AppTheme.primaryGold.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Photo: takes ~60% of card so it extends down; no fixed height = no gap
                  Expanded(
                    flex: 60,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (customer.imageUrl != null &&
                            customer.imageUrl!.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: customer.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _buildPhotoPlaceholder(
                              avatarSize: avatarSize,
                              avatarFontSize: avatarFontSize,
                            ),
                            errorWidget: (_, __, ___) =>
                                _buildPhotoPlaceholder(
                              avatarSize: avatarSize,
                              avatarFontSize: avatarFontSize,
                            ),
                          )
                        else
                          CachedNetworkImage(
                            imageUrl: _mockPhotoUrl(customer.id),
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _buildPhotoPlaceholder(
                              avatarSize: avatarSize,
                              avatarFontSize: avatarFontSize,
                            ),
                            errorWidget: (_, __, ___) =>
                                _buildPhotoPlaceholder(
                              avatarSize: avatarSize,
                              avatarFontSize: avatarFontSize,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Content: fixed portion at bottom; scrollable to prevent overflow
                  Expanded(
                    flex: 40,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: contentPadding,
                        vertical: contentPadding * 0.5,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                        Text(
                          customer.cardName,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: titleSize,
                            color: AppTheme.textPrimary,
                            letterSpacing: 0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        SizedBox(height: compact ? 0 : 2),
                        Text(
                          customer.customerName,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: subtitleSize,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        SizedBox(height: compact ? 4 : 8),
                        // Payment badge
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: badgePaddingH,
                            vertical: badgePaddingV,
                          ),
                          decoration: BoxDecoration(
                            color: paymentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: paymentColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            paymentLabel,
                            style: TextStyle(
                              color: paymentColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!compact) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 16,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '₪${customer.remainingDebt.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: customer.remainingDebt > 0
                                      ? AppTheme.error
                                      : AppTheme.success,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (customer.phones.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.phone_outlined,
                                  size: 14,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    customer.phones.join(', '),
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ] else ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 12,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '₪${customer.remainingDebt.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: customer.remainingDebt > 0
                                        ? AppTheme.error
                                        : AppTheme.success,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPlaceholder({
    double avatarSize = 64,
    double avatarFontSize = 26,
  }) {
    return Container(
      color: AppTheme.surfaceDark,
      child: Center(
        child: Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryGold,
                AppTheme.primaryGold.withValues(alpha: 0.7),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryGold.withValues(alpha: 0.3),
                blurRadius: 12,
              ),
            ],
          ),
          child: Center(
            child: Text(
              customer.cardName.isNotEmpty
                  ? customer.cardName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: Colors.black,
                fontSize: avatarFontSize,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
