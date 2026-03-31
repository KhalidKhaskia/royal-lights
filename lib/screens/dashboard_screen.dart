import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_animations.dart';
import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../widgets/editorial_screen_title.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final openOrders = ref.watch(openOrdersCountProvider);
    final upcomingAssemblies = ref.watch(upcomingAssembliesCountProvider);
    final totalDebts = ref.watch(totalUnpaidDebtsProvider);
    final username = ref.watch(currentUsernameProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLowest,
      appBar: AppBar(
        toolbarHeight: 0,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppTheme.surfaceContainerLowest,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EditorialScreenTitle(
              title: l10n?.tr('dashboard') ?? 'Dashboard',
              trailing: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '${l10n?.tr('welcome') ?? 'Welcome'}, $username',
                  style: GoogleFonts.assistant(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: AnimatedFadeIn(
                duration: AppAnimations.durationMedium,
                slideUp: true,
                scaleBegin: 0.97,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats row
                    Row(
                children: [
                  Expanded(
                    child: AnimatedFadeIn(
                      delay: const Duration(milliseconds: 50),
                      child: _StatCard(
                    icon: Icons.shopping_cart_rounded,
                    title: l10n?.tr('openOrders') ?? 'Open Orders',
                    value: openOrders.when(
                      data: (v) => v.toString(),
                      loading: () => '...',
                      error: (_, __) => '!',
                    ),
                    color: AppTheme.primaryGold,
                    gradient: [
                      AppTheme.primaryGold,
                      AppTheme.primaryGold.withValues(alpha: 0.6),
                    ],
                  ),
                ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: AnimatedFadeIn(
                    delay: const Duration(milliseconds: 100),
                    child: _StatCard(
                    icon: Icons.build_rounded,
                    title:
                        l10n?.tr('upcomingAssemblies') ?? 'Upcoming Assemblies',
                    value: upcomingAssemblies.when(
                      data: (v) => v.toString(),
                      loading: () => '...',
                      error: (_, __) => '!',
                    ),
                    color: AppTheme.warning,
                    gradient: [
                      AppTheme.warning,
                      AppTheme.warning.withValues(alpha: 0.6),
                    ],
                  ),
                ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: AnimatedFadeIn(
                    delay: const Duration(milliseconds: 150),
                    child: _StatCard(
                    icon: Icons.account_balance_wallet_rounded,
                    title: l10n?.tr('totalUnpaidDebts') ?? 'Total Unpaid Debts',
                    value: totalDebts.when(
                      data: (v) => '₪${v.toStringAsFixed(2)}',
                      loading: () => '...',
                      error: (_, __) => '!',
                    ),
                    color: AppTheme.error,
                    gradient: [
                      AppTheme.error,
                      AppTheme.error.withValues(alpha: 0.6),
                    ],
                  ),
                ),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            // Quick actions row
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 200),
              child: Text(
                l10n?.tr('quickActions') ?? 'Quick actions',
                style: GoogleFonts.assistant(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AnimatedFadeIn(
                    delay: const Duration(milliseconds: 250),
                    child: _QuickActionCard(
                  icon: Icons.person_add_rounded,
                  label: l10n?.tr('newCustomer') ?? 'New Customer',
                  onTap: () =>
                      ref.read(selectedNavIndexProvider.notifier).setIndex(1),
                ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedFadeIn(
                    delay: const Duration(milliseconds: 300),
                    child: _QuickActionCard(
                  icon: Icons.add_shopping_cart_rounded,
                  label: l10n?.tr('newOrder') ?? 'New Order',
                  onTap: () =>
                      ref.read(selectedNavIndexProvider.notifier).setIndex(2),
                ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedFadeIn(
                    delay: const Duration(milliseconds: 350),
                    child: _QuickActionCard(
                  icon: Icons.payment_rounded,
                  label: l10n?.tr('newPayment') ?? 'New Payment',
                  onTap: () =>
                      ref.read(selectedNavIndexProvider.notifier).setIndex(3),
                ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // LLM Placeholder
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 400),
              child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.primaryGold.withValues(alpha: 0.1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryGold.withValues(alpha: 0.3),
                          AppTheme.accentBlue.withValues(alpha: 0.3),
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: AppTheme.primaryGold,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n?.tr('llmPlaceholder') ?? 'Future AI Integration Area',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chat assistant, analytics, and insights powered by AI',
                    style: TextStyle(
                      color: AppTheme.textSecondary.withValues(alpha: 0.6),
                      fontSize: 14,
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
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final List<Color> gradient;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(colors: gradient),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppTheme.primaryGold, size: 32),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
