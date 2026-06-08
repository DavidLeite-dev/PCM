import 'package:flutter/material.dart';
import 'book_catalog_screen.dart';
import 'my_books_screen.dart';
import 'transactions_screen.dart';
import 'profile_screen.dart';
import 'admin_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import 'debug_logs_screen.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  @override
  Widget build(BuildContext context) {
    final screens = [
      ('📋 Debug Logs', const DebugLogsScreen()),
      ('🔓 Login Screen', const LoginScreen()),
      ('📝 Register Screen', const RegisterScreen()),
      ('🏠 Home Screen', const HomeScreen()),
      ('📚 Book Catalog Screen', const BookCatalogScreen()),
      ('📖 My Books Screen', const MyBooksScreen()),
      (' Transactions Screen', const TransactionsScreen()),
      ('👤 Profile Screen', const ProfileScreen()),
      ('⚙️ Admin Screen', const AdminScreen()),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Navigation'),
        backgroundColor: Colors.red,
        centerTitle: true,
      ),
      body: ListView.builder(
        itemCount: screens.length,
        itemBuilder: (context, index) {
          final (screenName, screenWidget) = screens[index];

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.all(16),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => screenWidget),
                );
              },
              child: Text(
                screenName,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          );
        },
      ),
    );
  }
}
