import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:website/pages/main_page.dart';

void main() {
  runApp(const InitializationApp());
}

class InitializationApp extends StatefulWidget {
  const InitializationApp({super.key});

  @override
  State<InitializationApp> createState() => _InitializationAppState();
}

class _InitializationAppState extends State<InitializationApp> {
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeSupabase();
  }

  Future<void> _initializeSupabase() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      await Supabase.initialize(
        // url: 'https://dydljotghohsukyukpwp.supabase.co',
        url: 'https://ojfkxgjrjivxrvqewlhr.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9qZmt4Z2pyaml2eHJ2cWV3bGhyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5NjU1ODEsImV4cCI6MjA5MjU0MTU4MX0.1x9LrlAef5Wp10tb9XM0yquH4Eih_tccofnsGGup9ps',
      );
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to connect to database: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: Colors.green.withValues(alpha: 0.3),
          primarySwatch: Colors.green,
        ),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Connection Error',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                        _initializeSupabase();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return MaterialApp(
        theme: ThemeData(
          scaffoldBackgroundColor: Colors.green.withValues(alpha: 0.3),
          primarySwatch: Colors.green,
        ),
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'Living Heritage Uganda',
      theme: ThemeData(
        // Your original theme restored exactly as you had it
        scaffoldBackgroundColor: Colors.green.withValues(alpha: 0.3),
      ),
      home: const MainPage(),
    );
  }
}
