import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../domain/models/food_model.dart';
import '../../../services/food_service.dart';
import '../../../core/cache/cache_manager.dart';
import '../../../core/constants/api_config.dart';

/// 食物图片预览组件
class FoodImagePreview extends StatefulWidget {
  final FoodRecord foodRecord;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool showFullScreen;
  final bool showLoadingIndicator;

  const FoodImagePreview({
    super.key,
    required this.foodRecord,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.showFullScreen = true,
    this.showLoadingIndicator = true,
  });

  @override
  State<FoodImagePreview> createState() => _FoodImagePreviewState();
}

class _FoodImagePreviewState extends State<FoodImagePreview> {
  final FoodService _foodService = FoodService();
  final CacheManager _cacheManager = CacheManager();
  bool _isLoading = false;
  String? _imageBase64;
  String? _contentType;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadImageData();
  }

  /// 加载图片数据（带缓存）
  Future<void> _loadImageData() async {
    if (widget.foodRecord.imageUrl == null) {
      print('❌ 记录 ${widget.foodRecord.id} 没有图片URL');
      setState(() {
        _errorMessage = '该记录没有图片';
      });
      return;
    }

    final cacheKey = 'food_image_${widget.foodRecord.id}';
    
    // 1. 检查图片字节缓存
    final cachedImageBytes = _cacheManager.getImageCache(cacheKey);
    if (cachedImageBytes != null) {
      print('✅ 从内存缓存获取图片字节数据：记录ID=${widget.foodRecord.id}');
      setState(() {
        _imageBase64 = base64Encode(cachedImageBytes);
        _contentType = 'image/jpeg'; // 默认类型
        _isLoading = false;
      });
      return;
    }

    // 2. 检查文件缓存
    final fileCachedBytes = await _cacheManager.getFileCache(cacheKey);
    if (fileCachedBytes != null) {
      print('✅ 从文件缓存获取图片字节数据：记录ID=${widget.foodRecord.id}');
      _cacheManager.setImageCache(cacheKey, fileCachedBytes);
      setState(() {
        _imageBase64 = base64Encode(fileCachedBytes);
        _contentType = 'image/jpeg'; // 默认类型
        _isLoading = false;
      });
      return;
    }

    print('🔄 开始加载图片数据：记录ID=${widget.foodRecord.id}, URL=${widget.foodRecord.imageUrl}');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _foodService.getFoodImageData(widget.foodRecord.id);
      
      if (response.success && response.data != null) {
        final data = response.data!;
        final imageBase64 = data['image_base64'] as String?;
        final contentType = data['content_type'] as String?;
        
        print('✅ 图片数据加载成功：记录ID=${widget.foodRecord.id}');
        print('📊 图片信息：contentType=$contentType, base64长度=${imageBase64?.length ?? 0}');
        
        setState(() {
          _imageBase64 = imageBase64;
          _contentType = contentType;
          _isLoading = false;
        });
      } else {
        print('❌ 图片数据加载失败：${response.message}');
        setState(() {
          _errorMessage = response.message ?? '获取图片失败';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ 图片数据加载异常：$e');
      setState(() {
        _errorMessage = '加载图片失败: $e';
        _isLoading = false;
      });
    }
  }

  /// 构建图片数据URI
  String? get _imageDataUri {
    if (_imageBase64 == null || _contentType == null) return null;
    return 'data:$_contentType;base64,$_imageBase64';
  }

  /// 显示全屏图片预览
  void _showFullScreenPreview() {
    if (_imageBase64 == null) {
      print('❌ 无法显示全屏预览：图片数据为空');
      return;
    }

    print('🔍 显示全屏预览：图片大小=${_imageBase64!.length} 字符');
    
    try {
      final imageBytes = base64Decode(_imageBase64!);
      print('✅ 图片解码成功：字节大小=${imageBytes.length}');
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              iconTheme: const IconThemeData(color: Colors.white),
              title: const Text(
                '图片预览',
                style: TextStyle(color: Colors.white),
              ),
            ),
            body: PhotoView(
              imageProvider: MemoryImage(imageBytes),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
              backgroundDecoration: const BoxDecoration(
                color: Colors.black,
              ),
              loadingBuilder: (context, event) {
                if (event == null) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  );
                }
                return const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                print('❌ PhotoView 错误: $error');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '图片加载失败',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
    } catch (e) {
      print('❌ 全屏预览错误: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('图片预览失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && widget.showLoadingIndicator) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.grey[600],
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_imageDataUri == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(
            Icons.image_not_supported,
            color: Colors.grey,
            size: 32,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.showFullScreen ? _showFullScreenPreview : null,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            base64Decode(_imageBase64!),
            fit: widget.fit,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.grey,
                    size: 32,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 食物图片网格预览组件
class FoodImageGridPreview extends StatelessWidget {
  final List<FoodRecord> foodRecords;
  final int crossAxisCount;
  final double spacing;
  final double childAspectRatio;
  final bool showFullScreen;

  const FoodImageGridPreview({
    super.key,
    required this.foodRecords,
    this.crossAxisCount = 2,
    this.spacing = 8.0,
    this.childAspectRatio = 1.0,
    this.showFullScreen = true,
  });

  @override
  Widget build(BuildContext context) {
    final recordsWithImages = foodRecords
        .where((record) => record.imageUrl != null)
        .toList();

    if (recordsWithImages.isEmpty) {
      return const Center(
        child: Text(
          '暂无图片记录',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: recordsWithImages.length,
      itemBuilder: (context, index) {
        final record = recordsWithImages[index];
        return FoodImagePreview(
          foodRecord: record,
          showFullScreen: showFullScreen,
        );
      },
    );
  }
} 