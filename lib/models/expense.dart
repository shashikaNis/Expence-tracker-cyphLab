import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String? id;
  final double amount;
  final String title;
  final String category;
  final DateTime date;
  final String note;

  const Expense({
    this.id,
    required this.amount,
    required this.title,
    required this.category,
    required this.date,
    this.note = '',
  });

  factory Expense.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Expense(
      id: doc.id,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      title: data['title'] as String? ?? '',
      category: data['category'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: data['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'amount': amount,
        'title': title,
        'category': category,
        'date': Timestamp.fromDate(date),
        'note': note,
        'createdAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> toFirestoreUpdate() => {
        'amount': amount,
        'title': title,
        'category': category,
        'date': Timestamp.fromDate(date),
        'note': note,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
