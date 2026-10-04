import 'package:flutter/material.dart';
import 'package:expense_tracker_cyph_lab/ui/addExpenses.dart';
import 'package:expense_tracker_cyph_lab/ui/homeScreen.dart';
import 'package:expense_tracker_cyph_lab/ui/loginScreen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';
  static const String addExpense = '/add-expense';

  static Map<String, WidgetBuilder> get routes => {
        login: (context) => const LoginScreen(),
        home: (context) => const Homescreen(),
        addExpense: (context) => const AddExpenses(),
      };
}
