import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/task_detail_screen.dart';
import 'screens/demo_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'タスク管理アプリ',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'NotoSansJP'),
      home: const DemoScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
