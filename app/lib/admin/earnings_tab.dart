import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/coin_service.dart';
import '../theme.dart';

class EarningsTab extends StatefulWidget {
  const EarningsTab({super.key});
  @override
  State<EarningsTab> createState() => _EarningsTabState();
}

class _EarningsTabState extends State<EarningsTab> {
  int _days = 30;
  late Future<List<({DateTime day, int count, int amount})>> _future =
      CoinService.instance.adminEarningsDaily(days: _days);

  Future<void> _reload([int? days]) async {
    if (days != null) _days = days;
    setState(() => _future = CoinService.instance.adminEarningsDaily(days: _days));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AzarPalette.accent, onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Row(children: [
            Text('GELİR', style: Theme.of(context).textTheme.headlineSmall),
            const Spacer(),
            _rangeChip(7), const SizedBox(width: 6),
            _rangeChip(30), const SizedBox(width: 6),
            _rangeChip(90),
          ]),
          const SizedBox(height: 14),
          FutureBuilder<List<({DateTime day, int count, int amount})>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 220, child: Center(
                  child: CircularProgressIndicator(color: AzarPalette.accent, strokeWidth: 2.4)));
              }
              final rows = snap.data ?? const [];
              if (rows.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(color: AzarPalette.surface,
                    borderRadius: BorderRadius.circular(14), border: Border.all(color: AzarPalette.line)),
                  child: Column(children: [
                    const Icon(Icons.show_chart_rounded, color: AzarPalette.textDim, size: 32),
                    const SizedBox(height: 10),
                    Text('Henüz satın alma yok',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AzarPalette.textDim)),
                  ]),
                );
              }
              final totalAmount = rows.fold<int>(0, (s, r) => s + r.amount);
              final totalCount  = rows.fold<int>(0, (s, r) => s + r.count);
              final maxY = rows.map((r) => r.amount).reduce((a, b) => a > b ? a : b).toDouble();
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _kpi('Toplam coin', _fmt(totalAmount), AzarPalette.accent),
                  const SizedBox(width: 10),
                  _kpi('İşlem', '$totalCount', AzarPalette.secondary),
                  const SizedBox(width: 10),
                  _kpi('Ortalama', rows.isEmpty ? '0' : _fmt((totalAmount / rows.length).round()), AzarPalette.success),
                ]),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
                  height: 240,
                  decoration: BoxDecoration(color: AzarPalette.surface,
                    borderRadius: BorderRadius.circular(14), border: Border.all(color: AzarPalette.line)),
                  child: LineChart(LineChartData(
                    minY: 0, maxY: maxY <= 0 ? 1 : maxY * 1.15,
                    gridData: FlGridData(show: true, horizontalInterval: maxY / 4 <= 0 ? 1 : maxY / 4,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(color: AzarPalette.line.withValues(alpha: 0.45), strokeWidth: 1)),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36,
                        getTitlesWidget: (v, _) => Text(_fmt(v.toInt()),
                          style: const TextStyle(color: AzarPalette.textDim, fontSize: 10)))),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22,
                        interval: (rows.length / 6).ceilToDouble().clamp(1, 999),
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= rows.length) return const SizedBox.shrink();
                          final d = rows[i].day;
                          return Padding(padding: const EdgeInsets.only(top: 6),
                            child: Text('${d.day}/${d.month}',
                              style: const TextStyle(color: AzarPalette.textDim, fontSize: 10)));
                        })),
                    ),
                    lineBarsData: [LineChartBarData(
                      isCurved: true, curveSmoothness: 0.32, barWidth: 2.5,
                      color: AzarPalette.accent,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true,
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [AzarPalette.accent.withValues(alpha: 0.3), AzarPalette.accent.withValues(alpha: 0.02)])),
                      spots: [for (var i = 0; i < rows.length; i++) FlSpot(i.toDouble(), rows[i].amount.toDouble())],
                    )],
                  )),
                ),
                const SizedBox(height: 16),
                Text('Son günler', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...rows.reversed.take(15).map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(color: AzarPalette.surface,
                    borderRadius: BorderRadius.circular(12), border: Border.all(color: AzarPalette.line)),
                  child: Row(children: [
                    Text('${r.day.day}/${r.day.month}/${r.day.year}',
                      style: const TextStyle(color: AzarPalette.text, fontSize: 13, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('${r.count} işlem',
                      style: const TextStyle(color: AzarPalette.textDim, fontSize: 12)),
                    const SizedBox(width: 14),
                    Text('+${_fmt(r.amount)}',
                      style: const TextStyle(color: AzarPalette.accent, fontSize: 13.5, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 4),
                    const Icon(Icons.diamond_rounded, color: AzarPalette.accent, size: 14),
                  ]),
                )),
              ]);
            },
          ),
        ],
      ),
    );
  }

  Widget _rangeChip(int days) {
    final active = _days == days;
    return GestureDetector(
      onTap: () => _reload(days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AzarPalette.accent.withValues(alpha: 0.18) : AzarPalette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? AzarPalette.accent : AzarPalette.line),
        ),
        child: Text('${days}g',
          style: TextStyle(color: active ? AzarPalette.accent : AzarPalette.textDim,
            fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _kpi(String label, String value, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AzarPalette.surface,
        borderRadius: BorderRadius.circular(13), border: Border.all(color: AzarPalette.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AzarPalette.textDim, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: color, fontSize: 19, fontWeight: FontWeight.w800)),
      ]),
    ));
  }

  String _fmt(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
