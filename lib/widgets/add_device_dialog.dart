import 'package:flutter/material.dart';

class AddDeviceDialog extends StatefulWidget {
  final Function(String deviceId, String username, String password, int channelCount) onAdd;

  const AddDeviceDialog({super.key, required this.onAdd});

  @override
  State<AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<AddDeviceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _deviceIdController = TextEditingController();
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController();
  int _channelCount = 1;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _deviceIdController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Camera'),
      content: Form(
        key:  _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize. min,
            children: [
              TextFormField(
                controller: _deviceIdController,
                decoration: const InputDecoration(
                  labelText: 'Camera ID',
                  hintText: 'Enter camera device ID',
                  border: OutlineInputBorder(),
                ),
                validator:  (value) {
                  if (value == null || value. isEmpty) {
                    return 'Please enter camera ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller:  _usernameController,
                decoration:  const InputDecoration(
                  labelText: 'Username',
                  hintText: 'Usually "admin"',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height:  16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText:  'Camera password (leave empty if none)',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ?  Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _channelCount,
                decoration: const InputDecoration(
                  labelText: 'Channels',
                  border: OutlineInputBorder(),
                ),
                items: [1, 2, 4, 8, 16].map((count) {
                  return DropdownMenuItem(
                    value: count,
                    child: Text('$count channel${count > 1 ? 's' : ''}'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _channelCount = value;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!. validate()) {
              widget.onAdd(
                _deviceIdController.text. trim(),
                _usernameController. text.trim(),
                _passwordController. text, // Can be empty
                _channelCount,
              );
              Navigator.of(context).pop();
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}