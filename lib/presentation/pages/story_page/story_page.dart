import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jiffy/jiffy.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:foodyman/application/home/home_provider.dart';
import 'package:foodyman/infrastructure/models/data/story_data.dart';
import 'package:foodyman/infrastructure/services/app_helpers.dart';
import 'package:foodyman/infrastructure/services/tr_keys.dart';
import 'package:foodyman/presentation/components/buttons/custom_button.dart';
import 'package:foodyman/presentation/components/loading.dart';
import 'package:foodyman/presentation/components/shop_avarat.dart';
import 'package:foodyman/presentation/routes/app_router.dart';
import 'package:foodyman/presentation/theme/app_style.dart';

bool isVideo(String? url) {
  if (url == null) return false;
  final lower = url.toLowerCase();
  return lower.endsWith(".mp4") ||
      lower.endsWith(".mov") ||
      lower.endsWith(".webm") ||
      lower.endsWith(".mkv");
}

@RoutePage()
class StoryListPage extends StatefulWidget {
  final RefreshController controller;
  final int index;

  const StoryListPage({super.key, required this.index, required this.controller});

  @override
  State<StoryListPage> createState() => _StoryListPageState();
}

class _StoryListPageState extends State<StoryListPage> {
  PageController? pageController;

  @override
  void initState() {
    pageController = PageController(initialPage: widget.index);
    super.initState();
  }

  @override
  void dispose() {
    pageController!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      final stories = ref.watch(homeProvider).story;
      return PageView.builder(
        controller: pageController,
        itemCount: stories?.length ?? 0,
        physics: const PageScrollPhysics(),
        itemBuilder: (context, index) {
          return StoryPage(
            story: stories?[index],
            nextPage: () {
              if (index == (stories?.length ?? 0) - 2) {
                ref.read(homeProvider.notifier).fetchStorePage(context, widget.controller);
              }
              if (index != (stories?.length ?? 0) - 1) {
                pageController!.animateToPage(++index,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeIn);
                setState(() {});
              } else {
                context.maybePop();
              }
            },
            prevPage: () {
              if (index != 0) {
                pageController!.animateToPage(--index,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeIn);
                setState(() {});
              } else {
                context.maybePop();
              }
            },
          );
        },
      );
    });
  }
}

class StoryPage extends StatefulWidget {
  final List<StoryModel?>? story;
  final VoidCallback nextPage;
  final VoidCallback prevPage;

  const StoryPage({super.key, required this.story, required this.nextPage, required this.prevPage});

  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> with TickerProviderStateMixin {
  late AnimationController controller;
  GlobalKey imageKey = GlobalKey();
  int currentIndex = 0;

  // WebView controller & last loaded url
  WebViewController? _webViewController;
  Key _videoWebKey = UniqueKey();
  String? _lastLoadedVideoUrl;

  void _updateCurrentIndex(int newIndex) {
    currentIndex = newIndex;
    controller.reset();
    controller.forward();
    _webViewController = null;      // <-- Reset controller
    _videoWebKey = UniqueKey();     // <-- Reset key
    _lastLoadedVideoUrl = null;     // <-- Reset last loaded URL
    setState(() {});
  }

  @override
  void initState() {
    // default duration 7 seconds (for images). Video will update duration via JS channel.
    controller = AnimationController(vsync: this, duration: const Duration(seconds: 7))
      ..addListener(() {
        if (controller.status == AnimationStatus.completed) {
          if (currentIndex == widget.story!.length - 1) {
            widget.nextPage();
          } else {
            _updateCurrentIndex(currentIndex + 1);
          }
        }
        setState(() {});
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.forward();
    });

    // NOTE: in webview_flutter v4.x we don't set WebView.platform here manually.
    // The platform interface is picked from the webview_flutter_android / wkwebview packages.

    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the story list changes, reset everything
    if (oldWidget.story != widget.story) {
      currentIndex = 0;
      _webViewController = null;
      _videoWebKey = UniqueKey();
      _lastLoadedVideoUrl = null;
    }
  }

  // Build the top progress bars (keeps same code structure as original)
  Widget buildTopProgressBars() {
    final count = widget.story?.length ?? 0;
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Container(
          height: 4.h,
          color: AppStyle.transparent,
          width: MediaQuery.sizeOf(context).width,
          margin: EdgeInsets.only(left: 20.w, top: 10.h),
          child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: count,
              itemBuilder: (context, index) {
                return AnimatedContainer(
                  margin: EdgeInsets.only(right: 8.w),
                  height: 4.h,
                  width: (MediaQuery.sizeOf(context).width -
                          (36.w + ((count == 1 ? count : (count - 1)) * 8.w))) /
                      count,
                  decoration: BoxDecoration(
                    color: currentIndex >= index ? AppStyle.primary : AppStyle.white,
                    borderRadius: BorderRadius.all(Radius.circular(122.r)),
                  ),
                  duration: const Duration(milliseconds: 500),
                  child: currentIndex == index
                      ? ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(122.r)),
                          child: LinearProgressIndicator(
                            value: controller.value,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppStyle.primary),
                            backgroundColor: AppStyle.white,
                          ),
                        )
                      : currentIndex > index
                          ? ClipRRect(
                              borderRadius: BorderRadius.all(Radius.circular(122.r)),
                              child: const LinearProgressIndicator(
                                value: 1,
                                valueColor: AlwaysStoppedAnimation<Color>(AppStyle.primary),
                                backgroundColor: AppStyle.white,
                              ),
                            )
                          : const SizedBox.shrink(),
                );
              }),
        ),
      ),
    );
  }

  // HTML for video player with JS bridge
  String _videoHtml(String src) {
    // small JS bridge: sends 'duration:xxx', 'time:yyy', 'ended'
    final escaped = src.replaceAll("'", "\\'");
    return '''
      <html>
      <head>
        <meta name="viewport" content="width=device-width,initial-scale=1.0,maximum-scale=1.0,user-scalable=no" />
        <style> html,body{margin:0;padding:0;background:black;height:100%;} video{display:block;width:100%;height:100%;object-fit:cover;} </style>
      </head>
      <body>
        <video id="storyVideo" autoplay playsinline muted webkit-playsinline>
          <source src="$escaped" type="video/mp4">
          Your browser does not support the video tag.
        </video>
        <script>
          var video = document.getElementById('storyVideo');
          video.onended = function() { VideoChannel.postMessage('ended'); };
          video.onloadedmetadata = function() { VideoChannel.postMessage('duration:' + video.duration); };
          video.ontimeupdate = function() { VideoChannel.postMessage('time:' + video.currentTime); };
          // try autoplay on user gesture if needed
          document.addEventListener('visibilitychange', function() {
            if (!document.hidden) { video.play().catch(()=>{}); }
          });
        </script>
      </body>
      </html>
    ''';
  }

  // Create and return a WebViewController configured with JS channel
  WebViewController _createControllerForVideo(String html, void Function(String) onMessage) {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams();
    } else {
      params = AndroidWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('VideoChannel', onMessageReceived: (message) {
        onMessage(message.message);
      })
      ..setBackgroundColor(const Color(0x00000000))
      ..loadHtmlString(html);

    // Android-specific settings (if platform supports)
    if (controller.platform is AndroidWebViewController) {
      try {
        (controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
      } catch (_) {}
    }

    return controller;
  }

  // Handle messages from WebView video JS
  void _handleVideoMessage(String message) {
    try {
      if (message == 'ended') {
        // same behavior as controller completion
        if (currentIndex == widget.story!.length - 1) {
          widget.nextPage();
        } else {
          _updateCurrentIndex(currentIndex + 1);
        }
        return;
      }

      if (message.startsWith('duration:')) {
        final parts = message.split(':');
        if (parts.length >= 2) {
          final d = double.tryParse(parts[1]) ?? 7.0;
          controller.duration = Duration(milliseconds: (d * 1000).round());
          controller.reset();
          controller.forward();
          setState(() {});
        }
        return;
      }

      if (message.startsWith('time:')) {
        final parts = message.split(':');
        if (parts.length >= 2) {
          final t = double.tryParse(parts[1]) ?? 0.0;
          final durMs = controller.duration?.inMilliseconds ?? 7000;
          if (durMs > 0) {
            final v = (t * 1000) / durMs;
            controller.value = v.clamp(0.0, 1.0);
            // controller listener will call setState
          }
        }
        return;
      }
    } catch (e) {
      // ignore parsing errors
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUrl = widget.story?[currentIndex]?.url ?? "";
    final isVideoFile = isVideo(currentUrl);

    // If it's a video and we don't have a controller for this URL (or URL changed), create one
    if (isVideoFile && (_webViewController == null || _lastLoadedVideoUrl != currentUrl)) {
      final html = _videoHtml(currentUrl);
      _webViewController = _createControllerForVideo(html, _handleVideoMessage);
      _videoWebKey = UniqueKey();
      _lastLoadedVideoUrl = currentUrl;
    }

    return Stack(
      children: [
        // Video branch
        if (isVideoFile && _webViewController != null)
          SizedBox(
            width: MediaQuery.sizeOf(context).width,
            height: MediaQuery.sizeOf(context).height,
            child: WebViewWidget(
              key: _videoWebKey,
              controller: _webViewController!,
            ),
          )
        else
          // Image branch (keeps original CachedNetworkImage usage and imageBuilder)
          CachedNetworkImage(
            imageUrl: currentUrl,
            width: MediaQuery.sizeOf(context).width,
            height: MediaQuery.sizeOf(context).height,
            fit: BoxFit.cover,
            imageBuilder: (context, image) {
              return Stack(
                key: imageKey,
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      image: DecorationImage(image: image, fit: BoxFit.fitWidth),
                    ),
                  ),
                  // Top progress bars (same structure as original)
                  buildTopProgressBars(),
                ],
              );
            },
            progressIndicatorBuilder: (context, url, progress) {
              return const Loading();
            },
            errorWidget: (context, url, error) {
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppStyle.textGrey,
                      borderRadius: BorderRadius.all(Radius.circular(16.r)),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FlutterRemix.image_line,
                          color: AppStyle.white,
                          size: 32.r,
                        ),
                        8.verticalSpace,
                        Text(
                          AppHelpers.getTranslation(TrKeys.notFound),
                          style: AppStyle.interNormal(color: AppStyle.white),
                        )
                      ],
                    ),
                  ),
                  // keep top progress bars even on error (matches original)
                  buildTopProgressBars(),
                ],
              );
            },
          ),

        // Gesture areas (prev / next) - same as original but use runJavaScript now
        Row(
          children: [
            GestureDetector(
              onLongPressStart: (s) {
                controller.stop();
                // try to pause video via JS
                if (isVideoFile && _webViewController != null) {
                  try {
                    _webViewController!.runJavaScript('document.getElementById("storyVideo")?.pause();');
                  } catch (_) {}
                }
              },
              onLongPressEnd: (s) {
                controller.forward();
                if (isVideoFile && _webViewController != null) {
                  try {
                    _webViewController!.runJavaScript('document.getElementById("storyVideo")?.play();');
                  } catch (_) {}
                }
              },
              onTap: () {
                if (currentIndex != 0) {
                  _updateCurrentIndex(currentIndex - 1);
                } else {
                  widget.prevPage();
                }
              },
              child: Container(
                width: MediaQuery.sizeOf(context).width / 2,
                height: MediaQuery.sizeOf(context).height,
                color: AppStyle.transparent,
              ),
            ),
            GestureDetector(
              onLongPressStart: (s) {
                controller.stop();
                if (isVideoFile && _webViewController != null) {
                  try {
                    _webViewController!.runJavaScript('document.getElementById("storyVideo")?.pause();');
                  } catch (_) {}
                }
              },
              onLongPressEnd: (s) {
                controller.forward();
                if (isVideoFile && _webViewController != null) {
                  try {
                    _webViewController!.runJavaScript('document.getElementById("storyVideo")?.play();');
                  } catch (_) {}
                }
              },
              onTap: () {
                if (currentIndex != widget.story!.length - 1) {
                  _updateCurrentIndex(currentIndex + 1);
                } else {
                  widget.nextPage();
                }
              },
              child: Container(
                width: MediaQuery.sizeOf(context).width / 2,
                height: MediaQuery.sizeOf(context).height,
                color: AppStyle.transparent,
              ),
            ),
          ],
        ),

        // Top-left row (avatar, title, time) - kept same as original
        Align(
          alignment: Alignment.topLeft,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 16.w),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      context.pushRoute(ShopRoute(shopId: (widget.story?.first?.shopId ?? 0).toString()));
                    },
                    child: Row(
                      children: [
                        6.horizontalSpace,
                        ShopAvatar(
                          shopImage: widget.story?.first?.logoImg ?? "",
                          size: 46.r,
                          padding: 5.r,
                          bgColor: AppStyle.tabBarBorderColor.withOpacity(0.6),
                        ),
                        6.horizontalSpace,
                        Text(
                          widget.story?.first?.title ?? "",
                          style: AppStyle.interNormal(size: 14.sp, color: AppStyle.white),
                        ),
                        6.horizontalSpace,
                        Text(
                          Jiffy.parseFromDateTime(widget.story?[currentIndex]?.createdAt ?? DateTime.now()).fromNow(),
                          style: AppStyle.interNormal(size: 10.sp, color: AppStyle.white),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      context.maybePop();
                    },
                    child: Container(
                      color: AppStyle.transparent,
                      child: Padding(
                        padding: EdgeInsets.only(top: 8.r, bottom: 8.r, left: 8.r, right: 4.r),
                        child: const Icon(
                          Icons.close,
                          color: AppStyle.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Order button (keeps original style)
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(left: 24.w, right: 24.w, bottom: 32.h),
              child: CustomButton(
                title: AppHelpers.getTranslation(TrKeys.order),
                onPressed: () {
                  context.pushRoute(ShopRoute(
                      shopId: (widget.story?[currentIndex]?.shopId ?? 0).toString(),
                      productId: widget.story?[currentIndex]?.productUuid ?? ""));
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
