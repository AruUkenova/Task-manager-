import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'db/app_dao.dart';
import 'db/app_database.dart';
import 'screens/tasks_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final AppDatabase db = AppDatabase();

  runApp(MyApp(db: db));
}

class MyApp extends StatelessWidget {
  final AppDatabase db;

  const MyApp({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    return Provider<AppDao>(
      create: (_) => AppDao(db),
      dispose: (_, dao) async {
        await dao.attachedDatabase.close(); // <-- FIX
      },
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: const TasksScreen(),
      ),
    );
  }
}