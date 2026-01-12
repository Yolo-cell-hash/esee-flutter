import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/eseeiot_camera_service.dart';
import '../widgets/eseeiot_camera_view.dart';

class LiveViewScreen extends StatefulWidget {
  final String deviceId;
  final String?  deviceName;
  final String username;
  final String password;

  const LiveViewScreen({
    super.key,
    required this. deviceId,
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
  bool _showControls = true;
  bool _isLandscape = false;
  bool _isViewReady = false;
  String?  _errorMessage;
  Timer? _hideControlsTimer;
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _listenToEvents();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // First, save the camera with credentials (in case it wasn't saved before)
      final saveResult = await EseeiotCameraService.saveCamera(
        cameraId: widget.deviceId,
        cameraName: widget.deviceName ??  widget.deviceId,
        username: widget. username,
        password: widget. password,
      );

      if (! saveResult) {
        setState(() {
          _errorMessage = 'Failed to save camera configuration';
          _isLoading = false;
        });
        return;
      }

      // Connect to the camera
      final connectResult = await EseeiotCameraService.connectCamera(widget.deviceId);
      if (connectResult == null || connectResult['success'] != true) {
        setState(() {
          _errorMessage = 'Failed to connect to camera';
          _isLoading = false;
        });
        return;
      }

      // Initialize live view
      final initResult = await EseeiotCameraService. initLiveView();
      if (!initResult) {
        setState(() {
          _errorMessage = 'Failed to initialize live view';
          _isLoading = false;
        });
        return;
      }

      // Start playback
      final startResult = await EseeiotCameraService.startPlay();
      if (!startResult) {
        setState(() {
          _errorMessage = 'Failed to start playback';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _isConnected = true;
        _isLoading = false;
      });
      _startHideControlsTimer();

    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _listenToEvents() {
    _eventSubscription = EseeiotCameraService.eventStream.listen((event) {
      final type = event['type'] as String? ;
      final data = event['data'] as Map<String, dynamic>?;

      print('Camera event: $type, data: $data');

      switch (type) {
        case 'playError':
          setState(() {
            _errorMessage = data? ['message'] ?? 'Playback error';
          });
          break;
        case 'playbackStarted':
          setState(() {
            _isConnected = true;
          });
          break;
        case 'surfaceReady':
          print('Surface ready:  ${data?['width']}x${data?['height']}');
          setState(() {
            _isViewReady = true;
          });
          break;
        case 'liveViewInitialized':
          print('Live view initialized');
          break;
      }
    });
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?. cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startHideControlsTimer();
    }
  }

  void _toggleOrientation() {
    setState(() => _isLandscape = !_isLandscape);
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation. landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _eventSubscription?.cancel();
    EseeiotCameraService.stopPlay();
    EseeiotCameraService.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation. portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode. edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Connecting to camera.. .',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child:  Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign. center,
              ),
              const SizedBox(height: 24),
              ElevatedButton. icon(
                onPressed: _initializeCamera,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        children: [
          // Native Camera View - This is the actual video stream!
          Center(
            child: Container(
              color: Colors.black,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _isConnected
                    ? EseeiotCameraView(
                  deviceId: widget.deviceId,
                  autoPlay: false, // We already started playback via service
                  onViewReady: (width, height, channelCount) {
                    print('Camera view ready:  ${width}x$height, channels: $channelCount');
                    setState(() {
                      _isViewReady = true;
                    });
                  },
                  onError: (error) {
                    print('Camera view error: $error');
                    setState(() {
                      _errorMessage = error;
                    });
                  },
                )
                    : const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
          ),

          // Loading overlay while view initializes
          if (_isConnected && ! _isViewReady)
            Center(
              child: Container(
                color: Colors.black54,
                child: const Column(
                  mainAxisAlignment:  MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Loading video stream...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

          // Controls overlay
          if (_showControls) ...[
            // Top bar
            Positioned(
              top:  0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        widget.deviceName ?? 'Camera',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isLandscape ? Icons.fullscreen_exit : Icons.fullscreen,
                        color: Colors. white,
                      ),
                      onPressed: _toggleOrientation,
                    ),
                  ],
                ),
              ),
            ),

            // Bottom controls
            Positioned(
              bottom: 0,
              left:  0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end:  Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(
                      icon: Icons.camera_alt,
                      label:  'Snapshot',
                      onPressed: () async {
                        await EseeiotCameraService. capture();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Snapshot captured')),
                          );
                        }
                      },
                    ),
                    _buildControlButton(
                      icon: Icons.control_camera,
                      label: 'PTZ',
                      onPressed:  () => _showPTZDialog(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.white, size: 32),
          onPressed: onPressed,
        ),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  void _showPTZDialog() {
    showModalBottomSheet(
      context:  context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize:  MainAxisSize.min,
          children: [
            const Text(
              'PTZ Control',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildPTZControls(),
            const SizedBox(height:  24),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPTZControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Up button
        _buildPTZButton(
          icon: Icons.arrow_upward,
          onPressed: EseeiotCameraService.ptzMoveUp,
          onReleased: EseeiotCameraService.ptzStop,
        ),
        const SizedBox(height: 8),
        // Left, Center, Right
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPTZButton(
              icon: Icons.arrow_back,
              onPressed: EseeiotCameraService.ptzMoveLeft,
              onReleased: EseeiotCameraService.ptzStop,
            ),
            const SizedBox(width: 48),
            _buildPTZButton(
              icon: Icons. arrow_forward,
              onPressed: EseeiotCameraService.ptzMoveRight,
              onReleased: EseeiotCameraService.ptzStop,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Down button
        _buildPTZButton(
          icon: Icons.arrow_downward,
          onPressed: EseeiotCameraService.ptzMoveDown,
          onReleased: EseeiotCameraService.ptzStop,
        ),
      ],
    );
  }

  Widget _buildPTZButton({
    required IconData icon,
    required Future<bool> Function() onPressed,
    required Future<bool> Function() onReleased,
  }) {
    return GestureDetector(
      onTapDown: (_) => onPressed(),
      onTapUp: (_) => onReleased(),
      onTapCancel: () => onReleased(),
      child: Container(
        width: 56,
        height:  56,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }
}