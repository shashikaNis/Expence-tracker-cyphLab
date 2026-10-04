import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:expense_tracker_cyph_lab/models/expense.dart';
import 'package:expense_tracker_cyph_lab/models/expense_category.dart';
import 'package:expense_tracker_cyph_lab/routes.dart';
import 'package:expense_tracker_cyph_lab/services/expense_service.dart';
import 'package:expense_tracker_cyph_lab/theme/theme_controller.dart';
import 'package:expense_tracker_cyph_lab/ui/addExpenses.dart';

class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  final ExpenseService _expenseService = ExpenseService();
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  // null means "All" categories.
  ExpenseCategory? _selectedCategory;
  // Expenses being deleted; hidden until Firestore confirms.
  final Set<String> _deletingIds = {};
  late Stream<List<Expense>> _expensesStream =
      _expenseService.watchExpensesForMonth(_selectedMonth);

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + delta);
      _expensesStream = _expenseService.watchExpensesForMonth(_selectedMonth);
    });
  }

  String _formatMonth(DateTime m) => '${_monthNames[m.month - 1]} ${m.year}';

  Widget _buildMonthSelector() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous month',
          onPressed: () => _changeMonth(-1),
        ),
        Expanded(
          child: Text(
            _formatMonth(_selectedMonth),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next month',
          onPressed: () => _changeMonth(1),
        ),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    final options = <ExpenseCategory?>[null, ...ExpenseCategory.all];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = options[index];
          return ChoiceChip(
            avatar: Icon(
              category?.icon ?? Icons.apps,
              size: 18,
              color: category?.color,
            ),
            label: Text(category?.name ?? 'All'),
            selected: _selectedCategory == category,
            showCheckmark: false,
            onSelected: (_) => setState(() => _selectedCategory = category),
          );
        },
      ),
    );
  }

  Widget _buildThemeMenu() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, mode, _) => PopupMenuButton<ThemeMode>(
        tooltip: 'Theme',
        icon: Icon(switch (mode) {
          ThemeMode.light => Icons.light_mode,
          ThemeMode.dark => Icons.dark_mode,
          ThemeMode.system => Icons.brightness_auto,
        }),
        initialValue: mode,
        onSelected: ThemeController.instance.setMode,
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: ThemeMode.system,
            child: ListTile(
              leading: Icon(Icons.brightness_auto),
              title: Text('System'),
            ),
          ),
          PopupMenuItem(
            value: ThemeMode.light,
            child: ListTile(
              leading: Icon(Icons.light_mode),
              title: Text('Light'),
            ),
          ),
          PopupMenuItem(
            value: ThemeMode.dark,
            child: ListTile(
              leading: Icon(Icons.dark_mode),
              title: Text('Dark'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) => 'Rs. ${amount.toStringAsFixed(2)}';

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Widget _buildList(List<Expense> expenses) {
    if (expenses.isEmpty) {
      final filter =
          _selectedCategory == null ? '' : ' in ${_selectedCategory!.name}';
      return Center(
        child: Text(
          'No expenses$filter for ${_formatMonth(_selectedMonth)}.\n'
          'Tap + to add one.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        final expense = expenses[index];
        final category = ExpenseCategory.fromName(expense.category);
        return Dismissible(
          key: ValueKey(expense.id),
          direction: DismissDirection.endToStart,
          background: _buildDeleteBackground(),
          confirmDismiss: (_) => confirmDeleteExpense(context, expense),
          onDismissed: (_) => _deleteExpense(expense),
          child: Card(
            child: ListTile(
              onTap: () => _openExpenseForm(expense),
              leading: CircleAvatar(
                backgroundColor: category.color.withOpacity(0.15),
                child: Icon(category.icon, color: category.color),
              ),
              title: Text(expense.title),
              subtitle: Text(
                '${expense.category} • ${_formatDate(expense.date)}'
                '${expense.note.isNotEmpty ? '\n${expense.note}' : ''}',
              ),
              isThreeLine: expense.note.isNotEmpty,
              trailing: Text(
                _formatAmount(expense.amount),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeleteBackground() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: scheme.error,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.delete, color: scheme.onError),
    );
  }

  Future<void> _deleteExpense(Expense expense) async {
    // Hide it straight away so the dismissed tile leaves the tree.
    setState(() => _deletingIds.add(expense.id!));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _expenseService.deleteExpense(expense.id!);
      messenger.showSnackBar(
        SnackBar(content: Text('Expense deleted: ${expense.title}')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to delete expense: $e')),
      );
    } finally {
      if (mounted) setState(() => _deletingIds.remove(expense.id));
    }
  }

  void _openExpenseForm([Expense? expense]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AddExpenses(expense: expense),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights),
            tooltip: 'Charts',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.charts),
          ),
          _buildThemeMenu(),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              final navigator = Navigator.of(context);
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              navigator.pushReplacementNamed(AppRoutes.login);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<Expense>>(
          stream: _expensesStream,
          builder: (context, snapshot) {
            final monthExpenses = (snapshot.data ?? const <Expense>[])
                .where((e) => !_deletingIds.contains(e.id))
                .toList();
            final expenses = _selectedCategory == null
                ? monthExpenses
                : monthExpenses
                    .where((e) =>
                        ExpenseCategory.fromName(e.category) ==
                        _selectedCategory)
                    .toList();
            final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);

            Widget list;
            if (snapshot.hasError) {
              list = Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Could not load expenses: ${snapshot.error}'),
                ),
              );
            } else if (snapshot.connectionState == ConnectionState.waiting) {
              list = const Center(child: CircularProgressIndicator());
            } else {
              list = _buildList(expenses);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
                  child: _buildMonthSelector(),
                ),
                _buildCategoryFilter(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius:
                              const BorderRadius.all(Radius.circular(12)),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        child: Column(
                          children: [
                            Text(
                              _selectedCategory == null
                                  ? 'Total'
                                  : 'Total • ${_selectedCategory!.name}',
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  fontSize: 18),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatAmount(total),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Expenses',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(child: list),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openExpenseForm(),
        tooltip: 'Add Expense',
        child: const Icon(Icons.add),
      ),
    );
  }
}
