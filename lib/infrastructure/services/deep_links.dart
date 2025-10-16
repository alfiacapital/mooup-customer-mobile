import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:app_links/app_links.dart';
import 'package:upmoo25/presentation/routes/app_router.dart';
import 'package:flutter/foundation.dart';

class DeepLinksHandler {
  DeepLinksHandler._internal();
  static final DeepLinksHandler instance = DeepLinksHandler._internal();

  StreamSubscription<Uri>? _subscription;
  bool _initialized = false;
  AppLinks? _appLinks;
  Uri? _pendingInitialLink;
  StackRouter? _router;
  bool _splashCompleted = false;

  Future<void> initialize(StackRouter router) async {
    if (_initialized) return;
    debugPrint('DeepLinksHandler: Initializing...');
    _initialized = true;
    _router = router;

    try {
      _appLinks = AppLinks();
      final initialUri = await _appLinks!.getInitialLink();
      if (initialUri != null) {
        debugPrint('DeepLinksHandler: Found initial link: $initialUri');
        _pendingInitialLink = initialUri;
        // Process the deep link immediately since it was intercepted by the router
        debugPrint('DeepLinksHandler: Processing deep link immediately');
        _splashCompleted = true; // Mark as completed since we're processing immediately
        
        // Wait a bit for the router to be ready
        Timer(const Duration(milliseconds: 500), () {
          processPendingLink();
        });
      } else {
        debugPrint('DeepLinksHandler: No initial link found');
      }
    } catch (e) {
      debugPrint('DeepLinksHandler: Error during initialization: $e');
    }

    _subscription = _appLinks!.uriLinkStream.listen((Uri uri) async {
      debugPrint('DeepLinksHandler: Received URI stream: $uri');
      // Process stream links immediately since they're intercepted by the router
      await _handleUri(router, uri);
    }, onError: (e) {
      debugPrint('DeepLinksHandler: Error in URI stream: $e');
    }, cancelOnError: false);
    
    debugPrint('DeepLinksHandler: Initialization complete');
  }

  Future<void> processPendingLink() async {
    if (_pendingInitialLink != null) {
      final link = _pendingInitialLink!;
      _pendingInitialLink = null;
      
      debugPrint('DeepLinksHandler: Processing pending link: $link');
      await _handleUri(_router!, link);
    }
  }

  Future<void> _handleUri(StackRouter router, Uri? uri) async {
    if (uri == null) return;

    debugPrint('DeepLinksHandler: Processing URI: $uri');

   // Skip if this is a Firebase Dynamic Link
    if (uri.host.contains('firebase') || uri.host.contains('goo.gl') || uri.host.contains('page.link')) {
      debugPrint('DeepLinksHandler: Skipping Firebase Dynamic Link');
      return;
    }

    // Handle the /open-app deep link - just open the app
    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'open-app') {
      debugPrint('DeepLinksHandler: Processing /open-app deep link - opening app');
      
      try {
        // Simple approach: just try to navigate to main route
        await router.replace(const MainRoute());
        debugPrint('DeepLinksHandler: Successfully navigated to MainRoute');
      } catch (e) {
        debugPrint('DeepLinksHandler: Error navigating to MainRoute: $e');
        // If replace fails, try push
        try {
          await router.push(const MainRoute());
          debugPrint('DeepLinksHandler: Successfully pushed MainRoute');
        } catch (e2) {
          debugPrint('DeepLinksHandler: Both navigation methods failed: $e2');
        }
      }
      return;
    }

         // Handle shop/restaurant deep links
     if (uri.pathSegments.isNotEmpty) {
       final first = uri.pathSegments.first;
       
       if (first == 'shop' || first == 'restaurant') {
         if (uri.pathSegments.length >= 2) {
           final shopId = uri.pathSegments[1];
           
           // Check if this is a product link: /shop/:shopId/product/:productId or /restaurant/:shopId/product/:productId
           if (uri.pathSegments.length >= 4 && uri.pathSegments[2] == 'product') {
             final productId = uri.pathSegments[3];
             debugPrint('DeepLinksHandler: Processing product link - Shop ID: $shopId, Product ID: $productId');
             
             try {
               // Navigate to shop with product ID - the shop page will automatically show the product modal
               await router.push(ShopRoute(shopId: shopId, productId: productId));
               debugPrint('DeepLinksHandler: Successfully navigated to ShopRoute with Shop ID: $shopId and Product ID: $productId');
               
             } catch (e) {
               debugPrint('DeepLinksHandler: Error navigating to shop for product: $e');
               // Fallback: try to navigate to main route
               try {
                 await router.push(const MainRoute());
                 debugPrint('DeepLinksHandler: Fallback navigation to MainRoute successful');
               } catch (e2) {
                 debugPrint('DeepLinksHandler: Fallback navigation also failed: $e2');
               }
             }
             return;
           }
           
           // Regular shop link (no product)
           debugPrint('DeepLinksHandler: Processing shop link - ID: $shopId');
           
           try {
             await router.push(ShopRoute(shopId: shopId));
             debugPrint('DeepLinksHandler: Successfully navigated to ShopRoute with ID: $shopId');
           } catch (e) {
             debugPrint('DeepLinksHandler: Error navigating to shop: $e');
             // Fallback: try to navigate to main route
             try {
               await router.push(const MainRoute());
               debugPrint('DeepLinksHandler: Fallback navigation to MainRoute successful');
             } catch (e2) {
               debugPrint('DeepLinksHandler: Fallback navigation also failed: $e2');
             }
           }
           return;
         } else {
           debugPrint('DeepLinksHandler: Shop link missing ID, navigating to main');
           try {
             await router.push(const MainRoute());
           } catch (e) {
             debugPrint('DeepLinksHandler: Error navigating to main: $e');
           }
           return;
         }
       }
     }

    // Handle other deep links with query parameters (legacy support)
    String? shopId = uri.queryParameters['restaurantId'] ?? uri.queryParameters['shopId'];
    if (shopId != null && shopId.isNotEmpty) {
      debugPrint('DeepLinksHandler: Processing shop link with query parameter - ID: $shopId');
      try {
        await router.push(ShopRoute(shopId: shopId));
        debugPrint('DeepLinksHandler: Successfully navigated to ShopRoute with query ID: $shopId');
      } catch (e) {
        debugPrint('DeepLinksHandler: Error navigating to shop with query: $e');
      }
      return;
    }

    // If we get here, it's an unknown deep link
    debugPrint('DeepLinksHandler: Unknown deep link format: $uri');
    // Navigate to main route as fallback
    try {
      await router.push(const MainRoute());
      debugPrint('DeepLinksHandler: Fallback navigation to MainRoute for unknown link');
    } catch (e) {
      debugPrint('DeepLinksHandler: Fallback navigation failed: $e');
    }
     }



   Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;
    _pendingInitialLink = null;
    _router = null;
    _splashCompleted = false;
  }
}


