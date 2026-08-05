import 'package:flutter/material.dart';

class StatsPlaceholderScreen extends StatelessWidget {
  const StatsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_outlined, size: 72),
            SizedBox(height: 16),
            Text('Statistics coming in Prompt 7'),
          ],
        ),
      ),
    );
  }
}
