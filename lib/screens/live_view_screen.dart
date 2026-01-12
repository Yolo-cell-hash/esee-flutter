import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/eseeiot_camera_service.dart';
import '../widgets/eseeiot_camera_view.dart';
import '../widgets/ptz_controller.dart'; // Import the PTZ Controller

class LiveViewScreen extends StatefulWidget {
  final String deviceId;
  final String? deviceName;
  final String username;
  final String password;

  const LiveViewScreen({
    super.key,
    required this.deviceId,
    this.deviceName,
    this.username = 'admin',
    this.password = '',
  });

  @override
  State<LiveViewScreen> createState() => _LiveViewScreenState();
}

class _LiveViewScreenState extends State<LiveViewScreen> {
  bool _isLoading = true;
  bool _isConnected = false;
  bool _showTopBar = true;
  bool _showPTZPanel = false; // Toggle for the on-screen PTZ D-pad
  bool _isLandscape = false;
  bool _isViewReady = false;
  String? _errorMessage;
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _listenToEvents();
  }

  Future<void> _initializeCamera() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await EseeiotCameraService.saveCamera(
        cameraId: widget.deviceId,
        cameraName: widget.deviceName ?? widget.deviceId,
        username: widget.username,
        password: widget.password,
      );
      final connectResult = await EseeiotCameraService.connectCamera(widget.deviceId);
      if (connectResult?['success'] != true) throw 'Connection failed';

      await EseeiotCameraService.initLiveView();
      await EseeiotCameraService.startPlay();

      setState(() { _isConnected = true; _isLoading = false; });
    } catch (e) {
      setState(() { _errorMessage = e.toString(); _isLoading = false; });
    }
  }

  void _listenToEvents() {
    _eventSubscription = EseeiotCameraService.eventStream.listen((event) {
      if (event['type'] == 'surfaceReady') setState(() => _isViewReady = true);
      if (event['type'] == 'playError') setState(() => _errorMessage = event['data']?['message']);
    });
  }

  void _toggleOrientation() {
    setState(() => _isLandscape = !_isLandscape);
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    EseeiotCameraService.stopPlay();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false, // Allow video to bleed into bottom area
        child: _buildMainStack(),
      ),
    );
  }

  Widget _buildMainStack() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.white));
    if (_errorMessage != null) return _buildErrorView();

    return Stack(
      children: [
        // 1. Video Background
        Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: EseeiotCameraView(
              deviceId: widget.deviceId,
              autoPlay: false,
              onViewReady: (_, __, ___) => setState(() => _isViewReady = true),
            ),
          ),
        ),

        // 2. PTZ Overlay Panel (The "D-Pad" logic)
        if (_showPTZPanel)
          Positioned(
            right: 20,
            bottom: 100, // Stay above the bottom action bar
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const SizedBox(
                width: 150, // Smaller size for landscape safety
                height: 150,
                child: FittedBox(child: PTZController(size: 200)),
              ),
            ),
          ),

        // 3. Top Bar (Auto-hides or Toggles)
        if (_showTopBar)
          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildTopBar(),
          ),

        // 4. Bottom Action Bar (PERMANENT)
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: _buildBottomActionBar(),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: Colors.black45,
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
          Expanded(child: Text(widget.deviceName ?? 'Live', style: const TextStyle(color: Colors.white))),
          IconButton(
            icon: Icon(_isLandscape ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white),
            onPressed: _toggleOrientation,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: Icons.camera_alt,
            label: 'Snapshot',
            onPressed: () {
              EseeiotCameraService.capture();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to Gallery')));
            },
          ),
          _buildActionButton(
            icon: _showPTZPanel ? Icons.close : Icons.control_camera,
            label: 'PTZ',
            color: _showPTZPanel ? Colors.blue : Colors.white,
            onPressed: () => setState(() => _showPTZPanel = !_showPTZPanel),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onPressed, Color color = Colors.white}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(icon: Icon(icon, color: color, size: 28), onPressed: onPressed),
        Text(label, style: TextStyle(color: color, fontSize: 10)),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_errorMessage!, style: const TextStyle(color: Colors.white)),
          ElevatedButton(onPressed: _initializeCamera, child: const Text('Retry')),
        ],
      ),
    );
  }
}