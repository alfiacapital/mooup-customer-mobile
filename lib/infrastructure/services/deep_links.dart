import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:app_links/app_links.dart';
import 'package:foodyman/presentation/routes/app_router.dart';

class DeepLinksHandler {
  DeepLinksHandler._internal();
  static final DeepLinksHandler instance = DeepLinksHandler._internal();

  StreamSubscription<Uri>? _subscription;
  bool _initialized = false;
  AppLinks? _appLinks;
  Uri? _pendingInitialLink;
  StackRouter? _router;

  Future<void> initialize(StackRouter router) async {
    if (_initialized) return;
    _initialized = true;
    _router = router;

    try {
      _appLinks = AppLinks();
      final initialUri = await _appLinks!.getInitialLink();
      if (initialUri != null) {
        _pendingInitialLink = initialUri;
        // Wait for app to be fully loaded, then process the link
        Timer(const Duration(seconds: 3), () {
          processPendingLink();
        });
      }
    } catch (_) {}

    _subscription = _appLinks!.uriLinkStream.listen((Uri uri) async {
      await _handleUri(router, uri);
    }, onError: (_) {}, cancelOnError: false);
  }

  Future<void> processPendingLink() async {
    if (_pendingInitialLink != null && _router != null) {
      final link = _pendingInitialLink!;
      _pendingInitialLink = null;
      await _handleUri(_router!, link);
    }
  }

  Future<void> _handleUri(StackRouter router, Uri? uri) async {
    if (uri == null) return;

    // Skip if this is a Firebase Dynamic Link (they have specific patterns)
    if (uri.host.contains('firebase') || uri.host.contains('goo.gl') || uri.host.contains('page.link')) {
      return;
    }

    String? shopId = uri.queryParameters['restaurantId'] ?? uri.queryParameters['shopId'];

    if (shopId == null && uri.pathSegments.isNotEmpty) {
      final first = uri.pathSegments.first;
      if ((first == 'restaurant' || first == 'shop') && uri.pathSegments.length >= 2) {
        shopId = uri.pathSegments[1];
      }
    }

    if (shopId != null && shopId.isNotEmpty) {
      // Navigate to the shop page
      // Use push instead of replace so it stacks correctly from splash/home
      // If you want to avoid duplicates, you could inspect router.stack
      await router.push(ShopRoute(shopId: shopId));
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;
    _pendingInitialLink = null;
    _router = null;
  }
}


