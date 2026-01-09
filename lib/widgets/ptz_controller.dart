import 'package:flutter/material.dart';
import '../services/eseeiot_camera_service.dart';

class PTZController extends StatelessWidget {
  final double size;
  final Color backgroundColor;
  final Color buttonColor;
  final Color activeButtonColor;
  final Color iconColor;

  const PTZController({
    super. key,
    this.size = 200,
    this. backgroundColor = Colors.black54,
    this. buttonColor = Colors. white24,
    this. activeButtonColor = Colors.blue,
    this. iconColor = Colors. white,
  });

  @override
  Widget build(BuildContext context) {
    final buttonSize = size / 3;

    return Container(
      width:  size,
      height:  size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Stack(
        children:  [
          // Up button
          Positioned(
            top:  10,
            left: size / 2 - buttonSize / 2,
            child:  _PTZButton(
              icon: Icons.keyboard_arrow_up,
              onPressed: EseeiotCameraService.ptzMoveUp,
              onReleased: EseeiotCameraService.ptzStop,
              size:  buttonSize,
              buttonColor: buttonColor,
              activeColor: activeButtonColor,
              iconColor: iconColor,
            ),
          ),
          // Down button
          Positioned(
            bottom: 10,
            left: size / 2 - buttonSize / 2,
            child: _PTZButton(
              icon: Icons. keyboard_arrow_down,
              onPressed: EseeiotCameraService.ptzMoveDown,
              onReleased: EseeiotCameraService. ptzStop,
              size: buttonSize,
              buttonColor: buttonColor,
              activeColor: activeButtonColor,
              iconColor: iconColor,
            ),
          ),
          // Left button
          Positioned(
            left: 10,
            top: size / 2 - buttonSize / 2,
            child:  _PTZButton(
              icon: Icons.keyboard_arrow_left,
              onPressed: EseeiotCameraService. ptzMoveLeft,
              onReleased: EseeiotCameraService.ptzStop,
              size: buttonSize,
              buttonColor: buttonColor,
              activeColor:  activeButtonColor,
              iconColor: iconColor,
            ),
          ),
          // Right button
          Positioned(
            right: 10,
            top: size / 2 - buttonSize / 2,
            child:  _PTZButton(
              icon: Icons.keyboard_arrow_right,
              onPressed: EseeiotCameraService. ptzMoveRight,
              onReleased: EseeiotCameraService.ptzStop,
              size: buttonSize,
              buttonColor: buttonColor,
              activeColor:  activeButtonColor,
              iconColor: iconColor,
            ),
          ),
          // Center indicator
          Center(
            child:  Container(
              width:  buttonSize * 0.8,
              height: buttonSize * 0.8,
              decoration: BoxDecoration(
                color: buttonColor,
                shape: BoxShape.circle,
                border: Border.all(color: iconColor, width: 2),
              ),
              child: Icon(
                Icons.control_camera,
                color:  iconColor. withOpacity(0.5),
                size: buttonSize * 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
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