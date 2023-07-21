// ignore_for_file: avoid_print

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rank5/features/webview_controller.dart';
import 'package:url_launcher/url_launcher.dart';

void launchURL() async {
  const url = "rank5://kr.sogeum.rank5";

  if (await canLaunchUrl(Uri.parse(url))) {
    await launchUrl(Uri.parse(url));
  } else {
    throw "Can not launch $url";
  }
}

Future<void> _requestLocationPermission() async {
  await Permission.location.request();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); /// Firebase 연동 시 필히 import
  await Firebase.initializeApp(); /// Firebase State 초기화

  bool data = await fetchData();
  print(data);

  await _requestLocationPermission();

  runZonedGuarded(() async {}, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack);
  });

  await SystemChrome.setPreferredOrientations(
    [DeviceOrientation.portraitUp],
  );

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  runApp(const Rank5App());
}

class Rank5App extends StatelessWidget {
  const Rank5App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '랭킹5',
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          primaryColor: const Color(0xFF0AE5AC),
          visualDensity: VisualDensity.adaptivePlatformDensity
          //useMaterial3: true,
          ),
      debugShowCheckedModeBanner: false,
      home: const WebviewController(),
    );
  }
}

// Splash Screen
Future<bool> fetchData() async {
  bool data = false;

  await Future.delayed(
      const Duration(
        seconds: 1,
      ), () {
    data = true;
  });

  return data;
}
