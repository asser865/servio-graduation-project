import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/bookings_api.dart';
import '../../core/models/booking_model.dart';
import '../../core/models/dispute.dart';
import '../../core/models/support_issue.dart';
import '../../core/state/support_provider.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_skeleton.dart';
import 'my_bookings_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Support Screen
// ─────────────────────────────────────────────────────────────────────────────

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupportProvider>().load();
    });
  }

  Future<void> _onRefresh() => context.read<SupportProvider>().refresh();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupportProvider>();
    final theme = Theme.of(context);
    final servio = context.servio;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        title: const Text('Support Cases'),
        actions: <Widget>[
          if (provider.refreshing)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: servio.accent,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: servio.accent,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _SupportHeader(provider: provider),
                    const SizedBox(height: 16),
                    _SupportSummaryGrid(provider: provider),
                    const SizedBox(height: 16),
                    _SupportTabBar(provider: provider),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            _SupportBody(provider: provider),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _SupportHeader extends StatelessWidget {
  const _SupportHeader({required this.provider});

  final SupportProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Track operational issues, payment disputes, and resolved support cases.',
          style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary grid — Open Issues / Open Disputes / Resolved Cases
// ─────────────────────────────────────────────────────────────────────────────

class _SupportSummaryGrid extends StatelessWidget {
  const _SupportSummaryGrid({required this.provider});

  final SupportProvider provider;

  @override
  Widget build(BuildContext context) {
    final loading = provider.loading;
    final stats = provider.stats;

    return Row(
      children: <Widget>[
        Expanded(
          child: _SupportSummaryCard(
            label: 'Open Issues',
            count: stats.openIssues,
            color: context.servio.warning,
            loading: loading,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SupportSummaryCard(
            label: 'Open Disputes',
            count: stats.openDisputes,
            color: context.servio.danger,
            loading: loading,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SupportSummaryCard(
            label: 'Resolved',
            count: stats.resolvedCases,
            color: context.servio.success,
            loading: loading,
          ),
        ),
      ],
    );
  }
}

class _SupportSummaryCard extends StatelessWidget {
  const _SupportSummaryCard({
    required this.label,
    required this.count,
    required this.color,
    required this.loading,
  });

  final String label;
  final int count;
  final Color color;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      radius: ServioRadius.md,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      child: Column(
        children: <Widget>[
          if (loading)
            ServioSkeleton(height: 24, width: 40, radius: ServioRadius.sm)
          else
            Text(
              '$count',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: servio.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab bar — Active / Disputes / Resolved
// ─────────────────────────────────────────────────────────────────────────────

class _SupportTabBar extends StatelessWidget {
  const _SupportTabBar({required this.provider});

  final SupportProvider provider;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    const tabs = <(SupportTab, String)>[
      (SupportTab.active, 'Active'),
      (SupportTab.disputes, 'Disputes'),
      (SupportTab.resolved, 'Resolved'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: servio.backgroundSoft,
        borderRadius: BorderRadius.circular(ServioRadius.md),
        border: Border.all(color: servio.border.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: <Widget>[
          for (final (tab, label) in tabs)
            Expanded(
              child: GestureDetector(
                onTap: () => provider.setTab(tab),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: provider.activeTab == tab
                        ? theme.cardColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(ServioRadius.sm),
                    boxShadow: provider.activeTab == tab
                        ? <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: provider.activeTab == tab
                          ? servio.accent
                          : servio.textSecondary,
                      fontWeight: provider.activeTab == tab
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body — delegates to skeleton / error / empty / list
// ─────────────────────────────────────────────────────────────────────────────

class _SupportBody extends StatelessWidget {
  const _SupportBody({required this.provider});

  final SupportProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.loading) {
      return const _SupportSkeletonList();
    }

    if (provider.error != null && !provider.loaded) {
      return SliverToBoxAdapter(
        child: _SupportErrorState(
          message: provider.error!,
          onRetry: () => provider.load(forceRefresh: true),
        ),
      );
    }

    final tab = provider.tabItems;

    // Filter duplicates by unique ID
    final seenIssues = <String>{};
    final uniqueIssues = <SupportIssue>[];
    for (final i in tab.issues) {
      if (i.id.isNotEmpty && !seenIssues.contains(i.id)) {
        seenIssues.add(i.id);
        uniqueIssues.add(i);
      }
    }

    final seenDisputes = <String>{};
    final uniqueDisputes = <Dispute>[];
    for (final d in tab.disputes) {
      if (d.id.isNotEmpty && !seenDisputes.contains(d.id)) {
        seenDisputes.add(d.id);
        uniqueDisputes.add(d);
      }
    }

    final issueWidgets = uniqueIssues
        .map((i) => _SupportIssueCard(issue: i))
        .toList();
    final disputeWidgets = uniqueDisputes
        .map((d) => _DisputeCard(dispute: d))
        .toList();

    final all = <Widget>[...issueWidgets, ...disputeWidgets];

    if (all.isEmpty) {
      return SliverToBoxAdapter(child: _SupportEmptyState(tab: provider.activeTab));
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: all[index],
            );
          },
          childCount: all.length,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Support Issue card
// ─────────────────────────────────────────────────────────────────────────────

class _SupportIssueCard extends StatelessWidget {
  const _SupportIssueCard({required this.issue});

  final SupportIssue issue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final statusColor = _issueStatusColor(issue.status, servio);

    return ServioCard(
      radius: ServioRadius.lg,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Status badge + type
          Row(
            children: <Widget>[
              _StatusBadge(label: issue.displayStatus, color: statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  issue.displayType,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: servio.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (issue.priority != 'normal')
                _PriorityBadge(priority: issue.priority),
            ],
          ),
          const SizedBox(height: 10),

          // Service
          Text(
            issue.displayService,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (issue.workerName != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              '${issue.workerName} · Opened ${_fmtDate(issue.createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
            ),
          ] else ...<Widget>[
            const SizedBox(height: 2),
            Text(
              'Opened ${_fmtDate(issue.createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
            ),
          ],

          const SizedBox(height: 8),

          // Description
          Text(
            issue.description,
            style: theme.textTheme.bodySmall,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

          // Resolution
          if (issue.resolution != null && issue.resolution!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: servio.success.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(ServioRadius.sm),
                border: Border.all(color: servio.success.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.check_circle_outline_rounded,
                      size: 14, color: servio.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      issue.resolution!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: servio.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Footer
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Icon(Icons.attach_file_rounded, size: 13, color: servio.textSecondary),
              const SizedBox(width: 4),
              Text(
                '${issue.evidence.length} file${issue.evidence.length == 1 ? '' : 's'}',
                style: theme.textTheme.labelSmall?.copyWith(color: servio.textSecondary),
              ),
              const Spacer(),
              if (issue.updatedAt != null)
                Text(
                  'Updated ${_fmtDate(issue.updatedAt!)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: servio.textSecondary,
                    fontSize: 10,
                  ),
                ),
            ],
          ),

          if (issue.bookingId.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _openBooking(context, issue.bookingId),
              icon: const Icon(Icons.receipt_long_outlined, size: 14),
              label: const Text('View Booking'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: const TextStyle(fontSize: 12),
                minimumSize: const Size(0, 32),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _issueStatusColor(String status, ServioThemeExtension servio) {
    return switch (status) {
      'open' => servio.warning,
      'reviewing' => servio.info,
      'waiting_customer' => servio.warning,
      'waiting_worker' => servio.info,
      'resolved' => servio.success,
      'closed' => servio.textSecondary,
      _ => servio.warning,
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dispute card
// ─────────────────────────────────────────────────────────────────────────────

class _DisputeCard extends StatefulWidget {
  const _DisputeCard({required this.dispute});

  final Dispute dispute;

  @override
  State<_DisputeCard> createState() => _DisputeCardState();
}

class _DisputeCardState extends State<_DisputeCard> {
  bool _expanded = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final statusColor = _disputeStatusColor(widget.dispute.status, servio);
    final statusLabel = _disputeStatusLabel(widget.dispute.status);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        setState(() {
          _expanded = !_expanded;
        });
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.fastOutSlowIn,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(ServioRadius.lg),
            border: Border.all(
              color: _expanded
                  ? statusColor.withValues(alpha: 0.5)
                  : servio.border.withValues(alpha: 0.3),
              width: _expanded ? 1.5 : 1.0,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _expanded
                    ? statusColor.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: _expanded ? 12 : 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Top Status Badge + Category Tag + Severity + Chevron Arrow
              Row(
                children: <Widget>[
                  _StatusBadge(label: 'Dispute · $statusLabel', color: statusColor),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: servio.backgroundSoft,
                      borderRadius: BorderRadius.circular(ServioRadius.full),
                      border: Border.all(color: servio.border.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _fmtCategory(widget.dispute.category),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: servio.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _SeverityBadge(severity: widget.dispute.severity),
                ],
              ),
              const SizedBox(height: 14),

              // Service Title and Circular Expand Chevron Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.dispute.serviceName != null && widget.dispute.serviceName!.isNotEmpty)
                          Text(
                            widget.dispute.serviceName!,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: -0.25,
                            ),
                          )
                        else
                          Text(
                            'Dispute #${widget.dispute.id.length > 8 ? widget.dispute.id.substring(widget.dispute.id.length - 8) : widget.dispute.id}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: -0.25,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 11, color: servio.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              'Opened ${_fmtDate(widget.dispute.createdAt)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: servio.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _expanded ? statusColor.withValues(alpha: 0.1) : servio.backgroundSoft,
                      shape: BoxShape.circle,
                    ),
                    child: AnimatedRotation(
                      turns: _expanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: _expanded ? statusColor : servio.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Short reason text (or fade out if collapsed)
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.fastOutSlowIn,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (!_expanded)
                      Text(
                        widget.dispute.reason,
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    else ...<Widget>[
                      // Full detailed view when expanded!
                      Text(
                        widget.dispute.reason,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Estimated Damages & Refund amounts info
                      if ((widget.dispute.estimatedDamages > 0) ||
                          (widget.dispute.refundAmount != null && widget.dispute.refundAmount! > 0)) ...<Widget>[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: servio.backgroundSoft,
                            borderRadius: BorderRadius.circular(ServioRadius.md),
                            border: Border.all(color: servio.border.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            children: <Widget>[
                              if (widget.dispute.estimatedDamages > 0)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Text(
                                      'Estimated Damages:',
                                      style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
                                    ),
                                    Text(
                                      '${widget.dispute.estimatedDamages.toStringAsFixed(0)} EGP',
                                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              if (widget.dispute.estimatedDamages > 0 && widget.dispute.refundAmount != null && widget.dispute.refundAmount! > 0)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 6),
                                  child: Divider(height: 1),
                                ),
                              if (widget.dispute.refundAmount != null && widget.dispute.refundAmount! > 0)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Icon(Icons.account_balance_wallet_outlined, size: 14, color: servio.info),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Refund Amount:',
                                          style: theme.textTheme.bodySmall?.copyWith(color: servio.info, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${widget.dispute.refundAmount!.toStringAsFixed(0)} EGP',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: servio.info,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Resolution block
                      if (widget.dispute.resolution != null && widget.dispute.resolution!.isNotEmpty) ...<Widget>[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: servio.success.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(ServioRadius.md),
                            border: Border.all(color: servio.success.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Icon(Icons.check_circle_outline_rounded, size: 16, color: servio.success),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Resolution Decision',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: servio.success,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.dispute.resolution!,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: servio.success,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Evidence attachments list
                      if (widget.dispute.evidence.isNotEmpty) ...<Widget>[
                        Text(
                          'Evidence Attachments (${widget.dispute.evidence.length})',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: servio.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 70,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: widget.dispute.evidence.length,
                            itemBuilder: (context, idx) {
                              final ev = widget.dispute.evidence[idx];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(ServioRadius.sm),
                                  child: Container(
                                    width: 70,
                                    height: 70,
                                    color: servio.backgroundSoft,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        if (ev.type == 'image' && ev.url.isNotEmpty)
                                          Image.network(
                                            ev.url,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 20),
                                          )
                                        else
                                          const Icon(Icons.insert_drive_file_outlined, size: 20),
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            color: Colors.black.withValues(alpha: 0.6),
                                            padding: const EdgeInsets.symmetric(vertical: 2),
                                            child: Text(
                                              ev.uploadedByRole.toUpperCase(),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Dispute Timeline / History!
                      if (widget.dispute.history.isNotEmpty) ...<Widget>[
                        Text(
                          'Dispute History',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: servio.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Column(
                          children: List.generate(widget.dispute.history.length, (idx) {
                            final hist = widget.dispute.history[idx];
                            final isLast = idx == widget.dispute.history.length - 1;
                            return IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  // Left line + dot
                                  Column(
                                    children: <Widget>[
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      if (!isLast)
                                        Expanded(
                                          child: Container(
                                            width: 2,
                                            color: servio.border.withValues(alpha: 0.5),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  // Right info
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: <Widget>[
                                              Text(
                                                hist.status.replaceAll('_', ' ').toUpperCase(),
                                                style: theme.textTheme.labelSmall?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 10,
                                                ),
                                              ),
                                              Text(
                                                _fmtDate(hist.at),
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: servio.textSecondary,
                                                  fontSize: 9,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'By ${hist.byRole.toUpperCase()} ${hist.byName != null ? '(${hist.byName})' : ''}',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: servio.textSecondary,
                                              fontSize: 10,
                                            ),
                                          ),
                                          if (hist.note != null && hist.note!.isNotEmpty) ...<Widget>[
                                            const SizedBox(height: 4),
                                            Text(
                                              hist.note!,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: servio.textSecondary,
                                                fontStyle: FontStyle.italic,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ],
                ),
              ),

              // Divider between content and footer if not expanded (expanded already has timelines)
              if (!_expanded) ...<Widget>[
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Icon(Icons.attach_file_rounded, size: 13, color: servio.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.dispute.evidence.length} file${widget.dispute.evidence.length == 1 ? '' : 's'}',
                      style: theme.textTheme.labelSmall?.copyWith(color: servio.textSecondary, fontSize: 10),
                    ),
                    const Spacer(),
                    if (widget.dispute.resolvedAt != null)
                      Text(
                        'Resolved ${_fmtDate(widget.dispute.resolvedAt!)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: servio.textSecondary,
                          fontSize: 9,
                        ),
                      )
                    else if (widget.dispute.slaResolveDueAt != null)
                      _SlaBadge(dueAt: widget.dispute.slaResolveDueAt!),
                  ],
                ),
              ],

              // View Booking action (always available inside card, but we put it neatly)
              if (widget.dispute.bookingId.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openBooking(context, widget.dispute.bookingId),
                    icon: const Icon(Icons.receipt_long_outlined, size: 14),
                    label: const Text('View Booking Detail'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ServioRadius.md),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _disputeStatusColor(String status, ServioThemeExtension servio) {
    if (status.startsWith('resolved_')) return servio.success;
    return switch (status) {
      'open' => servio.danger,
      'reviewing' => servio.warning,
      'awaiting_evidence' => servio.warning,
      _ => servio.danger,
    };
  }

  String _disputeStatusLabel(String status) {
    return switch (status) {
      'open' => 'Open',
      'reviewing' => 'Reviewing',
      'awaiting_evidence' => 'Awaiting Evidence',
      'resolved_refund' => 'Resolved – Refunded',
      'resolved_release' => 'Resolved – Released',
      _ => status.replaceAll('_', ' ').toUpperCase()[0] +
          status.replaceAll('_', ' ').substring(1),
    };
  }

  String _fmtCategory(String cat) {
    return cat.replaceAll('_', ' ').split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable badge widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ServioRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final color = priority == 'high' || priority == 'urgent'
        ? servio.danger
        : servio.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ServioRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '${priority[0].toUpperCase()}${priority.substring(1)} priority',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 9,
            ),
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.severity});

  final String severity;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final color = switch (severity) {
      'high' || 'critical' => servio.danger,
      'medium' => servio.warning,
      _ => servio.textSecondary,
    };

    return Text(
      '${severity[0].toUpperCase()}${severity.substring(1)} severity',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontSize: 10,
          ),
    );
  }
}

class _SlaBadge extends StatelessWidget {
  const _SlaBadge({required this.dueAt});

  final DateTime dueAt;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final now = DateTime.now();
    final isOverdue = dueAt.isBefore(now);
    final hoursLeft = dueAt.difference(now).inHours;
    final label = isOverdue
        ? 'SLA overdue'
        : hoursLeft < 24
            ? 'SLA: ${hoursLeft}h left'
            : 'SLA: ${dueAt.difference(now).inDays}d left';

    final color = isOverdue ? servio.danger : servio.warning;

    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton loader
// ─────────────────────────────────────────────────────────────────────────────

class _SupportSkeletonList extends StatelessWidget {
  const _SupportSkeletonList();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SkeletonCard(),
          ),
          childCount: 4,
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ServioCard(
      radius: ServioRadius.lg,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ServioSkeleton(height: 20, width: 120, radius: ServioRadius.full),
          const SizedBox(height: 10),
          const ServioSkeleton(height: 16),
          const SizedBox(height: 6),
          ServioSkeleton(height: 12, width: 180, radius: ServioRadius.sm),
          const SizedBox(height: 10),
          const ServioSkeleton(height: 12),
          const SizedBox(height: 4),
          ServioSkeleton(height: 12, width: 220, radius: ServioRadius.sm),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              ServioSkeleton(height: 10, width: 60, radius: ServioRadius.sm),
              const Spacer(),
              ServioSkeleton(height: 10, width: 80, radius: ServioRadius.sm),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _SupportEmptyState extends StatelessWidget {
  const _SupportEmptyState({required this.tab});

  final SupportTab tab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    final (icon, title, sub) = switch (tab) {
      SupportTab.active => (
          Icons.check_circle_outline_rounded,
          'No active issues',
          'Everything looks good. Open issues will appear here.',
        ),
      SupportTab.disputes => (
          Icons.gavel_rounded,
          'No disputes',
          'Payment disputes you raise will appear here.',
        ),
      SupportTab.resolved => (
          Icons.history_rounded,
          'No resolved cases',
          'Cases closed by our support team will appear here.',
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 52, color: servio.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: servio.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────────────────────────────────────

class _SupportErrorState extends StatelessWidget {
  const _SupportErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      child: Column(
        children: <Widget>[
          Icon(Icons.wifi_off_rounded,
              size: 48, color: servio.danger.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'Failed to load support cases',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Booking navigation helper
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _openBooking(BuildContext context, String bookingId) async {
  if (bookingId.isEmpty) return;

  final messenger = ScaffoldMessenger.of(context);
  final nav = Navigator.of(context);

  final snack = SnackBar(
    content: const Text('Opening booking…'),
    duration: const Duration(seconds: 10),
  );
  messenger.showSnackBar(snack);

  try {
    final backend = await BookingsApi(
      context.read<ApiClient>(),
    ).getBooking(bookingId);
    final model = BookingModel.fromBackend(backend);
    final flowData = bookingFlowDataFromModel(model);
    messenger.hideCurrentSnackBar();
    if (context.mounted) {
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => BookingDetailsScreen(data: flowData),
        ),
      );
    }
  } catch (_) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not load booking details.')),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _fmtDate(DateTime dt) {
  const months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}
