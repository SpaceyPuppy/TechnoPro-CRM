import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/providers/layout_provider.dart';
import '../../shared/models/models.dart';
import '../../shared/models/enums.dart';
import '../../shared/widgets/error_view.dart';
import 'dashboard_provider.dart';
import 'dashboard_preferences.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(dashboardProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
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
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Customize dashboard',
            onPressed: () => _showDashboardCustomize(context, ref),
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

    final order = ref.watch(dashboardLayoutProvider);
    final sections = <String, Widget>{
      'overview': Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatsGrid(stats: stats, tier: tier),
          const SizedBox(height: 12),
          const _QuickActionStrip(),
        ],
      ),
      'status': _StatusBreakdownCard(stats: stats),
      'mine': stats.myTickets != null && stats.myTickets!.isNotEmpty
          ? _MyTicketsCard(tickets: stats.myTickets!)
          : const SizedBox.shrink(),
      'activity': _RecentActivityCard(events: stats.recentEvents),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final section in order) ...[
          sections[section]!,
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _QuickActionStrip extends StatelessWidget {
  const _QuickActionStrip();

  @override
  Widget build(BuildContext context) {
    final actions = <(IconData, String, String)>[
      (Icons.confirmation_number_outlined, 'Tickets', '/tickets'),
      (Icons.add_circle_outline, 'New ticket', '/tickets/new'),
      (Icons.people_outline, 'Customers', '/customers'),
      (Icons.inventory_2_outlined, 'Inventory', '/inventory'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: actions.map((action) => ActionChip(
            avatar: Icon(action.$1, size: 18),
            label: Text(action.$2),
            onPressed: () => context.go(action.$3),
          )).toList(),
        ),
      ),
    );
  }
}

void _showDashboardCustomize(BuildContext context, WidgetRef ref) {
  final labels = <String, String>{
    'overview': 'Overview metrics',
    'status': 'Tickets by status',
    'mine': 'My tickets',
    'activity': 'Recent activity',
  };
  final sections = [...ref.read(dashboardLayoutProvider)];
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (_, setSheetState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customize dashboard', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...sections.asMap().entries.map((entry) => ListTile(
                leading: const Icon(Icons.drag_indicator),
                title: Text(labels[entry.value]!),
                trailing: Wrap(
                  children: [
                    IconButton(icon: const Icon(Icons.keyboard_arrow_up), tooltip: 'Move up', onPressed: entry.key == 0 ? null : () => setSheetState(() { final item = sections.removeAt(entry.key); sections.insert(entry.key - 1, item); })),
                    IconButton(icon: const Icon(Icons.keyboard_arrow_down), tooltip: 'Move down', onPressed: entry.key == sections.length - 1 ? null : () => setSheetState(() { final item = sections.removeAt(entry.key); sections.insert(entry.key + 1, item); })),
                  ],
                ),
              )),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(onPressed: () => setSheetState(() { sections..clear()..addAll(['overview', 'status', 'mine', 'activity']); }), child: const Text('Reset')),
                  const Spacer(),
                  FilledButton(onPressed: () { ref.read(dashboardLayoutProvider.notifier).save(sections); Navigator.pop(sheetContext); }, child: const Text('Save layout')),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// --- Stats Grid ---

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats, required this.tier});

  final DashboardStats stats;
  final LayoutTier tier;

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = tier == LayoutTier.desktop ? 3 : 2;
    final currencyFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    final cards = [
      _StatCardData(
        icon: Icons.confirmation_number_rounded,
        label: 'Active Tickets',
        value: stats.activeCount.toString(),
        iconColor: const Color(0xFF3B82F6),
        iconBg: const Color(0xFFEFF6FF),
      ),
      _StatCardData(
        icon: Icons.warning_amber_rounded,
        label: 'Overdue',
        value: stats.overdueCount.toString(),
        iconColor: const Color(0xFFEF4444),
        iconBg: const Color(0xFFFEF2F2),
      ),
      _StatCardData(
        icon: Icons.person_off_outlined,
        label: 'Unassigned',
        value: stats.unassignedCount.toString(),
        iconColor: const Color(0xFFF97316),
        iconBg: const Color(0xFFFFF7ED),
      ),
      _StatCardData(
        icon: Icons.timer_off_outlined,
        label: 'Unbilled Work',
        value: stats.unbilledCount.toString(),
        iconColor: const Color(0xFF0F766E),
        iconBg: const Color(0xFFF0FDFA),
      ),
      _StatCardData(
        icon: Icons.add_circle_rounded,
        label: 'New Today',
        value: stats.todayNewTickets.toString(),
        iconColor: const Color(0xFF10B981),
        iconBg: const Color(0xFFECFDF5),
      ),
      _StatCardData(
        icon: Icons.payments_rounded,
        label: "Today's Revenue",
        value: currencyFmt.format(double.tryParse(stats.todayRevenue) ?? 0.0),
        iconColor: const Color(0xFF8B5CF6),
        iconBg: const Color(0xFFF5F3FF),
      ),
    ];

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: tier == LayoutTier.desktop ? 3.6 : 2.5,
      children: cards.map((c) => _StatCard(data: c)).toList(),
    );
  }
}

class _StatCardData {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final Color iconBg;

  const _StatCardData({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    required this.iconBg,
  });
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});

  final _StatCardData data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .7)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: data.iconColor.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: data.iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.label,
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  data.value,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Status Breakdown ---

class _StatusBreakdownCard extends StatelessWidget {
  const _StatusBreakdownCard({required this.stats});

  final DashboardStats stats;

  static const _mainStatuses = [
    TicketStatus.new_,
    TicketStatus.triage,
    TicketStatus.scheduled,
    TicketStatus.inProgress,
    TicketStatus.awaitingCustomer,
    TicketStatus.awaitingParts,
    TicketStatus.ready,
  ];

  static const _secondaryStatuses = [
    TicketStatus.resolved,
    TicketStatus.closed,
    TicketStatus.cancelled,
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tickets by Status',
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            // Main status cards (2x2 grid)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.0,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                ..._mainStatuses.map((status) {
                  final count = stats.countForStatus(status.value);
                  return _CompactStatusCard(
                    status: status,
                    count: count,
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),
            // Secondary statuses (3 across)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ..._secondaryStatuses.map((status) {
                  final count = stats.countForStatus(status.value);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _CompactStatusCard(
                        status: status,
                        count: count,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactStatusCard extends StatelessWidget {
  const _CompactStatusCard({
    required this.status,
    required this.count,
  });

  final TicketStatus status;
  final int count;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    
    return Container(
      decoration: BoxDecoration(
        color: status.bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: status.color,
            width: 3,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            status.label,
            style: textTheme.labelSmall?.copyWith(
              color: status.color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            count.toString(),
            style: textTheme.titleSmall?.copyWith(
              color: status.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
