import 'package:flutter/material.dart';

class ConfigurationErrorScreen extends StatelessWidget {
  const ConfigurationErrorScreen({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        backgroundColor: const Color(0xFF101113),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.settings_ethernet_rounded,
                    size: 64,
                    color: Color(0xFFFF6B4A),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Chưa kết nối máy chủ âm nhạc',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFB5B6BA)),
                  ),
                  const SizedBox(height: 18),
                  const SelectableText(
                    'Build với --dart-define=API_BASE_URL=https://proxy.example.com',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFB8F43D),
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
