import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/state/ai_performance_tracker.dart';

/// Developer-only screen that visualises AI generation performance metrics.
/// Accessible in debug builds via the chart icon in the AI Room Finisher AppBar.
/// Never shown in production; contains no prompt text or user content.
class AiPerformanceDashboard extends StatefulWidget {
  const AiPerformanceDashboard({super.key});

  @override
  State<AiPerformanceDashboard> createState() => _AiPerformanceDashboardState();
}

class _AiPerformanceDashboardState extends State<AiPerformanceDashboard> {
  final AiPerformanceTracker _tracker = AiPerformanceTracker.instance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timings = _tracker.timings;
    final hasData = timings.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Performance'),
        actions: <Widget>[
          if (hasData)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Clear metrics',
              onPressed: () => setState(() => _tracker.clear()),
            ),
        ],
      ),
      body: hasData ? _buildContent(theme, timings) : _buildEmpty(theme),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.bar_chart_rounded,
              size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text('No data yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Run an AI room analysis to collect metrics.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
      ThemeData theme, List<AiGenerationTiming> timings) {
    final successColor = theme.colorScheme.primary;
    final errorColor = theme.colorScheme.error;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        // ── Summary cards ──────────────────────────────────────────────────
        _SummaryRow(tracker: _tracker),
        const SizedBox(height: 24),

        // ── Generation time line chart ─────────────────────────────────────
        Text('Generation Time (ms)', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: _GenerationTimeChart(timings: timings),
        ),
        const SizedBox(height: 24),

        // ── Success vs failure bar chart ───────────────────────────────────
        Text('Success vs Failure', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: _SuccessFailureChart(
            successCount: _tracker.successCount,
            failureCount: _tracker.failureCount,
            successColor: successColor,
            errorColor: errorColor,
          ),
        ),
        const SizedBox(height: 24),

        // ── Recent requests list ───────────────────────────────────────────
        Text('Recent Requests', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ...timings.reversed.take(10).map(
              (t) => _TimingTile(timing: t, theme: theme),
            ),
      ],
    );
  }
}

// ── Summary row ─────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.tracker});
  final AiPerformanceTracker tracker;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _StatCard(
          label: 'Avg',
          value: '${tracker.averageMs.round()} ms',
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Slowest',
          value: '${tracker.slowestMs} ms',
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Requests',
          value: '${tracker.totalRequests}',
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Success',
          value: tracker.totalRequests == 0
              ? '—'
              : '${(tracker.successCount / tracker.totalRequests * 100).round()}%',
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: <Widget>[
            Text(value,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}

// ── Generation time line chart ───────────────────────────────────────────────

class _GenerationTimeChart extends StatelessWidget {
  const _GenerationTimeChart({required this.timings});
  final List<AiGenerationTiming> timings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spots = timings
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.totalMs.toDouble()))
        .toList();

    final maxY = timings.map((t) => t.totalMs).reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (timings.length - 1).toDouble(),
        minY: 0,
        maxY: (maxY * 1.15).toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY / 4).toDouble().clamp(1, double.infinity),
          getDrawingHorizontalLine: (_) => FlLine(
            color: theme.colorScheme.outlineVariant,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (value, _) => Text(
                '${(value / 1000).toStringAsFixed(0)}s',
                style: theme.textTheme.labelSmall,
              ),
            ),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, index) {
                final success = timings[index].success;
                return FlDotCirclePainter(
                  radius: 4,
                  color: success
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                  strokeWidth: 0,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Success / failure bar chart ──────────────────────────────────────────────

class _SuccessFailureChart extends StatelessWidget {
  const _SuccessFailureChart({
    required this.successCount,
    required this.failureCount,
    required this.successColor,
    required this.errorColor,
  });

  final int successCount;
  final int failureCount;
  final Color successColor;
  final Color errorColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = successCount + failureCount;
    if (total == 0) return const SizedBox.shrink();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: total.toDouble() * 1.2,
        barGroups: <BarChartGroupData>[
          BarChartGroupData(
            x: 0,
            barRods: <BarChartRodData>[
              BarChartRodData(
                toY: successCount.toDouble(),
                color: successColor,
                width: 40,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ],
          ),
          BarChartGroupData(
            x: 1,
            barRods: <BarChartRodData>[
              BarChartRodData(
                toY: failureCount.toDouble(),
                color: errorColor,
                width: 40,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ],
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                final label = value == 0 ? 'Success' : 'Failed';
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(label, style: theme.textTheme.labelSmall),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, _) => Text(
                value.toInt().toString(),
                style: theme.textTheme.labelSmall,
              ),
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (_) => FlLine(
            color: theme.colorScheme.outlineVariant,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

// ── Recent request tile ──────────────────────────────────────────────────────

class _TimingTile extends StatelessWidget {
  const _TimingTile({required this.timing, required this.theme});
  final AiGenerationTiming timing;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final secs = (timing.totalMs / 1000).toStringAsFixed(1);
    final time = TimeOfDay.fromDateTime(timing.startedAt).format(context);
    final renderLabel = timing.includeRender ? 'with render' : 'no render';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Icon(
            timing.success
                ? Icons.check_circle_outline_rounded
                : Icons.error_outline_rounded,
            size: 18,
            color: timing.success
                ? theme.colorScheme.primary
                : theme.colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${secs}s  ·  $renderLabel  ·  $time',
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (!timing.success && timing.errorMessage != null)
            Text(
              _truncate(timing.errorMessage!, 24),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
        ],
      ),
    );
  }

  String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';
}
