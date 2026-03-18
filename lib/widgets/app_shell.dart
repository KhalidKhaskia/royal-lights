import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../config/app_theme.dart';
import '../screens/dashboard_screen.dart';
import '../screens/customers/customers_screen.dart';
import '../screens/orders/orders_screen.dart';
import '../screens/payments/payments_screen.dart';
import '../screens/assemblies/assemblies_screen.dart';
import '../screens/suppliers/suppliers_screen.dart';
import '../screens/fixing/fixing_screen.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedNavIndexProvider);
    final locale = ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context);

    final screens = [
      const DashboardScreen(),
      const CustomersScreen(),
      const OrdersScreen(),
      const FixingScreen(),
      const PaymentsScreen(),
      const AssembliesScreen(),
      const SuppliersScreen(),
    ];
    // Keys so AnimatedSwitcher can animate between screens
    final screenKeys = List.generate(screens.length, (i) => ValueKey<int>(i));

    final navItems = [
      _NavItem(Icons.dashboard_rounded, l10n?.tr('dashboard') ?? 'Dashboard'),
      _NavItem(Icons.people_rounded, l10n?.tr('customers') ?? 'Customers'),
      _NavItem(Icons.shopping_cart_rounded, l10n?.tr('orders') ?? 'Orders'),
      _NavItem(Icons.build_circle_outlined, l10n?.tr('fixing') ?? 'Fixing'),
      _NavItem(Icons.payment_rounded, l10n?.tr('payments') ?? 'Payments'),
      _NavItem(Icons.build_rounded, l10n?.tr('assemblies') ?? 'Assemblies'),
      _NavItem(
        Icons.local_shipping_rounded,
        l10n?.tr('suppliers') ?? 'Suppliers',
      ),
    ];

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 220,
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Logo / Brand
                Container(
                  height: 80,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryBlue, AppTheme.accentBlue],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryGold,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryGold.withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.light,
                          color: Colors.black,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Royal Light',
                          style: TextStyle(
                            color: AppTheme.primaryGold,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Navigation items
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    itemCount: navItems.length,
                    itemBuilder: (context, index) {
                      final isSelected = selectedIndex == index;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              ref
                                  .read(selectedNavIndexProvider.notifier)
                                  .setIndex(index);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: isSelected
                                    ? AppTheme.primaryGold.withValues(
                                        alpha: 0.15,
                                      )
                                    : Colors.transparent,
                                border: isSelected
                                    ? Border.all(
                                        color: AppTheme.primaryGold.withValues(
                                          alpha: 0.3,
                                        ),
                                        width: 1,
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    navItems[index].icon,
                                    color: isSelected
                                        ? AppTheme.primaryGold
                                        : AppTheme.textSecondary,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 14),
                                  Text(
                                    navItems[index].label,
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppTheme.primaryGold
                                          : AppTheme.textSecondary,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Language switcher
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _LanguageChip('עב', 'he', locale, ref),
                      _LanguageChip('عر', 'ar', locale, ref),
                      _LanguageChip('EN', 'en', locale, ref),
                    ],
                  ),
                ),
                // Logout
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final authService = ref.read(authServiceProvider);
                        await authService.signOut();
                      },
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: Text(l10n?.tr('logout') ?? 'Logout'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: const BorderSide(color: AppTheme.error),
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Main content with heavier cross-fade + subtle scale
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              switchInCurve: Curves.easeOutQuart,
              switchOutCurve: Curves.easeInQuart,
              transitionBuilder: (child, animation) {
                final scale = Tween<double>(begin: 0.98, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutQuart),
                );
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: scale,
                    alignment: Alignment.center,
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: screenKeys[selectedIndex],
                child: screens[selectedIndex],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _LanguageChip(
  String label,
  String code,
  Locale currentLocale,
  WidgetRef ref,
) {
  final isSelected = currentLocale.languageCode == code;
  return GestureDetector(
    onTap: () {
      ref.read(localeProvider.notifier).setLocale(Locale(code));
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isSelected
            ? AppTheme.primaryGold.withValues(alpha: 0.2)
            : AppTheme.surfaceLight,
        border: isSelected
            ? Border.all(color: AppTheme.primaryGold, width: 1.5)
            : Border.all(color: Colors.white10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppTheme.primaryGold : AppTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          fontSize: 13,
        ),
      ),
    ),
  );
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem(this.icon, this.label);
}
