import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:expense_tracker_cyph_lab/models/expense_category.dart';
import 'package:expense_tracker_cyph_lab/models/monthly_total.dart';
import 'package:expense_tracker_cyph_lab/services/expense_service.dart';

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  static const List<String> _monthShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  final ExpenseService _expenseService = ExpenseService();
  late final Future<void> _ready = _expenseService.ensureMonthlyTotals();
  late final Stream<List<MonthlyTotal>> _totalsStream =
      _expenseService.watchAllMonthlyTotals();
  int _selectedYear = DateTime.now().year;
  // null means the whole year in the category tab.
  int? _selectedMonth = DateTime.now().month;

  String _formatAmount(double amount) => 'Rs. ${amount.toStringAsFixed(2)}';

  String _compactAmount(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}k';
    return amount.toStringAsFixed(0);
  }

  String _shortLabel(MonthlyTotal m) =>
      "${_monthShort[m.month - 1]} '${(m.year % 100).toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Expense Charts'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.show_chart), text: 'Monthly'),
              Tab(icon: Icon(Icons.pie_chart), text: 'By Category'),
            ],
          ),
        ),
        body: SafeArea(
          child: FutureBuilder<void>(
            future: _ready,
            builder: (context, readySnap) {
              if (readySnap.hasError) {
                return _message('Could not prepare totals: ${readySnap.error}');
              }
              if (readySnap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              return StreamBuilder<List<MonthlyTotal>>(
                stream: _totalsStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _message('Could not load totals: ${snapshot.error}');
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final totals =
                      snapshot.data!.where((m) => m.total > 0).toList();
                  return TabBarView(
                    children: [
                      _buildMonthlyTab(totals),
                      _buildCategoryTab(totals),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _message(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );

  Widget _summaryCard(String label, double amount) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        color: scheme.primary,
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: scheme.onPrimary, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            _formatAmount(amount),
            style: TextStyle(
              color: scheme.onPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Monthly tab: one point per month with data, all time ----------

  Widget _buildMonthlyTab(List<MonthlyTotal> totals) {
    if (totals.isEmpty) {
      return _message('No expenses recorded yet.');
    }

    final scheme = Theme.of(context).colorScheme;
    final count = totals.length;
    final allTotal = totals.fold<double>(0, (a, m) => a + m.total);
    final maxValue = totals.map((m) => m.total).reduce(math.max);
    final maxY = maxValue * 1.2;
    // Spread labels so at most ~6 are shown however many points there are.
    final labelStep = math.max(1, (count / 6).ceil());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _summaryCard(
          'Total across $count month${count == 1 ? '' : 's'}',
          allTotal,
        ),
        const SizedBox(height: 24),
        const Text(
          'Monthly spending',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 260,
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: LineChart(
              LineChartData(
                // One x unit per data point; pad a single point so it is centred.
                minX: count == 1 ? -1 : 0,
                maxX: count == 1 ? 1 : (count - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  drawVerticalLine: true,
                  verticalInterval: labelStep.toDouble(),
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: scheme.outlineVariant, strokeWidth: 1),
                  getDrawingVerticalLine: (_) =>
                      FlLine(color: scheme.outlineVariant, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => scheme.inverseSurface,
                    getTooltipItems: (spots) => spots.map((s) {
                      final m = totals[s.x.toInt()];
                      return LineTooltipItem(
                        '${_monthNames[m.month - 1]} ${m.year}\n'
                        '${_formatAmount(m.total)}',
                        TextStyle(color: scheme.onInverseSurface),
                      );
                    }).toList(),
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: maxY / 4,
                      getTitlesWidget: (value, meta) => Text(
                        _compactAmount(value),
                        style: TextStyle(
                            fontSize: 10, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: labelStep.toDouble(),
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        if (value != i || i < 0 || i >= count) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _shortLabel(totals[i]),
                            style: TextStyle(
                                fontSize: 10, color: scheme.onSurfaceVariant),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < count; i++)
                        FlSpot(i.toDouble(), totals[i].total),
                    ],
                    isCurved: count > 2,
                    preventCurveOverShooting: true,
                    color: scheme.primary,
                    barWidth: 3,
                    dotData: FlDotData(show: count <= 24),
                    belowBarData: BarAreaData(
                      show: true,
                      color: scheme.primary.withOpacity(0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Newest month first.
        for (final m in totals.reversed)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${_monthNames[m.month - 1]} ${m.year}'),
            subtitle: Text('${m.count} expense${m.count == 1 ? '' : 's'}'),
            trailing: Text(
              _formatAmount(m.total),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  // ---------- Category tab ----------

  Widget _buildYearSelector() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous year',
          onPressed: () => setState(() => _selectedYear--),
        ),
        Expanded(
          child: Text(
            '$_selectedYear',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next year',
          onPressed: () => setState(() => _selectedYear++),
        ),
      ],
    );
  }

  Widget _buildCategoryTab(List<MonthlyTotal> totals) {
    final months = totals.where((m) =>
        m.year == _selectedYear &&
        (_selectedMonth == null || m.month == _selectedMonth));
    final byCategory = <String, double>{};
    for (final m in months) {
      m.categories.forEach((name, amount) {
        byCategory[name] = (byCategory[name] ?? 0) + amount;
      });
    }
    final entries = byCategory.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (a, e) => a + e.value);
    final periodLabel = _selectedMonth == null
        ? '$_selectedYear'
        : '${_monthNames[_selectedMonth! - 1]} $_selectedYear';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildYearSelector(),
        const SizedBox(height: 8),
        DropdownButtonFormField<int?>(
          value: _selectedMonth,
          decoration: InputDecoration(
            labelText: 'Period',
            prefixIcon: const Icon(Icons.calendar_month),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Whole year')),
            for (var m = 1; m <= 12; m++)
              DropdownMenuItem<int?>(value: m, child: Text(_monthNames[m - 1])),
          ],
          onChanged: (m) => setState(() => _selectedMonth = m),
        ),
        const SizedBox(height: 16),
        _summaryCard('Total for $periodLabel', total),
        const SizedBox(height: 24),
        if (entries.isEmpty)
          _message('No expenses recorded for $periodLabel.')
        else ...[
          SizedBox(
            height: 240,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: [
                  for (final e in entries)
                    PieChartSectionData(
                      value: e.value,
                      color: ExpenseCategory.fromName(e.key).color,
                      radius: 60,
                      title: e.value / total >= 0.06
                          ? '${(e.value / total * 100).toStringAsFixed(0)}%'
                          : '',
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          for (final e in entries) _categoryRow(e.key, e.value, total),
        ],
      ],
    );
  }

  Widget _categoryRow(String name, double amount, double total) {
    final category = ExpenseCategory.fromName(name);
    final percent = amount / total * 100;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: category.color.withOpacity(0.15),
        child: Icon(category.icon, color: category.color),
      ),
      title: Text(category.name),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: LinearProgressIndicator(
          value: amount / total,
          color: category.color,
          backgroundColor: category.color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatAmount(amount),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('${percent.toStringAsFixed(1)}%'),
        ],
      ),
    );
  }
}
