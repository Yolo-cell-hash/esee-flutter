import 'dart:async';
import 'package:flutter/services.dart';

class EseeiotCameraService {
  static const MethodChannel _channel = MethodChannel('eseeiot_camera');
  static const EventChannel _eventChannel = EventChannel('eseeiot_camera_events');

  static Stream<Map<String, dynamic>>? _eventStream;
  static bool _isInitialized = false;

  /// Initialize the eseeiot SDK
  static Future<bool> initializeSDK() async {
    if (_isInitialized) {
      print('SDK already initialized');
      return true;
    }

    try {
      final result = await _channel. invokeMethod('initializeSDK');
      _isInitialized = result['success'] == true;
      print('SDK initialization result: $_isInitialized');
      return _isInitialized;
    } catch (e) {
      print('Error initializing SDK: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Save/Register a camera with DeviceManager
  static Future<bool> saveCamera({
    required String cameraId,
    String cameraName = '',
    String username = 'admin',
    String password = '',  // Empty by default
    int channelCount = 1,
  }) async {
    if (! _isInitialized) {
      print('SDK not initialized, initializing now...');
      final initResult = await initializeSDK();
      if (!initResult) {
        print('Failed to initialize SDK');
        return false;
      }
    }

    try {
      print('Saving camera:  id=$cameraId, user=$username, pwd=${password.isEmpty ?  "(empty)" : "(set)"}');

      final result = await _channel.invokeMethod('saveCamera', {
        'cameraId': cameraId,
        'cameraName': cameraName. isEmpty ? cameraId : cameraName,
        'username': username,
        'password': password,
        'channelCount': channelCount,
      });

      final success = result['success'] == true;
      print('Save camera result: $success');
      return success;
    } catch (e) {
      print('Error saving camera: $e');
      return false;
    }
  }

  /// Connect to a camera
  static Future<Map<String, dynamic>?> connectCamera(String cameraId) async {
    if (!_isInitialized) {
      await initializeSDK();
    }

    try {
      final result = await _channel.invokeMethod('connectCamera', {
        'cameraId': cameraId,
      });
      return Map<String, dynamic>. from(result);
    } catch (e) {
      print('Error connecting camera:  $e');
      return null;
    }
  }

  static Future<bool> initLiveView() async {
    try {
      final result = await _channel. invokeMethod('initLiveView');
      return result['success'] == true;
    } catch (e) {
      print('Error initializing live view: $e');
      return false;
    }
  }

  static Future<bool> startPlay() async {
    try {
      final result = await _channel.invokeMethod('startPlay');
      return result['success'] == true;
    } catch (e) {
      print('Error starting play: $e');
      return false;
    }
  }

  static Future<bool> stopPlay() async {
    try {
      final result = await _channel.invokeMethod('stopPlay');
      return result['success'] == true;
    } catch (e) {
      print('Error stopping play: $e');
      return false;
    }
  }

  static Future<bool> ptzMoveUp() async {
    try {
      await _channel.invokeMethod('ptzMoveUp');
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> ptzMoveDown() async {
    try {
      await _channel.invokeMethod('ptzMoveDown');
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> ptzMoveLeft() async {
    try {
      await _channel.invokeMethod('ptzMoveLeft');
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> ptzMoveRight() async {
    try {
      await _channel.invokeMethod('ptzMoveRight');
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> ptzStop() async {
    try {
      await _channel.invokeMethod('ptzStop');
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> capture() async {
    try {
      await _channel.invokeMethod('capture');
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> dispose() async {
    try {
      await _channel.invokeMethod('dispose');
      return true;
    } catch (e) {
      return false;
    }
  }

  static Stream<Map<String, dynamic>> get eventStream {
    _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>. from(event));
    return _eventStream! ;
  }
}