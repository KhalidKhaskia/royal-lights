import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_animations.dart';
import '../../config/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/inventory_item.dart';
import '../../providers/providers.dart';
import '../../widgets/app_loading_overlay.dart';
import '../../widgets/app_dropdown_styles.dart';
import '../../widgets/editorial_screen_title.dart';
import '../../widgets/barcode_scan_dialog.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchCtrl = TextEditingController();

  int _gridCols(double width) {
    const minTileWidth = 185.0;
    const spacing = 14.0;
    final cols = ((width + spacing) / (minTileWidth + spacing)).floor();
    return cols.clamp(2, 4);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _trOrLocale(
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

  String _searchHint() {
    final l10n = AppLocalizations.of(context);
    final t = l10n?.tr('searchItemsHint');
    if (t != null && t.isNotEmpty && t != 'searchItemsHint') return t;
    return switch (Localizations.localeOf(context).languageCode) {
      'ar' => 'ابحث بالوصف، الماركة، الباركود…',
      'en' => 'Search by description, brand, barcode…',
      _ => 'חיפוש לפי תיאור, מותג, ברקוד…',
    };
  }

  Future<void> _openItemDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations? l10n, {
    InventoryItem? existing,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => InventoryItemDialog(
        ref: ref,
        l10n: l10n,
        existingItem: existing,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final itemsAsync = ref.watch(inventoryItemsProvider);
    final suppliersAsync = ref.watch(suppliersProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLowest,
      appBar: AppBar(
        toolbarHeight: 0,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppTheme.surfaceContainerLowest,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.secondary,
        foregroundColor: AppTheme.onPrimary,
        elevation: 2,
        onPressed: () => _openItemDialog(context, ref, l10n),
        tooltip: l10n?.tr('newItem') ?? 'New Item',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: itemsAsync.when(
        data: (items) {
          final suppliersById = <String, String>{
            for (final s in (suppliersAsync.value ?? const [])) s.id: s.companyName,
          };

          final q = _searchCtrl.text.trim().toLowerCase();
          final filtered = items.where((i) {
            if (q.isEmpty) return true;
            final desc = i.description.toLowerCase();
            final brand = (i.brand ?? '').toLowerCase();
            final barcode = (i.barcode ?? '').toLowerCase();
            return desc.contains(q) || brand.contains(q) || barcode.contains(q);
          }).toList();

          return SupplierNameCache(
            suppliersById: suppliersById,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      EditorialScreenTitle(
                        title: _trOrLocale(
                          context,
                          l10n,
                          'inventory',
                          en: 'Inventory',
                          he: 'מלאי',
                          ar: 'المخزون',
                        ),
                        padding: const EdgeInsets.only(
                          left: 32,
                          right: 32,
                          top: 28,
                          bottom: 6,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
                        child: Material(
                          elevation: 2,
                          shadowColor: Colors.black.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (_) => setState(() {}),
                            style: GoogleFonts.assistant(
                              color: AppTheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.auto,
                              floatingLabelAlignment:
                                  FloatingLabelAlignment.start,
                              labelText: _searchHint(),
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
                              suffixIcon: IconButton(
                                tooltip: _trOrLocale(
                                  context,
                                  l10n,
                                  'scanBarcode',
                                  en: 'Scan barcode',
                                  he: 'סריקת ברקוד',
                                  ar: 'مسح الباركود',
                                ),
                                icon: const Icon(Icons.qr_code_scanner_rounded),
                                color: AppTheme.secondary,
                                onPressed: () async {
                                  final code =
                                      await BarcodeScanDialog.show(context);
                                  if (!mounted || code == null) return;
                                  _searchCtrl.text = code;
                                  setState(() {});
                                },
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
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
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
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final cols = _gridCols(constraints.crossAxisExtent);
                        return SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            // Slightly taller cells so two-column details + price row fit on iPad without overflow.
                            childAspectRatio: 0.84,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = filtered[index];
                              return StaggeredFadeIn(
                                index: index,
                                stepMilliseconds: 55,
                                child: _InventoryItemCard(
                                  item: item,
                                  l10n: l10n,
                                  onTap: () => _openItemDialog(
                                    context,
                                    ref,
                                    l10n,
                                    existing: item,
                                  ),
                                ),
                              );
                            },
                            childCount: filtered.length,
                          ),
                        );
                      },
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 88)),
              ],
            ),
          );
        },
        loading: () => const AppLoadingOverlay(
          isLoading: true,
          child: SizedBox.expand(),
        ),
        error: (e, _) => Center(
          child: Text(
            '${l10n?.tr('error') ?? 'Error'}: $e',
            style: const TextStyle(color: AppTheme.error),
          ),
        ),
      ),
    );
  }
}

class _InventoryItemCard extends StatelessWidget {
  final InventoryItem item;
  final AppLocalizations? l10n;
  final VoidCallback onTap;

  const _InventoryItemCard({
    required this.item,
    required this.l10n,
    required this.onTap,
  });

  String _trOrLocale(BuildContext context, String key,
      {required String en, required String he, required String ar}) {
    final t = l10n?.tr(key) ?? '';
    if (t.isNotEmpty && t != key) return t;
    return switch (Localizations.localeOf(context).languageCode) {
      'he' => he,
      'ar' => ar,
      _ => en,
    };
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = item.imageUrl != null && item.imageUrl!.trim().isNotEmpty;
    final fallbackBannerColor = AppTheme.secondary;
    final suppliers = SupplierNameCache.of(context)?.suppliersById;

    final stockLabel = _trOrLocale(
      context,
      'availableStock',
      en: 'In stock',
      he: 'מלאי זמין',
      ar: 'متوفر',
    );

    final int warrantyYears = item.warrantyYears;
    final String? warrantyLabel = warrantyYears == 3
        ? _trOrLocale(
            context,
            'warranty3Years',
            en: '3 years',
            he: '3 שנים',
            ar: '3 سنوات',
          )
        : (warrantyYears == 5
            ? _trOrLocale(
                context,
                'warranty5Years',
                en: '5 years',
                he: '5 שנים',
                ar: '5 سنوات',
              )
            : null);

    final warrantyPrefix = _trOrLocale(
      context,
      'warranty',
      en: 'Warranty',
      he: 'אחריות',
      ar: 'الضمان',
    );

    final supplierName = (item.supplierId != null && suppliers != null)
        ? suppliers[item.supplierId!]
        : null;
    final brand = (item.brand ?? '').trim();
    final barcode = (item.barcode ?? '').trim();
    final weightedLabel = _trOrLocale(
      context,
      'weightedItem',
      en: 'Weighted item',
      he: 'פריט שקיל',
      ar: 'عنصر وزني',
    );
    final vatLabel = _trOrLocale(
      context,
      'vatExemptItem',
      en: 'VAT exempt',
      he: 'ללא מע״מ',
      ar: 'معفى من الضريبة',
    );

    String yesNo(bool v) {
      return switch (Localizations.localeOf(context).languageCode) {
        'ar' => v ? 'نعم' : 'لا',
        'en' => v ? 'Yes' : 'No',
        _ => v ? 'כן' : 'לא',
      };
    }

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
              SizedBox(
                height: 128,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    hasPhoto
                        ? CachedNetworkImage(
                            imageUrl: item.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: fallbackBannerColor),
                            errorWidget: (_, __, ___) =>
                                Container(color: fallbackBannerColor),
                          )
                        : Container(color: fallbackBannerColor),
                    Container(
                      color: Colors.black.withValues(alpha: 0.14),
                    ),
                    if (warrantyLabel != null)
                      PositionedDirectional(
                        top: 10,
                        start: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerLowest
                                .withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppTheme.outlineVariant
                                  .withValues(alpha: 0.22),
                            ),
                          ),
                          child: Text(
                            '$warrantyPrefix · $warrantyLabel',
                            style: GoogleFonts.assistant(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    PositionedDirectional(
                      bottom: 10,
                      start: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLowest
                              .withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppTheme.outlineVariant
                                .withValues(alpha: 0.22),
                          ),
                        ),
                        child: Text(
                          '$stockLabel · ${item.availableStock}',
                          style: GoogleFonts.assistant(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        item.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.assistant(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (supplierName != null &&
                                    supplierName.trim().isNotEmpty)
                                  _detailRow(
                                    context,
                                    label: _trOrLocale(
                                      context,
                                      'supplier',
                                      en: 'Supplier',
                                      he: 'ספק',
                                      ar: 'مورد',
                                    ),
                                    value: supplierName,
                                  ),
                                if (brand.isNotEmpty)
                                  _detailRow(
                                    context,
                                    label: _trOrLocale(
                                      context,
                                      'brand',
                                      en: 'Brand',
                                      he: 'חברה / מותג',
                                      ar: 'شركة / ماركة',
                                    ),
                                    value: brand,
                                  ),
                                if (barcode.isNotEmpty)
                                  _detailRow(
                                    context,
                                    label: _trOrLocale(
                                      context,
                                      'barcode',
                                      en: 'Barcode',
                                      he: 'ברקוד',
                                      ar: 'باركود',
                                    ),
                                    value: barcode,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _detailRow(
                                  context,
                                  label: _trOrLocale(
                                    context,
                                    'availableStock',
                                    en: 'Available stock',
                                    he: 'מלאי זמין',
                                    ar: 'المخزون المتاح',
                                  ),
                                  value: item.availableStock.toString(),
                                  valueColor: item.availableStock < 3
                                      ? AppTheme.error
                                      : AppTheme.success,
                                  valueAsPill: true,
                                ),
                                _detailRow(
                                  context,
                                  label: weightedLabel,
                                  value: yesNo(item.isWeighted),
                                ),
                                _detailRow(
                                  context,
                                  label: vatLabel,
                                  value: yesNo(item.isVatExempt),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Divider(
                        height: 1,
                        color: AppTheme.outlineVariant.withValues(alpha: 0.15),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.consumerPrice == null
                                ? '-'
                                : '₪${item.consumerPrice!.toStringAsFixed(2)}',
                            style: GoogleFonts.assistant(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.onSurface,
                            ),
                          ),
                          Wrap(
                            spacing: 6,
                            children: [
                              if (item.isWeighted)
                                _chip(
                                  context,
                                  label: _trOrLocale(
                                    context,
                                    'weightedItem',
                                    en: 'Weighted',
                                    he: 'שקיל',
                                    ar: 'وزني',
                                  ),
                                ),
                              if (item.isVatExempt)
                                _chip(
                                  context,
                                  label: _trOrLocale(
                                    context,
                                    'vatExemptItem',
                                    en: 'No VAT',
                                    he: 'ללא מע״מ',
                                    ar: 'بدون ضريبة',
                                  ),
                                ),
                            ],
                          ),
                        ],
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

  Widget _chip(BuildContext context, {required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppTheme.secondary.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.assistant(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppTheme.secondary,
        ),
      ),
    );
  }

  Widget _detailRow(
    BuildContext context, {
    required String label,
    required String value,
    Color? valueColor,
    bool valueAsPill = false,
  }) {
    final labelStyle = GoogleFonts.assistant(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppTheme.onSurfaceVariant,
    );
    final valueStyle = GoogleFonts.assistant(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: valueColor ?? AppTheme.onSurface,
    );

    Widget valueWidget = Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: valueStyle,
      textAlign: TextAlign.start,
    );

    if (valueAsPill && valueColor != null) {
      valueWidget = Container(
        constraints: const BoxConstraints(minHeight: 24, maxHeight: 24),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: valueColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: valueColor.withValues(alpha: 0.30),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: valueStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SizedBox(
        height: 24,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 62),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '$label:',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: valueWidget,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InventoryItemDialog extends StatefulWidget {
  final WidgetRef ref;
  final AppLocalizations? l10n;
  final InventoryItem? existingItem;

  const InventoryItemDialog({
    super.key,
    required this.ref,
    required this.l10n,
    this.existingItem,
  });

  @override
  State<InventoryItemDialog> createState() => _InventoryItemDialogState();
}

class _InventoryItemDialogState extends State<InventoryItemDialog> {
  final _descCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();

  Uint8List? _pickedImageBytes;
  bool _deleteExistingPhoto = false;
  bool _isWeighted = false;
  bool _isVatExempt = false;
  int _warrantyYears = 0;
  String? _supplierId;
  bool _saving = false;

  String _trOrLocale(
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

  @override
  void initState() {
    super.initState();
    final e = widget.existingItem;
    if (e != null) {
      _descCtrl.text = e.description;
      _brandCtrl.text = e.brand ?? '';
      _barcodeCtrl.text = e.barcode ?? '';
      _priceCtrl.text = e.consumerPrice?.toStringAsFixed(2) ?? '';
      _stockCtrl.text = e.availableStock.toString();
      _isWeighted = e.isWeighted;
      _isVatExempt = e.isVatExempt;
      _supplierId = e.supplierId;
      _warrantyYears = e.warrantyYears;
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _brandCtrl.dispose();
    _barcodeCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _showPhotoPicker() async {
    final l10n = widget.l10n;
    final hasExisting =
        widget.existingItem?.imageUrl != null && !_deleteExistingPhoto;
    final hasPicked = _pickedImageBytes != null;

    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(
          _trOrLocale(
            context,
            l10n,
            'selectImageSource',
            en: 'Select Image Source',
            he: 'בחר מקור תמונה',
            ar: 'اختر مصدر الصورة',
          ),
          style: GoogleFonts.assistant(fontWeight: FontWeight.bold),
        ),
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.camera_alt_outlined, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    _trOrLocale(
                      context,
                      l10n,
                      'camera',
                      en: 'Camera',
                      he: 'מצלמה',
                      ar: 'الكاميرا',
                    ),
                    style: GoogleFonts.assistant(fontSize: 16),
                  ),
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
                  Text(
                    _trOrLocale(
                      context,
                      l10n,
                      'gallery',
                      en: 'Gallery',
                      he: 'גלריה',
                      ar: 'المعرض',
                    ),
                    style: GoogleFonts.assistant(fontSize: 16),
                  ),
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
                    Text(
                      _trOrLocale(
                        context,
                        l10n,
                        'deletePhoto',
                        en: 'Delete Photo',
                        he: 'מחק תמונה',
                        ar: 'حذف الصورة',
                      ),
                      style: GoogleFonts.assistant(
                        fontSize: 16,
                        color: AppTheme.error,
                      ),
                    ),
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
    final l10n = widget.l10n;
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.tr('error') ?? 'Error')),
      );
      return;
    }
    if (_supplierId == null || _supplierId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _trOrLocale(
              context,
              l10n,
              'pleaseSelectSupplier',
              en: 'Please select a supplier',
              he: 'נא לבחור ספק',
              ar: 'يرجى اختيار مورد',
            ),
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    int parseStock(String raw) {
      final v = int.tryParse(raw.trim());
      return v == null ? 0 : v.clamp(0, 1 << 30);
    }

    double? parsePrice(String raw) {
      final t = raw.trim().replaceAll(',', '.');
      if (t.isEmpty) return null;
      return double.tryParse(t);
    }

    String cacheBustedUrl(String url) {
      final ts = DateTime.now().millisecondsSinceEpoch.toString();
      try {
        final uri = Uri.parse(url);
        final qp = Map<String, String>.from(uri.queryParameters);
        qp['v'] = ts;
        return uri.replace(queryParameters: qp).toString();
      } catch (_) {
        return '$url?v=$ts';
      }
    }

    setState(() => _saving = true);
    try {
      final stock = parseStock(_stockCtrl.text);
      final price = parsePrice(_priceCtrl.text);

      if (widget.existingItem == null) {
        var created = await widget.ref.read(inventoryServiceProvider).create(
              InventoryItem(
                id: '',
                description: desc,
                supplierId: _supplierId,
                brand: _brandCtrl.text.trim().isEmpty
                    ? null
                    : _brandCtrl.text.trim(),
                barcode: _barcodeCtrl.text.trim().isEmpty
                    ? null
                    : _barcodeCtrl.text.trim(),
                consumerPrice: price,
                availableStock: stock,
                isWeighted: _isWeighted,
                isVatExempt: _isVatExempt,
                warrantyYears: _warrantyYears,
              ),
            );

        if (_pickedImageBytes != null) {
          try {
            final url = await widget.ref
                .read(inventoryServiceProvider)
                .uploadPhoto(created.id, _pickedImageBytes!);
            final busted = cacheBustedUrl(url);
            created = created.copyWith(imageUrl: busted);
            await widget.ref
                .read(inventoryServiceProvider)
                .update(created.id, {'image_url': busted});
          } on StorageException catch (e) {
            if (!mounted) return;
            final msg = (e.message).toLowerCase();
            final looksLikeMissingBucket =
                msg.contains('bucket') && msg.contains('not found');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppTheme.error,
                content: Text(
                  looksLikeMissingBucket
                      ? _trOrLocale(
                          context,
                          l10n,
                          'inventoryPhotoBucketMissing',
                          en: 'Photo upload is not configured yet. Create the Supabase storage bucket "inventory-item-photos".',
                          he: 'העלאת תמונה עדיין לא מוגדרת. יש ליצור ב-Supabase את דלי האחסון "inventory-item-photos".',
                          ar: 'رفع الصورة غير مهيأ بعد. أنشئ سلة التخزين في Supabase باسم "inventory-item-photos".',
                        )
                      : '${l10n?.tr('error') ?? 'Error'}: ${e.message}',
                ),
              ),
            );
            // Keep the item (without photo) created; let the user fix bucket and edit later.
          }
        }
      } else {
        final id = widget.existingItem!.id;
        final updates = {
          'description': desc,
          'supplier_id': _supplierId,
          'brand': _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
          'barcode':
              _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
          'consumer_price': price,
          'available_stock': stock,
          'is_weighted': _isWeighted,
          'is_vat_exempt': _isVatExempt,
          'warranty_years': _warrantyYears,
        };
        await widget.ref.read(inventoryServiceProvider).update(id, updates);

        if (_pickedImageBytes != null) {
          try {
            final url = await widget.ref
                .read(inventoryServiceProvider)
                .uploadPhoto(id, _pickedImageBytes!);
            final busted = cacheBustedUrl(url);
            await widget.ref
                .read(inventoryServiceProvider)
                .update(id, {'image_url': busted});
          } on StorageException catch (e) {
            if (!mounted) return;
            final msg = (e.message).toLowerCase();
            final looksLikeMissingBucket =
                msg.contains('bucket') && msg.contains('not found');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppTheme.error,
                content: Text(
                  looksLikeMissingBucket
                      ? _trOrLocale(
                          context,
                          l10n,
                          'inventoryPhotoBucketMissing',
                          en: 'Photo upload is not configured yet. Create the Supabase storage bucket "inventory-item-photos".',
                          he: 'העלאת תמונה עדיין לא מוגדרת. יש ליצור ב-Supabase את דלי האחסון "inventory-item-photos".',
                          ar: 'رفع الصورة غير مهيأ بعد. أنشئ سلة التخزين في Supabase باسم "inventory-item-photos".',
                        )
                      : '${l10n?.tr('error') ?? 'Error'}: ${e.message}',
                ),
              ),
            );
          }
        } else if (_deleteExistingPhoto) {
          await widget.ref.read(inventoryServiceProvider).update(
            id,
            {'image_url': null},
          );
        }
      }

      widget.ref.invalidate(inventoryItemsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n?.tr('error') ?? 'Error'}: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final e = widget.existingItem;
    if (e == null) return;

    final l10n = widget.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n?.tr('delete') ?? 'Delete',
          style: GoogleFonts.assistant(fontWeight: FontWeight.w700),
        ),
        content: Text(
          _trOrLocale(
            context,
            l10n,
            'deleteItemConfirm',
            en: 'Delete "${e.description}"?',
            he: 'למחוק "${e.description}"?',
            ar: 'حذف "${e.description}"؟',
          ),
          style: GoogleFonts.assistant(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l10n?.tr('cancel') ?? 'Cancel',
              style: GoogleFonts.assistant(color: AppTheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text(
              l10n?.tr('delete') ?? 'Delete',
              style: GoogleFonts.assistant(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await widget.ref.read(inventoryServiceProvider).delete(e.id);
      widget.ref.invalidate(inventoryItemsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n?.tr('error') ?? 'Error'}: $err'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final isEdit = widget.existingItem != null;
    final hasExistingPhoto =
        widget.existingItem?.imageUrl != null && !_deleteExistingPhoto;
    final suppliersAsync = widget.ref.watch(suppliersProvider);

    return Dialog(
      backgroundColor: AppTheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: AppLoadingOverlay(
        isLoading: _saving,
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isEdit
                      ? _trOrLocale(
                          context,
                          l10n,
                          'editItem',
                          en: 'Edit item',
                          he: 'עריכת פריט',
                          ar: 'تعديل عنصر',
                        )
                      : _trOrLocale(
                          context,
                          l10n,
                          'newItem',
                          en: 'New item',
                          he: 'פריט חדש',
                          ar: 'عنصر جديد',
                        ),
                  style: GoogleFonts.assistant(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 18),
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
                    child: _pickedImageBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              _pickedImageBytes!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          )
                        : (hasExistingPhoto
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: widget.existingItem!.imageUrl!,
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
                              )),
                  ),
                ),
                const SizedBox(height: 18),
                _buildField(
                  controller: _descCtrl,
                  label: _trOrLocale(
                    context,
                    l10n,
                    'itemDescription',
                    en: 'Item description',
                    he: 'תיאור פריט',
                    ar: 'وصف العنصر',
                  ),
                  icon: Icons.description_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                suppliersAsync.when(
                  data: (suppliers) {
                    final entries = suppliers
                        .map(
                          (s) => DropdownMenuEntry<String>(
                            value: s.id,
                            label: s.companyName,
                          ),
                        )
                        .toList();

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return DropdownMenu<String>(
                          width: constraints.maxWidth,
                          initialSelection: _supplierId,
                          enabled: !_saving,
                          menuStyle: appDropdownMenuStyle(),
                          inputDecorationTheme: appDropdownInputDecorationTheme()
                              .copyWith(fillColor: Colors.white),
                          decorationBuilder: (context, controller) {
                            return animatedDropdownDecorationBuilder(
                              label: Text(
                                _trOrLocale(
                                  context,
                                  l10n,
                                  'supplier',
                                  en: 'Supplier',
                                  he: 'ספק',
                                  ar: 'مورد',
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              leadingIcon: dropdownLeadingSlot(
                                Icon(
                                  Icons.local_shipping_outlined,
                                  color: AppTheme.outline,
                                  size: 18,
                                ),
                              ),
                              iconSize: 18,
                            )(context, controller);
                          },
                          onSelected: (v) => setState(() => _supplierId = v),
                          dropdownMenuEntries: entries,
                        );
                      },
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                  error: (e, _) => Text(
                    '${l10n?.tr('error') ?? 'Error'}: $e',
                    style: GoogleFonts.assistant(color: AppTheme.error),
                  ),
                ),
                const SizedBox(height: 14),
                _buildField(
                  controller: _brandCtrl,
                  label: _trOrLocale(
                    context,
                    l10n,
                    'brand',
                    en: 'Brand / company',
                    he: 'חברה / מותג',
                    ar: 'شركة / ماركة',
                  ),
                  icon: Icons.storefront_outlined,
                ),
                const SizedBox(height: 14),
                _buildField(
                  controller: _barcodeCtrl,
                  label: _trOrLocale(
                    context,
                    l10n,
                    'barcode',
                    en: 'Barcode',
                    he: 'ברקוד',
                    ar: 'باركود',
                  ),
                  icon: Icons.qr_code_2_rounded,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () async {
                            final code = await BarcodeScanDialog.show(context);
                            if (!mounted || code == null) return;
                            setState(() => _barcodeCtrl.text = code);
                          },
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: Text(
                      _trOrLocale(
                        context,
                        l10n,
                        'scanBarcode',
                        en: 'Scan barcode',
                        he: 'סריקת ברקוד',
                        ar: 'مسح الباركود',
                      ),
                      style: GoogleFonts.assistant(fontWeight: FontWeight.w800),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.secondary,
                      side: BorderSide(
                        color: AppTheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownMenu<int>(
                  key: ValueKey('inv_warranty_${_warrantyYears}_${Localizations.localeOf(context).languageCode}'),
                  initialSelection: _warrantyYears,
                  enabled: !_saving,
                  menuStyle: appDropdownMenuStyle(),
                  inputDecorationTheme:
                      appDropdownInputDecorationTheme().copyWith(fillColor: Colors.white),
                  decorationBuilder: (context, controller) {
                    return animatedDropdownDecorationBuilder(
                      label: Text(
                        _trOrLocale(
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
                      leadingIcon: dropdownLeadingSlot(
                        Icon(
                          Icons.verified_outlined,
                          color: AppTheme.outline,
                          size: 18,
                        ),
                      ),
                      iconSize: 18,
                    )(context, controller);
                  },
                  onSelected: (v) => setState(() => _warrantyYears = v ?? 0),
                  dropdownMenuEntries: [
                    DropdownMenuEntry<int>(
                      value: 0,
                      label: _trOrLocale(
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
                      label: _trOrLocale(
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
                      label: _trOrLocale(
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        controller: _priceCtrl,
                        label: _trOrLocale(
                          context,
                          l10n,
                          'consumerPrice',
                          en: 'Consumer price',
                          he: 'מחיר לצרכן',
                          ar: 'سعر للمستهلك',
                        ),
                        icon: Icons.sell_outlined,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildField(
                        controller: _stockCtrl,
                        label: _trOrLocale(
                          context,
                          l10n,
                          'availableStock',
                          en: 'Available stock',
                          he: 'מלאי זמין',
                          ar: 'المخزون المتاح',
                        ),
                        icon: Icons.inventory_2_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile.adaptive(
                        value: _isWeighted,
                        onChanged: _saving ? null : (v) => setState(() => _isWeighted = v),
                        title: Text(
                          _trOrLocale(
                            context,
                            l10n,
                            'weightedItem',
                            en: 'Weighted item',
                            he: 'פריט שקיל',
                            ar: 'عنصر وزني',
                          ),
                          style: GoogleFonts.assistant(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SwitchListTile.adaptive(
                        value: _isVatExempt,
                        onChanged: _saving ? null : (v) => setState(() => _isVatExempt = v),
                        title: Text(
                          _trOrLocale(
                            context,
                            l10n,
                            'vatExemptItem',
                            en: 'VAT exempt',
                            he: 'ללא מע״מ',
                            ar: 'معفى من الضريبة',
                          ),
                          style: GoogleFonts.assistant(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isEdit)
                      TextButton(
                        onPressed: _saving ? null : _delete,
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          l10n?.tr('delete') ?? 'Delete',
                          style: GoogleFonts.assistant(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (isEdit) const SizedBox(width: 8),
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        l10n?.tr('cancel') ?? 'Cancel',
                        style: GoogleFonts.assistant(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: AppTheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        l10n?.tr('save') ?? 'Save',
                        style: GoogleFonts.assistant(fontWeight: FontWeight.w700),
                      ),
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: TextField(
        controller: controller,
        enabled: !_saving,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: GoogleFonts.assistant(fontSize: 14, color: AppTheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: AppTheme.onSurfaceVariant,
            fontSize: 13,
          ),
          prefixIcon: Icon(icon, size: 20, color: AppTheme.outline),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: AppTheme.outlineVariant.withValues(alpha: 0.25),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: AppTheme.outlineVariant.withValues(alpha: 0.25),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppTheme.secondary, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

/// Small helper so cards can show supplier names without ref access.
class SupplierNameCache extends InheritedWidget {
  final Map<String, String> suppliersById;

  const SupplierNameCache({
    super.key,
    required this.suppliersById,
    required super.child,
  });

  static SupplierNameCache? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SupplierNameCache>();
  }

  @override
  bool updateShouldNotify(SupplierNameCache oldWidget) =>
      suppliersById != oldWidget.suppliersById;
}

