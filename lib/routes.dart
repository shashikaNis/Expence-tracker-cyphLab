import 'package:flutter/material.dart';
import 'package:expense_tracker_cyph_lab/ui/addExpenses.dart';
import 'package:expense_tracker_cyph_lab/ui/chartsScreen.dart';
import 'package:expense_tracker_cyph_lab/ui/homeScreen.dart';
import 'package:expense_tracker_cyph_lab/ui/loginScreen.dart';
import 'package:expense_tracker_cyph_lab/ui/signupScreen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String signUp = '/signup';
  static const String home = '/home';
  static const String addExpense = '/add-expense';
  static const String charts = '/charts';

  static Map<String, WidgetBuilder> get routes => {
        login: (context) => const LoginScreen(),
        signUp: (context) => const SignupScreen(),
        home: (context) => const Homescreen(),
        addExpense: (context) => const AddExpenses(),
        charts: (context) => const ChartsScreen(),
      };
}
