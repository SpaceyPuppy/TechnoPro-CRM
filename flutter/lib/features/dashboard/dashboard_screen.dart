import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/providers/layout_provider.dart';
import '../../shared/models/models.dart';
import '../../shared/models/enums.dart';
import '../../shared/widgets/error_view.dart';
import 'dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.read(dashboardProvider.notifier).refresh(),
        ),
        data: (stats) => RefreshIndicator(
          onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: _DashboardContent(stats: stats),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isTouch = ref.watch(touchModeProvider);
    final tier = layoutTier(width, isTouch);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatsGrid(stats: stats, tier: tier),
        const SizedBox(height: 16),
        _StatusBreakdownCard(stats: stats),
        if (stats.myTickets != null && stats.myTickets!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _MyTicketsCard(tickets: stats.myTickets!),
        ],
        const SizedBox(height: 16),
        _RecentActivityCard(events: stats.recentEvents),
        const SizedBox(height: 16),
      ],
    );
  }
}

// --- Stats Grid ---

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats, required this.tier});

  final DashboardStats stats;
  final LayoutTier tier;

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = tier == LayoutTier.desktop ? 4 : 2;
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    final cards = [
      _StatCardData(
        icon: Icons.confirmation_number_outlined,
        label: 'Active Tickets',
        value: stats.activeCount.toString(),
        color: null,
      ),
      _StatCardData(
        icon: Icons.warning_amber_outlined,
        label: 'Overdue',
        value: stats.overdueCount.toString(),
        color: stats.overdueCount > 0 ? colorScheme.error : null,
      ),
      _StatCardData(
        icon: Icons.calendar_today_outlined,
        label: 'New Today',
        value: stats.todayNewTickets.toString(),
        color: null,
      ),
      _StatCardData(
        icon: Icons.payments_outlined,
        label: "Today's Revenue",
        value: currencyFmt.format(double.tryParse(stats.todayRevenue) ?? 0.0),
        color: null,
      ),
    ];

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: tier == LayoutTier.desktop ? 2.2 : 1.6,
      children: cards.map((c) => _StatCard(data: c)).toList(),
    );
  }
}

class _StatCardData {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _StatCardData({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});

  final _StatCardData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(data.icon, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.label,
                    style: textTheme.labelMedium?.copyWith(color: colorScheme.outline),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              data.value,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: data.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Status Breakdown ---

class _StatusBreakdownCard extends StatelessWidget {
  const _StatusBreakdownCard({required this.stats});

  final DashboardStats stats;

  static const _statusOrder = [
    TicketStatus.open,
    TicketStatus.inProgress,
    TicketStatus.waitingParts,
    TicketStatus.waitingCustomer,
    TicketStatus.resolved,
    TicketStatus.closed,
    TicketStatus.cancelled,
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tickets by Status',
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ..._statusOrder.map((s) {
              final count = stats.countForStatus(s.value);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(s.label,
                            style: textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant))),
                    Text(
                      count.toString(),
                      style: textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// --- My Tickets ---

class _MyTicketsCard extends StatelessWidget {
  const _MyTicketsCard({required this.tickets});

  final List<TicketModel> tickets;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Tickets',
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...tickets.map((t) => InkWell(
                  onTap: () => context.go('/tickets/${t.id}'),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Text(
                          t.ticketNumber,
                          style: textTheme.labelMedium?.copyWith(
                            fontFamily: 'monospace',
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            t.summary,
                            style: textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(t.status.label),
                          labelStyle: textTheme.labelSmall,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// --- Recent Activity ---

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.events});

  final List<DashboardRecentEvent> events;

  String _formatAge(String iso) {
    final diff = DateTime.now().difference(DateTime.parse(iso));
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatEventType(String type) => switch (type) {
        'status_change' => 'Status changed',
        'note' => 'Note added',
        'assignment' => 'Assigned',
        'system' => 'System',
        _ => type,
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Activity',
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (events.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('No recent activity',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.outline)),
              )
            else
              ...events.map((e) => InkWell(
                    onTap: () => context.go('/tickets/${e.ticketId}'),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 56,
                            child: Text(
                              _formatAge(e.createdAt),
                              style: textTheme.labelSmall
                                  ?.copyWith(color: colorScheme.outline),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      e.ticketNumber,
                                      style: textTheme.labelMedium?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '· ${_formatEventType(e.eventType)}',
                                      style: textTheme.labelMedium?.copyWith(
                                          color: colorScheme.outline),
                                    ),
                                  ],
                                ),
                                if (e.content != null && e.content!.isNotEmpty)
                                  Text(
                                    e.content!,
                                    style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
