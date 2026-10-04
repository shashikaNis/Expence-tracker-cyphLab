import 'package:flutter/material.dart';

class ExpenseCategory {
  final String name;
  final IconData icon;
  final Color color;

  const ExpenseCategory(this.name, this.icon, this.color);

  static const List<ExpenseCategory> all = [
    ExpenseCategory('Food', Icons.restaurant, Colors.orange),
    ExpenseCategory('Grocery', Icons.local_grocery_store, Colors.green),
    ExpenseCategory('Transport', Icons.directions_bus, Colors.blue),
    ExpenseCategory('Fuel', Icons.local_gas_station, Colors.brown),
    ExpenseCategory('Shopping', Icons.shopping_bag, Colors.pink),
    ExpenseCategory('Bills', Icons.receipt_long, Colors.indigo),
    ExpenseCategory('Health', Icons.medical_services, Colors.red),
    ExpenseCategory('Education', Icons.school, Colors.teal),
    ExpenseCategory('Entertainment', Icons.movie, Colors.purple),
    ExpenseCategory('Other', Icons.category, Colors.grey),
  ];

  static ExpenseCategory get other => all.last;

 static ExpenseCategory fromName(String name) {
    return all.firstWhere(
      (c) => c.name.toLowerCase() == name.trim().toLowerCase(),
      orElse: () => other,
    );
  }
}
