import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rank5/features/webview_controller.dart';

void main() async {
  runApp(const Rank5App());

  await SystemChrome.setPreferredOrientations(
    [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ],
  );

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.light
  );
}

class Rank5App extends StatelessWidget {
  const Rank5App({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '랭킹5',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        visualDensity: VisualDensity.adaptivePlatformDensity
        //useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const WebviewController(),
    );
  }
}
