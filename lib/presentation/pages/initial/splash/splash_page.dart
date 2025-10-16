import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:upmoo25/presentation/routes/app_router.dart';
import 'package:upmoo25/application/splash/splash_provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

@RoutePage()
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Simple approach: just proceed with normal splash logic
      // The deep link handler will handle navigation if needed
      debugPrint('SplashPage: Starting splash logic');
      ref.read(splashProvider.notifier).getTranslations(context);
      ref.read(splashProvider.notifier).getToken(context, goMain: () {
        debugPrint('SplashPage: goMain called - navigating to MainRoute');
        FlutterNativeSplash.remove();
        context.replaceRoute(const MainRoute());
      }, goLogin: () {
        debugPrint('SplashPage: goLogin called - navigating to LoginRoute');
        FlutterNativeSplash.remove();
        context.replaceRoute(const LoginRoute());
      }, goNoInternet: () {
        debugPrint('SplashPage: goNoInternet called - navigating to NoConnectionRoute');
        FlutterNativeSplash.remove();
        context.replaceRoute(const NoConnectionRoute());
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      "assets/images/splash.png",
      fit: BoxFit.fill,
    );
  }
}
