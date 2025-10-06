import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/player_background_service.dart';
import '../../services/player_service.dart';

/// 播放器背景组件
/// 根据设置显示不同类型的背景（自适应、纯色、图片）
class PlayerBackground extends StatelessWidget {
  const PlayerBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        PlayerBackgroundService(),
        PlayerService(), // 也监听播放器状态变化，用于更新专辑封面
      ]),
      builder: (context, child) {
        return _buildBackground();
      },
    );
  }

  /// 构建背景（根据设置选择背景类型）
  Widget _buildBackground() {
    final backgroundService = PlayerBackgroundService();
    final greyColor = Colors.grey[900] ?? const Color(0xFF212121);
    
    switch (backgroundService.backgroundType) {
      case PlayerBackgroundType.adaptive:
        // 自适应背景 - 检查是否启用封面渐变效果
        if (backgroundService.enableGradient) {
          return _buildCoverGradientBackground(greyColor);
        } else {
          return _buildColorGradientBackground(greyColor);
        }
        
      case PlayerBackgroundType.solidColor:
        // 纯色背景
        return _buildSolidColorBackground(backgroundService, greyColor);
        
      case PlayerBackgroundType.image:
        // 图片背景
        return _buildImageBackground(backgroundService, greyColor);
    }
  }

  /// 构建封面渐变背景（新样式）
  Widget _buildCoverGradientBackground(Color greyColor) {
    final song = PlayerService().currentSong;
    final track = PlayerService().currentTrack;
    final imageUrl = song?.pic ?? track?.picUrl ?? '';
    
    return ValueListenableBuilder<Color?>(
      valueListenable: PlayerService().themeColorNotifier,
      builder: (context, themeColor, child) {
        final color = themeColor ?? Colors.deepPurple;
        
        return RepaintBoundary(
          child: Stack(
            children: [
              // 底层纯主题色背景
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  color: color,
                ),
              ),
              
              // 专辑封面层 - 等比例放大至占满高度，位于左侧
              if (imageUrl.isNotEmpty)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: AspectRatio(
                    aspectRatio: 1.0, // 保持正方形比例
                    child: Stack(
                      children: [
                        // 封面图片
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: greyColor,
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: greyColor,
                          ),
                        ),
                        // 封面右侧渐变遮罩 - 让封面边缘自然融入背景
                        Positioned.fill(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.transparent,  // 左侧和中间保持透明，显示封面
                                  Colors.transparent,
                                  color.withOpacity(0.3),  // 右侧开始融合主题色
                                  color.withOpacity(0.7),  // 最右侧更多主题色
                                ],
                                stops: const [0.0, 0.6, 0.85, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // 渐变遮罩层 - 从封面到主题色的丝滑渐变
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.transparent,        // 左侧完全透明，显示封面原貌
                        color.withOpacity(0.5),    // 左中部开始融合主题色
                        color.withOpacity(0.85),   // 中部主题色更明显
                        color,                      // 右侧完全不透明的主题色
                      ],
                      stops: const [0.0, 0.25, 0.5, 0.7],  // 更自然的渐变分布
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建颜色渐变背景（原有样式）
  Widget _buildColorGradientBackground(Color greyColor) {
    return ValueListenableBuilder<Color?>(
      valueListenable: PlayerService().themeColorNotifier,
      builder: (context, themeColor, child) {
        final color = themeColor ?? Colors.deepPurple;
        print('🎨 [PlayerBackground] 构建背景，主题色: $color');
        
        return RepaintBoundary(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500), // 主题色变化时平滑过渡
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color,        // 主题色（不透明）
                  greyColor,    // 灰色（不透明）
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建纯色背景
  Widget _buildSolidColorBackground(PlayerBackgroundService backgroundService, Color greyColor) {
    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              backgroundService.solidColor,
              greyColor,
            ],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }

  /// 构建图片背景
  Widget _buildImageBackground(PlayerBackgroundService backgroundService, Color greyColor) {
    if (backgroundService.imagePath != null) {
      final imageFile = File(backgroundService.imagePath!);
      if (imageFile.existsSync()) {
        return Stack(
          children: [
            // 图片层
            Positioned.fill(
              child: Image.file(
                imageFile,
                fit: BoxFit.cover, // 保持原比例裁剪
              ),
            ),
            // 模糊层
            if (backgroundService.blurAmount > 0)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: backgroundService.blurAmount,
                    sigmaY: backgroundService.blurAmount,
                  ),
                  child: Container(
                    color: Colors.black.withOpacity(0.3), // 添加半透明遮罩
                  ),
                ),
              )
            else
              // 无模糊时也添加浅色遮罩以确保文字可读
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.2),
                ),
              ),
          ],
        );
      }
    }
    
    // 如果没有设置图片，使用默认背景
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              greyColor,
              Colors.black,
            ],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}
