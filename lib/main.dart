import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodyman/infrastructure/services/local_storage.dart';
import 'package:foodyman/presentation/theme/theme.dart';
import 'domain/di/dependency_manager.dart';
import 'presentation/app_widget.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:smartlook/smartlook.dart'; 

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Smartlook.setupAndStartRecording('fe7978d3b0a4b6609df9d966a04ccb9346e8a012'); 
  Smartlook.setupAndStartRecording(
      SetupOptionsBuilder('fe7978d3b0a4b6609df9d966a04ccb9346e8a012').build(),
  );

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
      overlays: SystemUiOverlay.values);
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppStyle.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.dark,
    ),
  );
  await LocalStorage.init();
  setUpDependencies();
  runApp(ProviderScope(child: AppWidget()));
}