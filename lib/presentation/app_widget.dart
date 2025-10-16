import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:upmoo25/application/app_widget/app_provider.dart';
import 'package:upmoo25/domain/di/dependency_manager.dart';
import 'package:upmoo25/infrastructure/services/local_storage.dart';
import 'package:upmoo25/presentation/theme/app_style.dart';
import 'package:app_links/app_links.dart';

import 'components/custom_range_slider.dart';
import 'routes/app_router.dart';
import 'package:upmoo25/infrastructure/services/deep_links.dart';

// Custom route information provider that always starts at splash
class FixedRouteInformationProvider extends RouteInformationProvider {
  @override
  RouteInformation get value => const RouteInformation(location: '/');
  
  @override
  void addListener(VoidCallback listener) {
    // No-op - we never change
  }
  
  @override
  void removeListener(VoidCallback listener) {
    // No-op - we never change
  }
}

class AppWidget extends ConsumerWidget {
  AppWidget({super.key});

  final appRouter = AppRouter();
  
  // Custom route information provider that always starts at splash
  RouteInformationProvider _createRouteInformationProvider() {
    return FixedRouteInformationProvider();
  }

  Future fetchSetting() async {
    final connect = await Connectivity().checkConnectivity();
    if (connect.contains(ConnectivityResult.mobile) ||
        connect.contains(ConnectivityResult.ethernet) ||
        connect.contains(ConnectivityResult.wifi)) {
      settingsRepository.getGlobalSettings();
      await settingsRepository.getLanguages();
      await settingsRepository.getMobileTranslations();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.refresh(appProvider);
    return FutureBuilder(
        future: Future.wait([
          FlutterDisplayMode.setHighRefreshRate(),
          if (LocalStorage.getTranslations().isEmpty) fetchSetting()
        ]),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          // Initialize deep link handling when app is ready
          if (snapshot.connectionState == ConnectionState.done) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Initialize deep links after the app is set up
              // Add a delay to ensure the router is fully initialized
              Future.delayed(const Duration(milliseconds: 1000), () {
                DeepLinksHandler.instance.initialize(appRouter);
              });
            });
          }
          
          return ScreenUtilInit(
            useInheritedMediaQuery: false,
            designSize: const Size(375, 812),
            builder: (context, child) {
              return RefreshConfiguration(
                footerBuilder: () => const ClassicFooter(
                  idleIcon: SizedBox(),
                  idleText: "",
                ),
                headerBuilder: () => const WaterDropMaterialHeader(
                  backgroundColor: AppStyle.white,
                  color: AppStyle.textGrey,
                ),
                child: MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  routerDelegate: appRouter.delegate(),
                  routeInformationParser: appRouter.defaultRouteParser(),
                  routeInformationProvider: _createRouteInformationProvider(),
                  locale: Locale(state.activeLanguage?.locale ?? 'en'),
                  theme: ThemeData(
                    useMaterial3: false,
                    sliderTheme: SliderThemeData(
                      overlayShape: SliderComponentShape.noOverlay,
                      rangeThumbShape: CustomRoundRangeSliderThumbShape(
                        enabledThumbRadius: 12.r,
                      ),
                    ),
                  ),
                  themeMode:
                      state.isDarkMode ? ThemeMode.dark : ThemeMode.light,
                ),
              );
            },
          );
        });
  }
}
