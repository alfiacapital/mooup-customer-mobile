import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:foodyman/infrastructure/models/data/story_data.dart';
import 'package:foodyman/presentation/theme/app_style.dart';
import 'dart:io'; // Added for File

class StoryThumbnail extends StatefulWidget {
  final StoryModel? story;
  final double? height;
  final double? width;
  final double radius;
  final BoxFit fit;

  const StoryThumbnail({
    super.key,
    required this.story,
    this.height,
    this.width,
    required this.radius,
    this.fit = BoxFit.cover,
  });

  @override
  State<StoryThumbnail> createState() => _StoryThumbnailState();
}

class _StoryThumbnailState extends State<StoryThumbnail> {
  String? _thumbnailPath;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  @override
  void didUpdateWidget(StoryThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.story?.url != widget.story?.url) {
      _generateThumbnail();
    }
  }

  Future<void> _generateThumbnail() async {
    if (widget.story?.url == null) return;
    
    final story = widget.story!;
    
    // If it's an image, no need to generate thumbnail
    if (story.fileType != 'video') {
      setState(() {
        _thumbnailPath = null;
        _isLoading = false;
        _hasError = false;
      });
      return;
    }

    // If it's a video, generate thumbnail
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      print('Generating thumbnail for video: ${story.url}');
      
      // Validate URL format
      final videoUrl = story.url!;
      if (!videoUrl.startsWith('http://') && !videoUrl.startsWith('https://')) {
        throw Exception('Invalid video URL format: $videoUrl');
      }
      
      // Try different thumbnail generation approaches
      String? thumbnailPath;
      
      try {
        // Method 1: Standard thumbnail generation
        thumbnailPath = await VideoThumbnail.thumbnailFile(
          video: videoUrl,
          thumbnailPath: (await getTemporaryDirectory()).path,
          imageFormat: ImageFormat.JPEG,
          quality: 80,
          timeMs: 500, // Take thumbnail at 0.5 seconds for better preview
          maxHeight: 300, // Limit height for better performance
          maxWidth: 300,  // Limit width for better performance
        );
        print('Method 1 successful: $thumbnailPath');
      } catch (e) {
        print('Method 1 failed: $e');
        
        // Method 2: Try with different parameters
        try {
          thumbnailPath = await VideoThumbnail.thumbnailFile(
            video: videoUrl,
            thumbnailPath: (await getTemporaryDirectory()).path,
            imageFormat: ImageFormat.JPEG,
            quality: 60,
            timeMs: 1000, // Try at 1 second
            maxHeight: 200,
            maxWidth: 200,
          );
          print('Method 2 successful: $thumbnailPath');
        } catch (e2) {
          print('Method 2 failed: $e2');
          throw Exception('All thumbnail generation methods failed: $e, $e2');
        }
      }

      print('Thumbnail generated successfully: $thumbnailPath');

      // Check if the file actually exists
      final thumbnailFile = File(thumbnailPath!);
      if (await thumbnailFile.exists()) {
        final fileSize = await thumbnailFile.length();
        print('Thumbnail file exists with size: ${fileSize} bytes');
        
        if (fileSize == 0) {
          print('ERROR: Thumbnail file is empty!');
          throw Exception('Generated thumbnail file is empty');
        }
      } else {
        print('ERROR: Thumbnail file does not exist!');
        throw Exception('Generated thumbnail file not found');
      }

      if (mounted) {
        setState(() {
          _thumbnailPath = thumbnailPath;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error generating thumbnail: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.story?.url == null) {
      return _buildPlaceholder();
    }

    final story = widget.story!;
    
    print('Building thumbnail for story: ${story.fileType} - ${story.url}');
    
    // For images, use the original URL
    if (story.fileType != 'video') {
      print('Using original image URL for image story');
      return _buildImageThumbnail(story.url!);
    }

    // For videos, use generated thumbnail or fallback
    print('Video story - thumbnail path: $_thumbnailPath, loading: $_isLoading, error: $_hasError');
    
    if (_isLoading) {
      print('Showing loading placeholder for video');
      return _buildLoadingPlaceholder();
    }

    if (_hasError || _thumbnailPath == null) {
      print('Showing fallback for video (error: $_hasError, path: $_thumbnailPath)');
      return _buildVideoFallback();
    }

    // Check if thumbnail file exists before trying to display it
    final thumbnailFile = File(_thumbnailPath!);
    if (!thumbnailFile.existsSync()) {
      print('ERROR: Thumbnail file not found, showing fallback');
      return _buildVideoFallback();
    }

    print('Using generated thumbnail: $_thumbnailPath');
    return _buildImageThumbnail(_thumbnailPath!);
  }

  Widget _buildImageThumbnail(String imageUrl) {
    final isVideo = widget.story?.fileType == 'video';
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: Stack(
        children: [
          // Check if this is a local file path (generated thumbnail) or network URL
          imageUrl.startsWith('/') || imageUrl.startsWith('file://')
              ? Builder(
                  builder: (context) {
                    print('Loading local thumbnail file: $imageUrl');
                    final file = File(imageUrl);
                    if (!file.existsSync()) {
                      print('ERROR: Local file does not exist: $imageUrl');
                      return _buildErrorPlaceholder();
                    }
                    
                    try {
                      return Image.file(
                        file,
                        height: widget.height,
                        width: widget.width,
                        fit: widget.fit,
                        errorBuilder: (context, error, stackTrace) {
                          print('Error loading local thumbnail: $error');
                          return _buildErrorPlaceholder();
                        },
                      );
                    } catch (e) {
                      print('Exception loading local thumbnail: $e');
                      return _buildErrorPlaceholder();
                    }
                  },
                )
              : CachedNetworkImage(
                  height: widget.height,
                  width: widget.width,
                  imageUrl: imageUrl,
                  fit: widget.fit,
                  progressIndicatorBuilder: (context, url, progress) {
                    return _buildLoadingPlaceholder();
                  },
                  errorWidget: (context, url, error) {
                    return _buildErrorPlaceholder();
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        color: AppStyle.shimmerBase,
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppStyle.primary),
        ),
      ),
    );
  }

  Widget _buildVideoFallback() {
    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        color: AppStyle.shimmerBase,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppStyle.shimmerBase,
            AppStyle.shimmerBase.withOpacity(0.7),
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle video icon
          Icon(
            FlutterRemix.video_line,
            color: AppStyle.shimmerBaseDark.withOpacity(0.3),
            size: 24.r,
          ),
          // Retry button if there was an error
          if (_hasError)
            Positioned(
              top: 8.h,
              left: 8.w,
              child: GestureDetector(
                onTap: _generateThumbnail,
                child: Container(
                  padding: EdgeInsets.all(4.r),
                  decoration: BoxDecoration(
                    color: AppStyle.primary,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    FlutterRemix.refresh_line,
                    color: AppStyle.white,
                    size: 12.r,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        color: AppStyle.shimmerBase,
      ),
      child: Icon(
        FlutterRemix.image_line,
        color: AppStyle.shimmerBaseDark,
        size: 32.r,
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        color: AppStyle.shimmerBase,
      ),
    );
  }
}
