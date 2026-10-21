import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/astra_theme.dart';
import '../admin_config.dart';
import '../admin_models.dart';

/// Which view of the chart card is showing.
enum ChartMode { active, installs }

/// The one chart: thirty days, one bar group a day, scrolled to today.
///
/// "Active users" shows one bar a day. "Installs and uninstalls" shows a green
/// and a red bar a day with the net result in words underneath. Every bar is a
/// button: tapping it calls back with that day so the screen can open the
/// people behind it.
class DayChart extends StatefulWidget {
  const DayChart({
    super.key,
    required this.days,
    required this.mode,
    required this.onActive,
    required this.onInstalled,
    required this.onUninstalled,
  });

  final List<DayStats> days;
  final ChartMode mode;
  final ValueChanged<DayStats> onActive;
  final ValueChanged<DayStats> onInstalled;
  final ValueChanged<DayStats> onUninstalled;

  @override
  State<DayChart> createState() => _DayChartState();
}

class _DayChartState extends State<DayChart> {
  final _scroll = ScrollController();

  static const _barArea = 110.0;

  @override
  void initState() {
    super.initState();
    _toToday();
  }

  @override
  void didUpdateWidget(DayChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) _toToday();
  }

  void _toToday() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final installs = widget.mode == ChartMode.installs;
    final peak = widget.days.fold<int>(1, (m, d) {
      final biggest = installs
          ? (d.installed.length > d.uninstalled.length
                ? d.installed.length
                : d.uninstalled.length)
          : d.active.length;
      return biggest > m ? biggest : m;
    });

    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < widget.days.length; i++)
            SizedBox(
              width: installs ? 70 : 32,
              child: installs
                  ? _InstallColumn(
                      day: widget.days[i],
                      peak: peak,
                      today: i == widget.days.length - 1,
                      onInstalled: widget.onInstalled,
                      onUninstalled: widget.onUninstalled,
                    )
                  : _ActiveColumn(
                      day: widget.days[i],
                      peak: peak,
                      today: i == widget.days.length - 1,
                      onTap: widget.onActive,
                    ),
            ),
        ],
      ),
    );
  }
}

class _DayLabel extends StatelessWidget {
  const _DayLabel({required this.day, required this.today});

  final DateTime day;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final color = today ? AdminColors.highlight : AdminColors.dim;
    return Column(
      children: [
        Text(
          DateFormat('E').format(day),
          style: AstraTextStyles.small.copyWith(fontSize: 9, height: 1, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          DateFormat('d').format(day),
          style: AstraTextStyles.small.copyWith(
            fontSize: 11,
            height: 1,
            color: color,
            fontWeight: today ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.count,
    required this.peak,
    required this.color,
    required this.width,
    required this.onTap,
    required this.label,
  });

  final int count;
  final int peak;
  final Color color;
  final double width;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: width + 6,
        height: _DayChartState._barArea + 18,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '$count',
              style: AstraTextStyles.small.copyWith(fontSize: 10, height: 1),
            ),
            const SizedBox(height: 3),
            Container(
              width: width,
              height: (_DayChartState._barArea * count / peak).clamp(3, _DayChartState._barArea),
              decoration: BoxDecoration(
                color: count == 0 ? color.withValues(alpha: 0.35) : color,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ActiveColumn extends StatelessWidget {
  const _ActiveColumn({
    required this.day,
    required this.peak,
    required this.today,
    required this.onTap,
  });

  final DayStats day;
  final int peak;
  final bool today;
  final ValueChanged<DayStats> onTap;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      _Bar(
        count: day.active.length,
        peak: peak,
        width: 18,
        color: today ? AdminColors.highlight : AdminColors.primary,
        onTap: () => onTap(day),
        label: '${day.active.length} active on ${DateFormat('d MMM').format(day.day)}',
      ),
      const SizedBox(height: 4),
      _DayLabel(day: day.day, today: today),
    ],
  );
}

class _InstallColumn extends StatelessWidget {
  const _InstallColumn({
    required this.day,
    required this.peak,
    required this.today,
    required this.onInstalled,
    required this.onUninstalled,
  });

  final DayStats day;
  final int peak;
  final bool today;
  final ValueChanged<DayStats> onInstalled;
  final ValueChanged<DayStats> onUninstalled;

  @override
  Widget build(BuildContext context) {
    final net = day.net;
    final (word, color) = net > 0
        ? ('Net gain', AdminColors.good)
        : net < 0
        ? ('Net loss', AdminColors.bad)
        : ('No change', AdminColors.dim);
    final number = net > 0 ? '+$net' : '$net';

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _Bar(
              count: day.installed.length,
              peak: peak,
              width: 20,
              color: AdminColors.good,
              onTap: () => onInstalled(day),
              label: '${day.installed.length} installed on ${DateFormat('d MMM').format(day.day)}',
            ),
            _Bar(
              count: day.uninstalled.length,
              peak: peak,
              width: 20,
              color: AdminColors.bad,
              onTap: () => onUninstalled(day),
              label:
                  '${day.uninstalled.length} uninstalled on ${DateFormat('d MMM').format(day.day)}',
            ),
          ],
        ),
        const SizedBox(height: 4),
        _DayLabel(day: day.day, today: today),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            word,
            style: AstraTextStyles.small.copyWith(fontSize: 10, height: 1, color: color),
          ),
        ),
        if (net != 0)
          Text(
            number,
            style: AstraTextStyles.small.copyWith(
              fontSize: 11,
              height: 1.2,
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
      ],
    );
  }
}
