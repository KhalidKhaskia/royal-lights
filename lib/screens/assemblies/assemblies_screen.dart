import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/order.dart';
import '../../providers/providers.dart';

class AssembliesScreen extends ConsumerWidget {
  const AssembliesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final assembliesAsync = ref.watch(assemblyOrdersProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLowest,
      appBar: AppBar(
        toolbarHeight: 0,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
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
                      l10n?.tr('assemblies') ?? 'Workshops',
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
            child: assembliesAsync.when(
              data: (orders) {
                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.build_outlined,
                          size: 80,
                          color: AppTheme.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n?.tr('noData') ?? 'No assemblies',
                          style: GoogleFonts.assistant(
                            color: AppTheme.onSurfaceVariant,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _AssemblyCard(order: order, l10n: l10n, ref: ref);
                  },
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
}

class _AssemblyCard extends StatelessWidget {
  final Order order;
  final AppLocalizations? l10n;
  final WidgetRef ref;

  const _AssemblyCard({
    required this.order,
    required this.l10n,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (order.status) {
      case OrderStatus.active:
        statusColor = AppTheme.success;
        break;
      case OrderStatus.preparing:
        statusColor = const Color(0xFF2196F3);
        break;
      case OrderStatus.inAssembly:
        statusColor = AppTheme.warning;
        break;
      case OrderStatus.awaitingShipping:
        statusColor = const Color(0xFF9C27B0);
        break;
      case OrderStatus.handled:
        statusColor = AppTheme.secondary;
        break;
      case OrderStatus.delivered:
        statusColor = AppTheme.success;
        break;
      case OrderStatus.canceled:
        statusColor = AppTheme.error;
        break;
    }

    // Calculate days until assembly
    final daysUntil = order.assemblyDate != null
        ? order.assemblyDate!.difference(DateTime.now()).inDays
        : null;
    final isUrgent = daysUntil != null && daysUntil <= 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isUrgent
              ? AppTheme.error.withValues(alpha: 0.5)
              : AppTheme.outlineVariant.withValues(alpha: 0.2),
          width: isUrgent ? 2 : 1,
        ),
        boxShadow: [
          if (isUrgent)
            BoxShadow(
              color: AppTheme.error.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          childrenPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          iconColor: AppTheme.onSurfaceVariant,
          collapsedIconColor: AppTheme.onSurfaceVariant,
          shape: const Border(), // remove inner border
          leading: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: statusColor.withValues(alpha: 0.1),
            ),
            child: Icon(Icons.build_rounded, color: statusColor, size: 28),
          ),
          title: Row(
            children: [
              Text(
                '#${order.orderNumber ?? '-'}',
                style: GoogleFonts.assistant(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.secondary,
                  fontSize: 18,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${order.cardName ?? ''} - ${order.customerName ?? ''}',
                style: GoogleFonts.assistant(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              // Assembly date
              if (order.assemblyDate != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isUrgent
                        ? AppTheme.error.withValues(alpha: 0.1)
                        : AppTheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: isUrgent ? AppTheme.error : AppTheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        order.assemblyDate!.toString().split(' ').first,
                        style: GoogleFonts.assistant(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isUrgent
                              ? AppTheme.error
                              : AppTheme.onSurfaceVariant,
                        ),
                      ),
                      if (daysUntil != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '(${daysUntil}d)',
                          style: GoogleFonts.assistant(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isUrgent
                                ? AppTheme.error
                                : AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(width: 16),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  order.status.dbValue,
                  style: GoogleFonts.assistant(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          children: [
            // Items list with opacity logic
            if (order.items.isNotEmpty) ...[
              Divider(color: AppTheme.outlineVariant.withValues(alpha: 0.2), thickness: 1, height: 32),
              ...order.items.map((item) {
                final isAssembly = item.assemblyRequired;
                return Opacity(
                  opacity: isAssembly ? 1.0 : 0.4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 20,
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isAssembly
                          ? AppTheme.secondary.withValues(alpha: 0.05)
                          : AppTheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: isAssembly
                          ? Border.all(
                              color: AppTheme.secondary.withValues(alpha: 0.2),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isAssembly
                              ? Icons.build_circle
                              : Icons.remove_circle_outline,
                          size: 22,
                          color: isAssembly
                              ? AppTheme.secondary
                              : AppTheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: Text(
                            item.name,
                            style: GoogleFonts.assistant(
                              fontWeight: isAssembly
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: AppTheme.onSurface,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: Text(
                            '${l10n?.tr('quantity') ?? 'Qty'}: ${item.quantity}',
                            style: GoogleFonts.assistant(
                              color: AppTheme.onSurfaceVariant,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (item.roomName != null)
                          SizedBox(
                            width: 120,
                            child: Text(
                              item.roomName!,
                              style: GoogleFonts.assistant(
                                color: AppTheme.onSurfaceVariant,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 24),
            // Status change buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  l10n?.tr('changeStatus') ?? 'Change Status:',
                  style: GoogleFonts.assistant(
                    color: AppTheme.onSurfaceVariant,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 16),
                if (order.status == OrderStatus.active)
                  ElevatedButton.icon(
                    onPressed: () => _changeStatus(context, order, 'In Assembly'),
                    icon: const Icon(Icons.build, size: 18),
                    label: Text(l10n?.tr('inAssembly') ?? 'In Assembly', style: GoogleFonts.assistant(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.warning,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                if (order.status == OrderStatus.inAssembly)
                  ElevatedButton.icon(
                    onPressed: () => _changeStatus(context, order, 'Handled'),
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: Text(l10n?.tr('handled') ?? 'Handled', style: GoogleFonts.assistant(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _changeStatus(
    BuildContext context,
    Order order,
    String newStatus,
  ) async {
    final username = ref.read(currentUsernameProvider);
    await ref
        .read(orderServiceProvider)
        .updateStatus(order.id, newStatus, username);
    ref.invalidate(assemblyOrdersProvider);
    ref.invalidate(ordersProvider);
  }
}
