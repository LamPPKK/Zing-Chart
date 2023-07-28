import 'package:flutter/material.dart';
import 'zing_chart_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zing MP3 Chart',
      home: ZingChartScreen(),
    );
  }
}