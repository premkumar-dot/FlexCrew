import 'package:flutter/material.dart';
import 'widgets/brand_appbar.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlexCrew',
      home: Scaffold(
        appBar: const BrandAppBar(
          title: 'FlexCrew',
          tagline: 'Your Crew. On Demand',
        ),
        body: const Center(child: Text('Hello')),
      ),
    );
  }
}
