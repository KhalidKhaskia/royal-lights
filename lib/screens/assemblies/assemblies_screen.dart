import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      appBar: AppBar(title: Text(l10n?.tr('assemblies') ?? 'Assemblies')),
      body: assembliesAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.build_outlined,
                    size: 80,
                    color: AppTheme.textSecondary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n?.tr('noData') ?? 'No assemblies',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
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
            style: const TextStyle(color: AppTheme.error),
          ),
        ),
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
        statusColor = AppTheme.primaryGold;
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgent
              ? AppTheme.error.withValues(alpha: 0.5)
              : Colors.white10,
          width: isUrgent ? 2 : 1,
        ),
        boxShadow: [
          if (isUrgent)
            BoxShadow(
              color: AppTheme.error.withValues(alpha: 0.15),
              blurRadius: 12,
            ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: statusColor.withValues(alpha: 0.15),
          ),
          child: Icon(Icons.build_rounded, color: statusColor, size: 24),
        ),
        title: Row(
          children: [
            Text(
              '#${order.orderNumber ?? '-'}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGold,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${order.cardName ?? ''} - ${order.customerName ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            // Assembly date
            if (order.assemblyDate != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isUrgent
                      ? AppTheme.error.withValues(alpha: 0.15)
                      : AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: isUrgent ? AppTheme.error : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      order.assemblyDate!.toString().split(' ').first,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isUrgent
                            ? AppTheme.error
                            : AppTheme.textSecondary,
                      ),
                    ),
                    if (daysUntil != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(${daysUntil}d)',
                        style: TextStyle(
                          fontSize: 11,
                          color: isUrgent
                              ? AppTheme.error
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(width: 12),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                order.status.dbValue,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        children: [
          // Items list with opacity logic
          if (order.items.isNotEmpty) ...[
            const Divider(),
            ...order.items.map((item) {
              final isAssembly = item.assemblyRequired;
              return Opacity(
                opacity: isAssembly ? 1.0 : 0.3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: isAssembly
                        ? AppTheme.primaryGold.withValues(alpha: 0.05)
                        : AppTheme.surfaceLight.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: isAssembly
                        ? Border.all(
                            color: AppTheme.primaryGold.withValues(alpha: 0.2),
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isAssembly
                            ? Icons.build_circle
                            : Icons.remove_circle_outline,
                        size: 18,
                        color: isAssembly
                            ? AppTheme.primaryGold
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontWeight: isAssembly
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          '${l10n?.tr('quantity') ?? 'Qty'}: ${item.quantity}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (item.roomName != null)
                        SizedBox(
                          width: 100,
                          child: Text(
                            item.roomName!,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 12),
          // Status change buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                l10n?.tr('changeStatus') ?? 'Change Status:',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 12),
              if (order.status == OrderStatus.active)
                ElevatedButton.icon(
                  onPressed: () => _changeStatus(context, order, 'In Assembly'),
                  icon: const Icon(Icons.build, size: 16),
                  label: Text(l10n?.tr('inAssembly') ?? 'In Assembly'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warning,
                    minimumSize: const Size(0, 44),
                  ),
                ),
              if (order.status == OrderStatus.inAssembly)
                ElevatedButton.icon(
                  onPressed: () => _changeStatus(context, order, 'Handled'),
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: Text(l10n?.tr('handled') ?? 'Handled'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    minimumSize: const Size(0, 44),
                  ),
                ),
            ],
          ),
        ],
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
