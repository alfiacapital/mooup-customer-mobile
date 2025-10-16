import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:upmoo25/infrastructure/models/data/story_data.dart';
import 'package:upmoo25/presentation/theme/app_style.dart';
import 'dart:async';

class VideoStoryWidget extends StatefulWidget {
  final StoryModel story;
  final VoidCallback onVideoEnd;
  final Function(double) onProgressUpdate;
  final bool isActive;

  const VideoStoryWidget({
    super.key,
    required this.story,
    required this.onVideoEnd,
    required this.onProgressUpdate,
    required this.isActive,
  });

  @override
  State<VideoStoryWidget> createState() => _VideoStoryWidgetState();
}

class _VideoStoryWidgetState extends State<VideoStoryWidget> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _hasError = false;
  Timer? _completionTimer;
  DateTime? _videoStartTime;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(VideoStoryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.story.url != widget.story.url) {
      print('Story URL changed, reinitializing video');
      _disposeControllers();
      _initializeVideo();
    }
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        print('Video became active, playing');
        _videoPlayerController?.play();
      } else {
        print('Video became inactive, pausing');
        _videoPlayerController?.pause();
      }
    }
  }

  void _logVideoStatus() {
    if (_videoPlayerController != null) {
      final value = _videoPlayerController!.value;
      print('Video Status - Initialized: ${value.isInitialized}, Playing: ${value.isPlaying}, Duration: ${value.duration}, Position: ${value.position}');
    } else {
      print('Video Status - Controller is null');
    }
  }

  Future<void> _initializeVideo() async {
    try {
      print('Initializing video: ${widget.story.url}');
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.story.url ?? ''),
      );

      await _videoPlayerController!.initialize();
      print('Video initialized successfully. Duration: ${_videoPlayerController!.value.duration}');
      
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true, // Always autoplay for stories
        looping: false,
        showControls: false,
        showOptions: false,
        allowFullScreen: false,
        allowMuting: false,
        allowPlaybackSpeedChanging: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          print('Chewie error: $errorMessage');
          return _buildErrorWidget(errorMessage);
        },
      );

      _videoPlayerController!.addListener(_videoListener);
      
      // Start playing immediately
      await _videoPlayerController!.play();
      print('Video started playing');
      
      // Record start time
      _videoStartTime = DateTime.now();
      
      // Start completion timer after video is playing
      _startCompletionTimer();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Video initialization error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _startCompletionTimer() {
    _completionTimer?.cancel();
    // Only start timer after a delay to ensure video is actually playing
    _completionTimer = Timer(const Duration(milliseconds: 500), () {
      // Check if video is actually playing before starting completion timer
      if (_videoPlayerController != null && 
          _videoPlayerController!.value.isInitialized &&
          _videoPlayerController!.value.isPlaying) {
        print('Video is playing, starting completion timer');
        _completionTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
          _checkVideoCompletion();
        });
      } else {
        print('Video not playing, not starting completion timer');
        _logVideoStatus();
      }
    });
    
    // Add periodic status logging for debugging
    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
        _logVideoStatus();
      } else {
        timer.cancel();
      }
    });
  }

  void _videoListener() {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) {
      return;
    }
    
    final duration = _videoPlayerController!.value.duration;
    final position = _videoPlayerController!.value.position;
    
    // Update progress callback
    if (duration > Duration.zero) {
      final progress = position.inMilliseconds / duration.inMilliseconds;
      widget.onProgressUpdate(progress.clamp(0.0, 1.0));
    }
    
    // Check minimum play time (at least 2 seconds)
    if (_videoStartTime != null) {
      final playTime = DateTime.now().difference(_videoStartTime!);
      if (playTime < const Duration(seconds: 2)) {
        return; // Don't advance if video hasn't played for at least 2 seconds
      }
    }
    
    // Only trigger completion when video is actually near the end
    if (duration > Duration.zero && position >= duration - const Duration(milliseconds: 300)) {
      print('Video completed, duration: $duration, position: $position, playTime=${DateTime.now().difference(_videoStartTime!)}');
      _completionTimer?.cancel();
      widget.onVideoEnd();
    }
  }

  void _checkVideoCompletion() {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) {
      return;
    }
    
    final duration = _videoPlayerController!.value.duration;
    final position = _videoPlayerController!.value.position;
    
    // Update progress callback
    if (duration > Duration.zero) {
      final progress = position.inMilliseconds / duration.inMilliseconds;
      widget.onProgressUpdate(progress.clamp(0.0, 1.0));
    }
    
    // Check minimum play time (at least 2 seconds)
    if (_videoStartTime != null) {
      final playTime = DateTime.now().difference(_videoStartTime!);
      if (playTime < const Duration(seconds: 2)) {
        return; // Don't advance if video hasn't played for at least 2 seconds
      }
    }
    
    // More conservative completion check - only if video has been playing for at least 1 second
    if (duration > Duration.zero && 
        position >= duration - const Duration(milliseconds: 300) &&
        position > const Duration(seconds: 1)) {
      print('Video near completion: duration=$duration, position=$position, playTime=${DateTime.now().difference(_videoStartTime!)}');
      _completionTimer?.cancel();
      widget.onVideoEnd();
    }
  }

  void _disposeControllers() {
    _completionTimer?.cancel();
    _videoPlayerController?.removeListener(_videoListener);
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    _chewieController = null;
    _videoPlayerController = null;
  }

  Widget _buildErrorWidget(String errorMessage) {
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
            Icons.video_library_outlined,
            color: AppStyle.white,
            size: 32.r,
          ),
          8.verticalSpace,
          Text(
            'Video not available',
            style: AppStyle.interNormal(color: AppStyle.white),
          ),
          4.verticalSpace,
          Text(
            errorMessage,
            style: AppStyle.interNormal(
              color: AppStyle.white,
              size: 12.sp,
            ),
            textAlign: TextAlign.center,
          ),
          8.verticalSpace,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  // Retry loading video
                  _hasError = false;
                  _initializeVideo();
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: AppStyle.primary,
                    borderRadius: BorderRadius.circular(15.r),
                  ),
                  child: Text(
                    'Retry',
                    style: AppStyle.interNormal(
                      color: AppStyle.white,
                      size: 12.sp,
                    ),
                  ),
                ),
              ),
              8.horizontalSpace,
              GestureDetector(
                onTap: () {
                  print('User manually skipped video due to error');
                  widget.onVideoEnd();
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: AppStyle.white,
                    borderRadius: BorderRadius.circular(15.r),
                  ),
                  child: Text(
                    'Skip',
                    style: AppStyle.interNormal(
                      color: AppStyle.textGrey,
                      size: 12.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return GestureDetector(
        onTap: widget.onVideoEnd,
        child: _buildErrorWidget('Failed to load video'),
      );
    }

    if (!_isInitialized || _chewieController == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: AppStyle.textGrey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppStyle.white,
            ),
            8.verticalSpace,
            Text(
              'Loading video...',
              style: AppStyle.interNormal(
                color: AppStyle.white,
                size: 14.sp,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        // Allow user to manually advance video story by tapping
        print('User tapped video, checking if ready to advance');
        if (_videoPlayerController != null && 
            _videoPlayerController!.value.isInitialized &&
            _videoStartTime != null) {
          final playTime = DateTime.now().difference(_videoStartTime!);
          if (playTime >= const Duration(seconds: 1)) {
            print('Manual advance after ${playTime.inMilliseconds}ms of playback');
            widget.onVideoEnd();
          } else {
            print('Video not ready to advance yet (${playTime.inMilliseconds}ms played)');
          }
        }
      },
      child: Chewie(controller: _chewieController!),
    );
  }
}
