import 'package:flutter/material.dart';

class StudyPlaceholderScreen extends StatelessWidget {
  const StudyPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_outlined, size: 72),
            SizedBox(height: 16),
            Text('Study mode coming in Prompt 6'),
          ],
        ),
      ),
    );
  }
}
