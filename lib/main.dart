import 'package:flutter/material.dart';
import 'services/eseeiot_camera_service.dart';
import 'screens/live_view_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eseeiot Camera Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // App starts here and will automatically redirect
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 1. Initialize the SDK first
    final success = await EseeiotCameraService.initializeSDK();

    if (success && mounted) {
      // 2. Once initialized, push the LiveViewScreen directly with your config
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const LiveViewScreen(
            deviceId: '6659244802',
            deviceName: 'Main Camera',
            username: 'admin',
            password: '', // Empty string as requested
          ),
        ),
      );
    } else if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to initialize camera SDK';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _isLoading
            ? const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text('Initializing Camera System...',
                style: TextStyle(fontSize: 16)),
          ],
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage ?? 'An error occurred'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeAndNavigate,
              child: const Text('Retry Connection'),
            ),
          ],
        ),
      ),
    );
  }
}