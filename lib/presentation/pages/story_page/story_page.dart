import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jiffy/jiffy.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:upmoo25/application/home/home_provider.dart';
import 'package:upmoo25/infrastructure/models/data/story_data.dart';
import 'package:upmoo25/infrastructure/services/app_helpers.dart';
import 'package:upmoo25/infrastructure/services/tr_keys.dart';
import 'package:upmoo25/presentation/components/buttons/custom_button.dart';
import 'package:upmoo25/presentation/components/loading.dart';
import 'package:upmoo25/presentation/components/shop_avarat.dart';
import 'package:upmoo25/presentation/components/video_story_widget.dart';
import 'package:upmoo25/presentation/routes/app_router.dart';
import 'package:upmoo25/presentation/theme/app_style.dart';


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
      return PageView.builder(
        controller: pageController,
        itemCount: ref.watch(homeProvider).story?.length ?? 0,
        physics: const PageScrollPhysics(),
        itemBuilder: (context, index) {
          return StoryPage(
            story: ref.watch(homeProvider).story?[index],
            nextPage: () {
              if (index == ref.watch(homeProvider).story!.length - 2) {
                ref
                    .read(homeProvider.notifier)
                    .fetchStorePage(context, widget.controller);
              }
              if (index != ref.watch(homeProvider).story!.length - 1) {
                pageController!.animateToPage(++index,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeIn);
                if (mounted) {
                  setState(() {});
                }
              } else {
                context.maybePop();
              }
            },
            prevPage: () {
              if (index != 0) {
                pageController!.animateToPage(--index,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeIn);
                if (mounted) {
                  setState(() {});
                }
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

  const StoryPage(
      {super.key,
      required this.story,
      required this.nextPage,
      required this.prevPage});

  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> with TickerProviderStateMixin {
  late AnimationController controller;
  final pageController = PageController(initialPage: 0);
  GlobalKey imageKey = GlobalKey();
  int currentIndex = 0;
  double videoProgress = 0.0;
  bool _forceVideoPause = false;

  @override
  void initState() {
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..addListener(() {
        if (controller.status == AnimationStatus.completed) {
          _advanceToNextStory();
        }
        if (mounted) {
          setState(() {});
        }
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startStoryTimer();
    });
    super.initState();
  }

  void _startStoryTimer() {
    final currentStory = widget.story?[currentIndex];
    if (currentStory?.fileType == 'video') {
      // For videos, don't start the timer - let video control timing
      print('Video story detected, not starting timer');
      return;
    }
    print('Image story detected, starting timer');
    controller.forward();
  }

  void _advanceToNextStory() {
    final currentStory = widget.story?[currentIndex];
    if (currentStory?.fileType == 'video') {
      // For videos, don't auto-advance - let video control timing
      print('Video story - not auto-advancing');
      return;
    }
    
    if (currentIndex == widget.story!.length - 1) {
      widget.nextPage();
    } else {
      currentIndex++;
      controller.reset();
      _startStoryTimer();
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _resetAndStartTimer() {
    if (!mounted) return;
    
    final currentStory = widget.story?[currentIndex];
    if (currentStory?.fileType == 'video') {
      // For videos, reset timer but don't start it
      print('Video story - resetting timer but not starting');
      setState(() {
        videoProgress = 0.0; // Reset video progress
        _forceVideoPause = false; // Reset force pause flag
      });
      controller.reset();
      return;
    }
    
    print('Image story - resetting and starting timer');
    setState(() {
      videoProgress = 0.0; // Reset video progress
      _forceVideoPause = false; // Reset force pause flag
    });
    controller.reset();
    _startStoryTimer();
  }

  void _onStoryChanged() {
    if (!mounted) return;
    
    // Reset timer when story changes
    _resetAndStartTimer();
    
    // Reset force pause flag when story changes
    if (mounted) {
      setState(() {
        _forceVideoPause = false;
      });
    }
  }

  bool _canGoToNextStory() {
    return currentIndex < widget.story!.length - 1;
  }

  bool _canGoToPreviousStory() {
    return currentIndex > 0;
  }

  bool _isFromSameShop(int index) {
    if (index < 0 || index >= widget.story!.length) return false;
    final currentStory = widget.story![currentIndex];
    final targetStory = widget.story![index];
    return currentStory?.shopId == targetStory?.shopId;
  }

  List<int> _getShopBoundaries() {
    List<int> boundaries = [];
    if (widget.story == null || widget.story!.isEmpty) return boundaries;
    
    int? currentShopId;
    for (int i = 0; i < widget.story!.length; i++) {
      final story = widget.story![i];
      if (story?.shopId != currentShopId) {
        if (currentShopId != null) {
          boundaries.add(i - 1);
        }
        currentShopId = story?.shopId;
      }
    }
    if (widget.story!.isNotEmpty) {
      boundaries.add(widget.story!.length - 1);
    }
    return boundaries;
  }



  void _skipToNextStory() {
    if (currentIndex < widget.story!.length - 1) {
      final currentStory = widget.story![currentIndex];
      final nextStory = widget.story![currentIndex + 1];
      final isShopChange = currentStory?.shopId != nextStory?.shopId;
      
      currentIndex++;
      _resetAndStartTimer();
      
      // Show shop transition indicator if switching shops
      if (isShopChange) {
        _showShopTransitionIndicator(nextStory?.title ?? "");
      }
      
      if (mounted) {
        setState(() {});
      }
    } else {
      widget.nextPage();
    }
  }

  void _goToPreviousStory() {
    if (currentIndex > 0) {
      final currentStory = widget.story![currentIndex];
      final prevStory = widget.story![currentIndex - 1];
      final isShopChange = currentStory?.shopId != prevStory?.shopId;
      
      currentIndex--;
      _resetAndStartTimer();
      
      // Show shop transition indicator if switching shops
      if (isShopChange) {
        _showShopTransitionIndicator(prevStory?.title ?? "");
      }
      
      if (mounted) {
        setState(() {});
      }
    } else {
      widget.prevPage();
    }
  }

  void _showShopTransitionIndicator(String shopName) {
    // Show a brief indicator when switching between shops
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Now viewing: $shopName'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppStyle.primary,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16.w),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.r),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Stop all playback and clean up resources
    _stopStoryPlayback();
    controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Handle any dependency changes
  }

  @override
  void didUpdateWidget(StoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if the story list changed
    if (oldWidget.story != widget.story) {
      _onStoryChanged();
    }
  }







  void _onVideoProgressUpdate(double progress) {
    if (!mounted) return;
    setState(() {
      videoProgress = progress;
    });
  }

  void _onVideoStoryCompleted() {
    if (!mounted) return;
    
    print('Video story completed, advancing to next story');
    setState(() {
      videoProgress = 0.0; // Reset video progress
    });
    if (currentIndex == widget.story!.length - 1) {
      // Last story, go to next page
      widget.nextPage();
    } else {
      // Go to next story
      currentIndex++;
      _resetAndStartTimer();
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if stories are available
    if (widget.story == null || widget.story!.isEmpty) {
      return Scaffold(
        backgroundColor: AppStyle.textGrey,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_library,
                color: AppStyle.white,
                size: 64.r,
              ),
              16.verticalSpace,
              Text(
                'No stories available',
                style: AppStyle.interNormal(
                  color: AppStyle.white,
                  size: 18.sp,
                ),
              ),
              8.verticalSpace,
              Text(
                'Tap to go back',
                style: AppStyle.interNormal(
                  color: AppStyle.white,
                  size: 14.sp,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Content based on story type (image or video)
        _buildStoryContent(),
        // Progress bars at the top
        _buildProgressBars(),
        // Navigation controls (left/right taps)
        _buildNavigationControls(),
        // Header with shop info and close button
        _buildHeader(),
        // Order button at bottom
        _buildOrderButton(),
      ],
    );
  }

  Widget _buildStoryContent() {
    final currentStory = widget.story?[currentIndex];
    if (currentStory == null) return const SizedBox.shrink();

    // Validate story content
    if (!_isValidStory(currentStory)) {
      return _buildInvalidStoryWidget();
    }

    // Check if it's a video story
    if (currentStory.fileType == 'video') {
      print('Building video story: ${currentStory.url}');
      return VideoStoryWidget(
        story: currentStory,
        onVideoEnd: () {
          print('Video ended, advancing to next story');
          _onVideoStoryCompleted();
        },
        onProgressUpdate: _onVideoProgressUpdate,
        isActive: !_forceVideoPause, // Pause video if force pause is set
      );
    }

    print('Building image story: ${currentStory.url}');
    // Image story - use existing CachedNetworkImage logic
    return CachedNetworkImage(
      imageUrl: currentStory.url ?? "",
      width: MediaQuery.sizeOf(context).width,
      height: MediaQuery.sizeOf(context).height,
      fit: BoxFit.cover,
      imageBuilder: (context, image) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(image: image, fit: BoxFit.fitWidth),
          ),
        );
      },
      progressIndicatorBuilder: (context, url, progress) {
        return const Loading();
      },
      errorWidget: (context, url, error) {
        return _buildErrorWidget();
      },
    );
  }

  bool _isValidStory(StoryModel story) {
    return story.url != null && story.url!.isNotEmpty;
  }

  Widget _buildInvalidStoryWidget() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppStyle.textGrey,
        borderRadius: BorderRadius.all(
          Radius.circular(16.r),
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            color: AppStyle.white,
            size: 32.r,
          ),
          8.verticalSpace,
          Text(
            'Invalid story content',
            style: AppStyle.interNormal(color: AppStyle.white),
          ),
          8.verticalSpace,
          GestureDetector(
            onTap: () {
              // Skip to next story
              _skipToNextStory();
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppStyle.primary,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                'Skip',
                style: AppStyle.interNormal(
                  color: AppStyle.white,
                  size: 14.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppStyle.textGrey,
        borderRadius: BorderRadius.all(
          Radius.circular(16.r),
        ),
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
    );
  }

  Widget _buildProgressBars() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          height: 4.h,
          color: AppStyle.transparent,
          width: MediaQuery.sizeOf(context).width,
          margin: EdgeInsets.only(left: 20.w, top: 10.h),
          child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.story?.length ?? 0,
              itemBuilder: (context, index) {
                final story = widget.story?[index];
                final isVideo = story?.fileType == 'video';
                final isCurrentStory = currentIndex == index;
                final isCompleted = currentIndex > index;
                final isFromSameShop = _isFromSameShop(index);
                
                return AnimatedContainer(
                  margin: EdgeInsets.only(right: 8.w),
                  height: 4.h,
                  width: (MediaQuery.sizeOf(context).width -
                          (36.w +
                              ((widget.story!.length == 1
                                      ? widget.story!.length
                                      : (widget.story!.length -
                                          1)) *
                                  8.w))) /
                      widget.story!.length,
                  decoration: BoxDecoration(
                    color: currentIndex >= index
                        ? (isFromSameShop ? AppStyle.primary : AppStyle.primary.withOpacity(0.7))
                        : AppStyle.white,
                    borderRadius:
                        BorderRadius.all(Radius.circular(122.r)),
                    border: !isFromSameShop && index > 0
                        ? Border(
                            left: BorderSide(
                              color: AppStyle.white,
                              width: 2.w,
                            ),
                          )
                        : null,
                  ),
                  duration: const Duration(milliseconds: 500),
                  child: isCurrentStory
                      ? ClipRRect(
                          borderRadius: BorderRadius.all(
                              Radius.circular(122.r)),
                          child: LinearProgressIndicator(
                            value: isVideo ? videoProgress : controller.value,
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(
                                    AppStyle.primary),
                            backgroundColor: AppStyle.white,
                          ),
                        )
                      : isCompleted
                          ? ClipRRect(
                              borderRadius: BorderRadius.all(
                                  Radius.circular(122.r)),
                              child: const LinearProgressIndicator(
                                value: 1,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                        AppStyle.primary),
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

  Widget _buildNavigationControls() {
    return Positioned.fill(
      child: Row(
        children: [
          GestureDetector(
            onLongPressStart: (s) {
              if (widget.story?[currentIndex]?.fileType != 'video') {
                controller.stop();
              }
            },
            onLongPressEnd: (s) {
              if (widget.story?[currentIndex]?.fileType != 'video') {
                controller.forward();
              }
            },
            onTap: () {
              _goToPreviousStory();
            },
            child: Container(
              width: MediaQuery.sizeOf(context).width / 2,
              height: MediaQuery.sizeOf(context).height,
              color: AppStyle.transparent,
            ),
          ),
          GestureDetector(
            onLongPressStart: (s) {
              if (widget.story?[currentIndex]?.fileType != 'video') {
                controller.stop();
              }
            },
            onLongPressEnd: (s) {
              if (widget.story?[currentIndex]?.fileType != 'video') {
                controller.forward();
              }
            },
            onTap: () {
              _skipToNextStory();
            },
            child: Container(
              width: MediaQuery.sizeOf(context).width / 2,
              height: MediaQuery.sizeOf(context).height,
              color: AppStyle.transparent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final currentStory = widget.story?[currentIndex];
    final shopTitle = currentStory?.title ?? widget.story?.first?.title ?? "";
    final shopLogo = currentStory?.logoImg ?? widget.story?.first?.logoImg ?? "";
    final shopId = currentStory?.shopId ?? widget.story?.first?.shopId ?? 0;
    
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 16.w),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    // Stop story playback before navigation
                    _stopStoryPlayback();
                    
                    // Get the shop info before closing
                    final shopIdString = shopId.toString();
                    
                    // Navigate directly without popping first
                    // This prevents the disposal error
                    context.pushRoute(ShopRoute(
                        shopId: shopIdString)).then((_) {
                      // Only pop the story page after returning from shop
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    });
                  },
                  child: Row(
                    children: [
                      6.horizontalSpace,
                      ShopAvatar(
                        shopImage: shopLogo,
                        size: 46.r,
                        padding: 5.r,
                        bgColor: AppStyle.tabBarBorderColor.withOpacity(0.6),
                      ),
                      6.horizontalSpace,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              shopTitle,
                              style: AppStyle.interNormal(
                                  size: 14.sp, color: AppStyle.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.story != null && widget.story!.length > 1)
                              Text(
                                '${currentIndex + 1}/${widget.story!.length}',
                                style: AppStyle.interNormal(
                                    size: 10.sp, color: AppStyle.white.withOpacity(0.8)),
                              ),
                          ],
                        ),
                      ),
                      6.horizontalSpace,
                      Text(
                        Jiffy.parseFromDateTime(currentStory?.createdAt ?? DateTime.now()).fromNow(),
                        style: AppStyle.interNormal(
                            size: 10.sp, color: AppStyle.white),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  context.maybePop();
                },
                child: Container(
                  color: AppStyle.transparent,
                  child: Padding(
                    padding: EdgeInsets.only(
                        top: 8.r, bottom: 8.r, left: 8.r, right: 4.r),
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
    );
  }

  Widget _buildOrderButton() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(left: 24.w,right: 24.w,bottom: 32.h),
          child: CustomButton(
            title: AppHelpers.getTranslation(TrKeys.order),
            onPressed: () {
              // Stop all story playback before navigation
              _stopStoryPlayback();
              
              // Get the shop and product info before closing
              final shopId = (widget.story?[currentIndex]?.shopId ?? 0).toString();
              final productId = widget.story?[currentIndex]?.productUuid ?? "";
              
              // Navigate directly without popping first
              // This prevents the disposal error
              context.pushRoute(ShopRoute(
                  shopId: shopId,
                  productId: productId)).then((_) {
                // Only pop the story page after returning from shop
                if (mounted) {
                  Navigator.of(context).pop();
                }
              });
            },
          ),
        ),
      ),
    );
  }

  // Stop all story playback (video, audio, timers)
  void _stopStoryPlayback() {
    // Check if widget is still mounted before calling setState
    if (!mounted) return;
    
    // Stop the story timer
    controller.stop();
    
    // Reset video progress
    setState(() {
      videoProgress = 0.0;
    });
    
    // Pause video if it's currently playing
    _pauseCurrentVideo();
    
    // Cancel any ongoing operations
    // This ensures all story-related activities are stopped
    
    print('Story playback stopped - navigating to shop');
  }

  // Pause the current video story if it's playing
  void _pauseCurrentVideo() {
    // Check if widget is still mounted before calling setState
    if (!mounted) return;
    
    final currentStory = widget.story?[currentIndex];
    if (currentStory?.fileType == 'video') {
      // For video stories, we need to pause the video immediately
      // The VideoStoryWidget will be disposed when the story page is closed
      // but we can add a flag to pause it immediately
      setState(() {
        // Force stop any video playback by setting a flag
        // This will be used by the VideoStoryWidget to pause immediately
        _forceVideoPause = true;
      });
      
      print('Video story paused');
    }
  }
}
