import 'package:flutter/material.dart';
import '../services/eseeiot_camera_service.dart';

class PTZController extends StatelessWidget {
  final double size;
  final Color backgroundColor;
  final Color buttonColor;
  final Color activeButtonColor;
  final Color iconColor;
  const PTZController({
    super.key,
    this.size = 200,
    this.backgroundColor = Colors.black54,
    this.buttonColor = Colors.white24,
    this.activeButtonColor = Colors.blue,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    // Wrap in a FittedBox to ensure it never "falls out" of its allocated space
    return SizedBox(
      width: size,
      height: size,
      child: FittedBox(
        child: Container(
          width: 200, // Internal fixed coordinate system
          height: 200,
          decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
          child: Stack(
            clipBehavior: Clip.none, // Prevent clipping if icons slightly overlap
            children: [
              _positionedButton(Alignment.topCenter, Icons.keyboard_arrow_up, EseeiotCameraService.ptzMoveUp),
              _positionedButton(Alignment.bottomCenter, Icons.keyboard_arrow_down, EseeiotCameraService.ptzMoveDown),
              _positionedButton(Alignment.centerLeft, Icons.keyboard_arrow_left, EseeiotCameraService.ptzMoveLeft),
              _positionedButton(Alignment.centerRight, Icons.keyboard_arrow_right, EseeiotCameraService.ptzMoveRight),
              const Center(child: Icon(Icons.control_camera, color: Colors.white24, size: 30)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _positionedButton(Alignment alignment, IconData icon, Future<bool> Function() action) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: _PTZButton(
          icon: icon,
          onPressed: action,
          onReleased: EseeiotCameraService.ptzStop,
          size: 50,
          buttonColor: buttonColor,
          activeColor: activeButtonColor,
          iconColor: iconColor,
        ),
      ),
    );
  }

// Note: Keep the existing _PTZButton class from your original file
}

class _PTZButton extends StatefulWidget {
  final IconData icon;
  final Future<bool> Function() onPressed;
  final Future<bool> Function() onReleased;
  final double size;
  final Color buttonColor;
  final Color activeColor;
  final Color iconColor;

  const _PTZButton({
    required this.icon,
    required this.onPressed,
    required this.onReleased,
    required this.size,
    required this.buttonColor,
    required this.activeColor,
    required this. iconColor,
  });

  @override
  State<_PTZButton> createState() => _PTZButtonState();
}

class _PTZButtonState extends State<_PTZButton> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    widget.onPressed();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    widget.onReleased();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    widget.onReleased();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp:  _onTapUp,
      onTapCancel: _onTapCancel,
      child:  AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color:  _isPressed ? widget. activeColor : widget. buttonColor,
          shape: BoxShape. circle,
        ),
        child: Icon(
          widget. icon,
          color: widget.iconColor,
          size:  widget.size * 0.6,
        ),
      ),
    );
  }
}