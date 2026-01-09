import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

class EseeiotCameraView extends StatefulWidget {
  final String deviceId;
  final bool autoPlay;
  final Function(int width, int height, int channelCount)? onViewReady;
  final Function(String error)? onError;

  const EseeiotCameraView({
    super.key,
    required this.deviceId,
    this. autoPlay = true,
    this. onViewReady,
    this.onError,
  });

  @override
  State<EseeiotCameraView> createState() => _EseeiotCameraViewState();
}

class _EseeiotCameraViewState extends State<EseeiotCameraView> {
  MethodChannel? _channel;
  bool _isReady = false;

  @override
  Widget build(BuildContext context) {
    return AndroidView(
      viewType: 'eseeiot_camera_view',
      creationParams: {
        'deviceId': widget.deviceId,
      },
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onPlatformViewCreated,
      gestureRecognizers:  <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
        ),
      },
    );
  }

  void _onPlatformViewCreated(int viewId) {
    _channel = MethodChannel('eseeiot_camera_view_$viewId');
    _channel! .setMethodCallHandler(_handleMethodCall);

    if (widget. autoPlay) {
      _startPlayback();
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onViewReady':
        final args = Map<String, dynamic>. from(call.arguments);
        setState(() => _isReady = true);
        widget.onViewReady?.call(
          args['width'] as int,
          args['height'] as int,
          args['channelCount'] as int,
        );
        break;
      case 'onError':
        widget.onError?.call(call.arguments['message'] as String);
        break;
    }
  }

  Future<void> _startPlayback() async {
    await _channel?. invokeMethod('startPlayback');
  }

  Future<void> stopPlayback() async {
    await _channel?.invokeMethod('stopPlayback');
  }

  @override
  void dispose() {
    _channel?.invokeMethod('stopPlayback');
    super.dispose();
  }
}