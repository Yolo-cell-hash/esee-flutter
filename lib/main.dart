import 'package:flutter/material.dart';
import 'services/eseeiot_camera_service.dart';
import 'screens/live_view_screen.dart';
import 'widgets/add_device_dialog.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eseeiot Camera Demo',
      theme:  ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
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
  bool _sdkInitialized = false;
  bool _isLoading = false;
  final List<CameraDevice> _devices = [];

  @override
  void initState() {
    super.initState();
    _initSDK();
  }

  Future<void> _initSDK() async {
    setState(() => _isLoading = true);
    final success = await EseeiotCameraService. initializeSDK();
    setState(() {
      _sdkInitialized = success;
      _isLoading = false;
    });

    if (!success && mounted) {
      ScaffoldMessenger. of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to initialize camera SDK'),
          backgroundColor:  Colors.red,
        ),
      );
    }
  }

  Future<void> _addDevice(
      String deviceId,
      String username,
      String password,
      int channelCount,
      ) async {
    setState(() => _isLoading = true);

    final success = await EseeiotCameraService. saveCamera(
      cameraId: deviceId,
      cameraName: 'Camera ${_devices.length + 1}',
      username: username,
      password: password,
      channelCount: channelCount,
    );

    if (success) {
      setState(() {
        _devices. add(CameraDevice(
          id: deviceId,
          name: 'Camera ${_devices. length + 1}',
          username:  username,
          password: password,
          channelCount: channelCount,
        ));
      });

      if (mounted) {
        ScaffoldMessenger. of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add camera'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  void _showAddDeviceDialog() {
    showDialog(
      context:  context,
      builder: (context) => AddDeviceDialog(onAdd: _addDevice),
    );
  }

  void _openLiveView(CameraDevice device) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LiveViewScreen(
          deviceId: device. id,
          deviceName: device.name,
          username:  device.username,
          password: device. password,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('eseeiot Camera Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _buildBody(),
      floatingActionButton:  _sdkInitialized
          ? FloatingActionButton. extended(
        onPressed: _showAddDeviceDialog,
        icon: const Icon(Icons.add_a_photo),
        label:  const Text('Add Camera'),
      )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (! _sdkInitialized) {
      return Center(
        child:  Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('SDK not initialized'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed:  _initSDK,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_devices.isEmpty) {
      return Center(
        child:  Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, size: 80, color: Colors. grey[400]),
            const SizedBox(height:  16),
            Text(
              'No cameras added',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to add a camera',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount:  _devices.length,
      itemBuilder:  (context, index) {
        final device = _devices[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons. videocam)),
            title: Text(device.name),
            subtitle: Text('ID: ${device.id}'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _openLiveView(device),
          ),
        );
      },
    );
  }
}

class CameraDevice {
  final String id;
  final String name;
  final String username;
  final String password;
  final int channelCount;

  CameraDevice({
    required this.id,
    required this.name,
    required this.username,
    required this.password,
    required this. channelCount,
  });
}