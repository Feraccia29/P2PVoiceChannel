import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/call_provider.dart';
import 'screens/call_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CallProvider(),
      child: MaterialApp(
        title: 'VoIP P2P',
        theme: ThemeData.dark(),
        home: const CallScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
