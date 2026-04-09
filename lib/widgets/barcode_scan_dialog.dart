import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';

class BarcodeScanDialog extends StatefulWidget {
  const BarcodeScanDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (_) => const BarcodeScanDialog(),
    );
  }

  @override
  State<BarcodeScanDialog> createState() => _BarcodeScanDialogState();
}

class _BarcodeScanDialogState extends State<BarcodeScanDialog> {
  bool _handled = false;

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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (kIsWeb) {
      return AlertDialog(
        backgroundColor: AppTheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
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
        content: Text(
          _trOrLocale(
            context,
            l10n,
            'barcodeScanNotSupportedWeb',
            en: 'Barcode scanning requires a device camera (not supported in this build).',
            he: 'סריקת ברקוד דורשת מצלמה (לא נתמך בגרסת ווב).',
            ar: 'مسح الباركود يتطلب كاميرا (غير مدعوم على الويب).',
          ),
          style: GoogleFonts.assistant(
            color: AppTheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n?.tr('cancel') ?? 'Cancel'),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: AppTheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
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
      content: SizedBox(
        width: 560,
        height: 360,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                onDetect: (capture) {
                  if (_handled) return;
                  final barcodes = capture.barcodes;
                  final raw = barcodes.isNotEmpty ? barcodes.first.rawValue : null;
                  if (raw == null || raw.trim().isEmpty) return;
                  _handled = true;
                  Navigator.pop(context, raw.trim());
                },
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    _trOrLocale(
                      context,
                      l10n,
                      'scanBarcodeHint',
                      en: 'Point the camera at a barcode',
                      he: 'כוון את המצלמה לברקוד',
                      ar: 'وجّه الكاميرا نحو الباركود',
                    ),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.assistant(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n?.tr('cancel') ?? 'Cancel'),
        ),
      ],
    );
  }
}

