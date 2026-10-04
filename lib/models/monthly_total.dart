import 'package:cloud_firestore/cloud_firestore.dart';

class MonthlyTotal {
  final int year;
  final int month;
  final double total;
  final int count;
  final Map<String, double> categories;

  const MonthlyTotal({
    required this.year,
    required this.month,
    required this.total,
    required this.count,
    required this.categories,
  });

  static String docId(int year, int month) =>
      '$year-${month.toString().padLeft(2, '0')}';

  factory MonthlyTotal.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawCategories = (data['categories'] as Map<String, dynamic>?) ?? {};
    return MonthlyTotal(
      year: (data['year'] as num?)?.toInt() ?? 0,
      month: (data['month'] as num?)?.toInt() ?? 0,
      total: (data['total'] as num?)?.toDouble() ?? 0,
      count: (data['count'] as num?)?.toInt() ?? 0,
      categories: rawCategories
          .map((key, value) => MapEntry(key, (value as num).toDouble())),
    );
  }
}
