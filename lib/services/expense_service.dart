import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:expense_tracker_cyph_lab/models/expense.dart';
import 'package:expense_tracker_cyph_lab/models/expense_category.dart';
import 'package:expense_tracker_cyph_lab/models/monthly_total.dart';

class ExpenseService {
 static const int _monthlyTotalsVersion = 1;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>> _userDoc() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user');
    }
    return _db.collection('users').doc(user.uid);
  }

  CollectionReference<Map<String, dynamic>> _expenses() =>
      _userDoc().collection('expenses');

  CollectionReference<Map<String, dynamic>> _monthlyTotals() =>
      _userDoc().collection('monthlyTotals');

 Future<void> addExpense(Expense expense) {
    final category = ExpenseCategory.fromName(expense.category).name;
    final monthRef = _monthlyTotals()
        .doc(MonthlyTotal.docId(expense.date.year, expense.date.month));

    final batch = _db.batch();
    batch.set(_expenses().doc(), expense.toFirestore());
    batch.set(
      monthRef,
      {
        'year': expense.date.year,
        'month': expense.date.month,
        'total': FieldValue.increment(expense.amount),
        'count': FieldValue.increment(1),
        'categories': {category: FieldValue.increment(expense.amount)},
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    return batch.commit();
  }

  Future<void> updateExpense(Expense updated) async {
    final ref = _expenses().doc(updated.id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('This expense no longer exists');
      }
      final old = Expense.fromFirestore(snap);

      final deltas = <String, _MonthDelta>{};
      _addDelta(deltas, old, -1);
      _addDelta(deltas, updated, 1);
      final monthSnaps = await _readMonths(tx, deltas.keys);

      tx.update(ref, updated.toFirestoreUpdate());
      _applyMonthDeltas(tx, deltas, monthSnaps);
    });
  }

 Future<void> deleteExpense(String id) async {
    final ref = _expenses().doc(id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final old = Expense.fromFirestore(snap);

      final deltas = <String, _MonthDelta>{};
      _addDelta(deltas, old, -1);
      final monthSnaps = await _readMonths(tx, deltas.keys);

      tx.delete(ref);
      _applyMonthDeltas(tx, deltas, monthSnaps);
    });
  }

  void _addDelta(Map<String, _MonthDelta> deltas, Expense e, int sign) {
    final id = MonthlyTotal.docId(e.date.year, e.date.month);
    final delta =
        deltas.putIfAbsent(id, () => _MonthDelta(e.date.year, e.date.month));
    final category = ExpenseCategory.fromName(e.category).name;
    delta.total += sign * e.amount;
    delta.count += sign;
    delta.categories[category] =
        (delta.categories[category] ?? 0) + sign * e.amount;
  }

  Future<Map<String, DocumentSnapshot<Map<String, dynamic>>>> _readMonths(
      Transaction tx, Iterable<String> ids) async {
    final snaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
    for (final id in ids) {
      snaps[id] = await tx.get(_monthlyTotals().doc(id));
    }
    return snaps;
  }

  static double _round2(double v) => (v * 100).roundToDouble() / 100;

  void _applyMonthDeltas(
    Transaction tx,
    Map<String, _MonthDelta> deltas,
    Map<String, DocumentSnapshot<Map<String, dynamic>>> monthSnaps,
  ) {
    deltas.forEach((id, delta) {
      final snap = monthSnaps[id]!;
      final current = snap.exists ? MonthlyTotal.fromFirestore(snap) : null;
      final newCount = (current?.count ?? 0) + delta.count;

      if (newCount <= 0) {
        if (snap.exists) tx.delete(snap.reference);
        return;
      }

      final categories = <String, double>{...?current?.categories};
      delta.categories.forEach((name, amount) {
        categories[name] = _round2((categories[name] ?? 0) + amount);
      });
      categories.removeWhere((_, amount) => amount <= 0);

      tx.set(snap.reference, {
        'year': delta.year,
        'month': delta.month,
        'total': _round2((current?.total ?? 0) + delta.total),
        'count': newCount,
        'categories': categories,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<List<Expense>> watchExpenses() {
    return _expenses()
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Expense.fromFirestore).toList());
  }

 Stream<List<Expense>> watchExpensesForMonth(DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    return _expenses()
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Expense.fromFirestore).toList());
  }

 Stream<List<MonthlyTotal>> watchAllMonthlyTotals() {
    return _monthlyTotals().snapshots().map((snap) {
      final totals = snap.docs.map(MonthlyTotal.fromFirestore).toList()
        ..sort((a, b) => a.year != b.year
            ? a.year.compareTo(b.year)
            : a.month.compareTo(b.month));
      return totals;
    });
  }

 Future<void> ensureMonthlyTotals() async {
    final userSnap = await _userDoc().get();
    final version =
        (userSnap.data()?['monthlyTotalsVersion'] as num?)?.toInt() ?? 0;
    if (version >= _monthlyTotalsVersion) return;
    await rebuildMonthlyTotals();
  }

 Future<void> rebuildMonthlyTotals() async {
    final expensesSnap = await _expenses().get();
    final totals = <String, Map<String, dynamic>>{};

    for (final doc in expensesSnap.docs) {
      final expense = Expense.fromFirestore(doc);
      final id = MonthlyTotal.docId(expense.date.year, expense.date.month);
      final category = ExpenseCategory.fromName(expense.category).name;
      final entry = totals.putIfAbsent(
        id,
        () => {
          'year': expense.date.year,
          'month': expense.date.month,
          'total': 0.0,
          'count': 0,
          'categories': <String, double>{},
        },
      );
      entry['total'] = (entry['total'] as double) + expense.amount;
      entry['count'] = (entry['count'] as int) + 1;
      final categories = entry['categories'] as Map<String, double>;
      categories[category] = (categories[category] ?? 0) + expense.amount;
    }

    final existing = await _monthlyTotals().get();
    final batch = _db.batch();
    for (final doc in existing.docs) {
      if (!totals.containsKey(doc.id)) batch.delete(doc.reference);
    }
    totals.forEach((id, data) {
      batch.set(_monthlyTotals().doc(id), {
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    batch.set(
      _userDoc(),
      {'monthlyTotalsVersion': _monthlyTotalsVersion},
      SetOptions(merge: true),
    );
    await batch.commit();
  }
}

class _MonthDelta {
  final int year;
  final int month;
  double total = 0;
  int count = 0;
  final Map<String, double> categories = {};

  _MonthDelta(this.year, this.month);
}
