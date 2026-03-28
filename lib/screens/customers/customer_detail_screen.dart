import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/customer.dart';
import '../../models/order.dart';
import '../../models/payment.dart';
import '../../providers/providers.dart';
import '../orders/order_form_screen.dart';
import '../payments/payments_screen.dart';
import 'customers_screen.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final Customer customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  ConsumerState<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  late Customer _customer;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
  }

  Future<void> _sendWhatsAppReport(
      BuildContext context, AppLocalizations? l10n) async {
    if (_customer.phones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.tr('noPhone') ?? 'No phone number available'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    String phone = _customer.phones.first.replaceAll(RegExp(r'\D'), '');
    if (phone.startsWith('0')) {
      phone = '972${phone.substring(1)}';
    } else if (!phone.startsWith('972')) {
      phone = '972$phone';
    }

    final message =
        'שלום ${_customer.cardName},\n\nמצורף דוח מצב חשבון עדכני.\nיתרת חוב: ₪${_customer.remainingDebt.toStringAsFixed(2)}';

    // Instead of whatsapp://, use https://wa.me/ which reliably redirects on mobile and web
    final url =
        Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(l10n?.tr('whatsappError') ?? 'Could not open WhatsApp'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(l10n?.tr('whatsappError') ?? 'Could not open WhatsApp'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ordersAsync = ref.watch(customerOrdersProvider(_customer.id));
    final paymentsAsync = ref.watch(customerPaymentsProvider(_customer.id));

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.onSurface),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              // TODO: Open edit dialog
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(customersProvider);
          ref.invalidate(customerOrdersProvider(_customer.id));
          ref.invalidate(customerPaymentsProvider(_customer.id));
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;

            final rightColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _ContactInfoCard(customer: _customer, l10n: l10n),
                const SizedBox(height: 24),
                if (_customer.notes != null && _customer.notes!.isNotEmpty)
                  _NotesCard(notes: _customer.notes!, l10n: l10n),
              ],
            );

            final leftColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _OrdersListSection(ordersAsync: ordersAsync, l10n: l10n),
                const SizedBox(height: 32),
                _PaymentsListSection(paymentsAsync: paymentsAsync, l10n: l10n),
              ],
            );

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _HeroBanner(
                    customer: _customer,
                    l10n: l10n,
                    ordersAsync: ordersAsync,
                    onNewOrder: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              OrderFormScreen(initialCustomer: _customer),
                        ),
                      );
                    },
                    onEditDetails: () {
                      showDialog<Customer>(
                        context: context,
                        builder: (ctx) => CustomerFormDialog(
                          ref: ref,
                          l10n: l10n,
                          existingCustomer: _customer,
                          onCustomerSaved: (updated) {
                            setState(() {
                              _customer = updated;
                            });
                          },
                        ),
                      );
                    },
                    onSendReport: () => _sendWhatsAppReport(context, l10n),
                  ),
                ),
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  sliver: SliverToBoxAdapter(
                    child: isWide
                        ? Directionality(
                            textDirection: TextDirection.rtl,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(flex: 4, child: rightColumn),
                                const SizedBox(width: 32),
                                Expanded(flex: 6, child: leftColumn),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              rightColumn,
                              const SizedBox(height: 32),
                              leftColumn,
                            ],
                          ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Hero Banner ─────────────────────────────────────────────────────────────

class _HeroBanner extends ConsumerStatefulWidget {
  final Customer customer;
  final AppLocalizations? l10n;
  final AsyncValue<List<Order>> ordersAsync;
  final VoidCallback onNewOrder;
  final VoidCallback onEditDetails;
  final VoidCallback onSendReport;

  const _HeroBanner({
    required this.customer,
    required this.l10n,
    required this.ordersAsync,
    required this.onNewOrder,
    required this.onEditDetails,
    required this.onSendReport,
  });

  @override
  ConsumerState<_HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends ConsumerState<_HeroBanner> {
  bool _isUpdatingPhoto = false;

  Future<void> _showPhotoPicker() async {
    final l10n = widget.l10n;
    final hasExisting = widget.customer.imageUrl != null && widget.customer.imageUrl!.isNotEmpty;

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
          if (hasExisting)
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _isUpdatingPhoto = true);
                try {
                  await ref.read(customerServiceProvider).deletePhoto(widget.customer.id);
                  ref.invalidate(customersProvider);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                } finally {
                  if (mounted) setState(() => _isUpdatingPhoto = false);
                }
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
      
      setState(() => _isUpdatingPhoto = true);
      try {
        final url = await ref.read(customerServiceProvider).uploadPhoto(widget.customer.id, bytes);
        await ref.read(customerServiceProvider).update(widget.customer.id, {'image_url': url});
        ref.invalidate(customersProvider);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) setState(() => _isUpdatingPhoto = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;
    final ordersAsync = widget.ordersAsync;
    final l10n = widget.l10n;
    final onEditDetails = widget.onEditDetails;
    final onSendReport = widget.onSendReport;
    final onNewOrder = widget.onNewOrder;
    // Determine VIP status (e.g. 5+ completed orders)
    bool isVip = false;
    if (ordersAsync.hasValue) {
      final completed = ordersAsync.value!
          .where((o) => o.status == OrderStatus.delivered)
          .length;
      if (completed >= 5) isVip = true;
    }

    final hasDebt = customer.remainingDebt > 0;

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        // Background banner
        Container(
          height: 240,
          width: double.infinity,
          decoration: BoxDecoration(
            image: customer.imageUrl != null && customer.imageUrl!.isNotEmpty
                ? DecorationImage(
                    image: CachedNetworkImageProvider(customer.imageUrl!),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withValues(alpha: 0.6),
                      BlendMode.darken,
                    ),
                  )
                : null,
            gradient: customer.imageUrl == null || customer.imageUrl!.isEmpty
                ? const LinearGradient(
                    colors: [
                      Color(0xFFE8DED5), // warm beige
                      Color(0xFFC9B8A8), // soft taupe
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: customer.imageUrl != null && customer.imageUrl!.isNotEmpty
                ? const Color(0xFF1B2430)
                : null,
          ),
          child: customer.imageUrl != null && customer.imageUrl!.isNotEmpty
              ? Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                )
              : Center(
                  child: Icon(
                    Icons.home_outlined,
                    size: 100,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
        ),

        // Content
        Positioned(
          bottom: 24,
          right: 24, // Assuming RTL, photo on the right
          left: 24,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              // Photo
              GestureDetector(
                onTap: _isUpdatingPhoto ? null : _showPhotoPicker,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppTheme.surfaceContainerLowest, width: 4),
                    color: AppTheme.surfaceContainerHighest,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _isUpdatingPhoto
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : (customer.imageUrl != null && customer.imageUrl!.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: customer.imageUrl!,
                              fit: BoxFit.cover,
                            )
                          : Center(
                              child: Text(
                                customer.cardName.isNotEmpty
                                    ? customer.cardName[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.assistant(
                                  color: AppTheme.secondary,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                ),
              ),
              const SizedBox(width: 20),

              // Name and Badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      customer.cardName,
                      style: GoogleFonts.assistant(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: customer.imageUrl != null && customer.imageUrl!.isNotEmpty
                            ? Colors.white
                            : AppTheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        if (isVip)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700)
                                  .withValues(alpha: 0.2),
                              border:
                                  Border.all(color: const Color(0xFFFFD700)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(Icons.star,
                                    color: Color(0xFFFFD700), size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'V.I.P',
                                  style: GoogleFonts.assistant(
                                    color: const Color(0xFFFFD700),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (hasDebt)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(Icons.warning_amber_rounded,
                                    color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'חוב פתוח: ₪${customer.remainingDebt.toStringAsFixed(0)}',
                                  style: GoogleFonts.assistant(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Action Buttons Row (positioned to overlap bottom edge or just below)
        Positioned(
          top: 220,
          left: 24,
          right: 24,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              ElevatedButton.icon(
                onPressed: onEditDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.surfaceContainerLowest,
                  foregroundColor: AppTheme.onSurface,
                  elevation: 2,
                  shadowColor: Colors.black.withValues(alpha: 0.1),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                        color: AppTheme.outlineVariant.withValues(alpha: 0.2)),
                  ),
                ),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(
                  'עריכת פרטים',
                  style: GoogleFonts.assistant(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: onSendReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: AppTheme.success.withValues(alpha: 0.3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: Text(
                  'שליחת דוח',
                  style: GoogleFonts.assistant(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => showPaymentDialog(context, ref, l10n,
                    initialCustomer: customer),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondary,
                  foregroundColor: AppTheme.onSecondary,
                  elevation: 2,
                  shadowColor: AppTheme.secondary.withValues(alpha: 0.3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.payment_rounded, size: 18),
                label: Text(
                  'תשלום חדש',
                  style: GoogleFonts.assistant(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: onNewOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.onPrimary,
                  elevation: 2,
                  shadowColor: AppTheme.primary.withValues(alpha: 0.3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  'הזמנה חדשה',
                  style: GoogleFonts.assistant(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Contact Info Card ───────────────────────────────────────────────────────

class _ContactInfoCard extends StatelessWidget {
  final Customer customer;
  final AppLocalizations? l10n;

  const _ContactInfoCard({required this.customer, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return _SidebarCard(
      title: 'פרטי התקשרות',
      icon: Icons.contact_page_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ContactRow(
            icon: Icons.person_outline,
            text: customer.customerName,
            onTap: () {},
          ),
          if (customer.phones.isNotEmpty) const SizedBox(height: 16),
          if (customer.phones.isNotEmpty)
            _ContactRow(
              icon: Icons.phone_outlined,
              text: customer.phones.join(', '),
              onTap: () {
                // TODO: url launcher tel:
              },
            ),
          if (customer.phones.isNotEmpty) const SizedBox(height: 16),
          if (customer.location != null && customer.location!.isNotEmpty)
            _ContactRow(
              icon: Icons.location_on_outlined,
              text: customer.location!,
              onTap: () {
                // TODO: maps
              },
            ),
          // Email omitted because customer model doesn't explicitly have email yet, but could be added
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _ContactRow(
      {required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 20, color: AppTheme.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.assistant(
                  fontSize: 15,
                  color: AppTheme.onSurface,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Notes Card ─────────────────────────────────────────────────────────────

class _NotesCard extends StatelessWidget {
  final String notes;
  final AppLocalizations? l10n;

  const _NotesCard({required this.notes, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return _SidebarCard(
      title: 'הערות מערכת',
      icon: Icons.note_outlined,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.warning.withValues(alpha: 0.2)),
        ),
        child: Text(
          notes,
          style: GoogleFonts.assistant(
            fontSize: 14,
            color: AppTheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _SidebarCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SidebarCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.15)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(26, 28, 28, 0.04),
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 20, color: AppTheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.assistant(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

// ─── Orders List Section ────────────────────────────────────────────────────

class _OrdersListSection extends StatelessWidget {
  final AsyncValue<List<Order>> ordersAsync;
  final AppLocalizations? l10n;

  const _OrdersListSection({required this.ordersAsync, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'היסטוריית הזמנות',
                  style: GoogleFonts.assistant(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(width: 12),
                ordersAsync.when(
                  data: (orders) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      orders.length.toString(),
                      style: GoogleFonts.assistant(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
              ],
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                'צפה בכולם',
                style: GoogleFonts.assistant(
                  color: AppTheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppTheme.outlineVariant.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ordersAsync.when(
            data: (orders) {
              if (orders.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'אין הזמנות ללקוח זה',
                      style: GoogleFonts.assistant(
                        color: AppTheme.onSurfaceVariant,
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orders.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: AppTheme.outlineVariant.withValues(alpha: 0.15),
                ),
                itemBuilder: (context, index) {
                  return _OrderRow(order: orders[index]);
                },
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text('שגיאה בטעינת הזמנות: $e')),
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderRow extends StatelessWidget {
  final Order order;

  const _OrderRow({required this.order});

  String _getStatusName(OrderStatus status) {
    switch (status) {
      case OrderStatus.active:
        return 'פתוחה';
      case OrderStatus.preparing:
        return 'בהכנה';
      case OrderStatus.inAssembly:
        return 'בהרכבה';
      case OrderStatus.awaitingShipping:
        return 'ממתין למשלוח';
      case OrderStatus.handled:
        return 'טופל';
      case OrderStatus.delivered:
        return 'סופקה';
      case OrderStatus.canceled:
        return 'בוטלה';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDelivered = order.status == OrderStatus.delivered;
    final statusColor = isDelivered ? AppTheme.success : AppTheme.warning;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderFormScreen(orderId: order.id),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: <Widget>[
            // Thumbnail Placeholder
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.inventory_2_outlined,
                  color: AppTheme.outline, size: 24),
            ),
            const SizedBox(width: 16),

            // Order details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'הזמנה #${order.orderNumber ?? order.id.substring(0, 6)}',
                    style: GoogleFonts.assistant(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${order.items.length} פריטים • ${order.createdAt.toString().split(' ').first}',
                    style: GoogleFonts.assistant(
                      fontSize: 13,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Status and Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '₪${order.totalPrice.toStringAsFixed(0)}',
                  style: GoogleFonts.assistant(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _getStatusName(order.status),
                    style: GoogleFonts.assistant(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Payments List Section ──────────────────────────────────────────────────

class _PaymentsListSection extends StatelessWidget {
  final AsyncValue<List<Payment>> paymentsAsync;
  final AppLocalizations? l10n;

  const _PaymentsListSection({required this.paymentsAsync, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'פעילות תשלומים אחרונה',
              style: GoogleFonts.assistant(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                'צפה בכולם',
                style: GoogleFonts.assistant(
                  color: AppTheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppTheme.outlineVariant.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: paymentsAsync.when(
            data: (payments) {
              if (payments.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'אין תשלומים ללקוח זה',
                      style: GoogleFonts.assistant(
                        color: AppTheme.onSurfaceVariant,
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: payments.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: AppTheme.outlineVariant.withValues(alpha: 0.15),
                ),
                itemBuilder: (context, index) {
                  return _PaymentRow(payment: payments[index]);
                },
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text('שגיאה בטעינת תשלומים: $e')),
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final Payment payment;

  const _PaymentRow({required this.payment});

  @override
  Widget build(BuildContext context) {
    IconData typeIcon = Icons.payment;
    if (payment.type == PaymentType.credit) {
      typeIcon = Icons.credit_card;
    } else if (payment.type == PaymentType.cash) {
      typeIcon = Icons.attach_money;
    } else if (payment.type == PaymentType.check) {
      typeIcon = Icons.receipt_long;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(typeIcon, color: AppTheme.success, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  payment.type.dbValue,
                  style: GoogleFonts.assistant(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  payment.date.toString().split(' ').first,
                  style: GoogleFonts.assistant(
                    fontSize: 13,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+ ₪${payment.amount.toStringAsFixed(0)}',
            style: GoogleFonts.assistant(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.success,
            ),
          ),
        ],
      ),
    );
  }
}
