import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/player_service.dart';

/// 播放器控制中心面板
/// 显示音量控制等功能
class PlayerControlCenter extends StatelessWidget {
  final bool isVisible;
  final Animation<double>? fadeAnimation;
  final VoidCallback onClose;

  const PlayerControlCenter({
    super.key,
    required this.isVisible,
    this.fadeAnimation,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();
    
    if (fadeAnimation != null) {
      return FadeTransition(
        opacity: fadeAnimation!,
        child: _buildPanel(),
      );
    }
    
    return _buildPanel();
  }

  Widget _buildPanel() {
    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black.withOpacity(0.85),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: SafeArea(
            child: Column(
              children: [
                // 顶部标题栏
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '控制中心',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
                        onPressed: onClose,
                      ),
                    ],
                  ),
                ),
                
                // 内容区域 - 使用 AnimatedBuilder 监听音量变化
                Expanded(
                  child: AnimatedBuilder(
                    animation: PlayerService(),
                    builder: (context, child) {
                      final player = PlayerService();
                      final volume = player.volume;
                      
                      return GestureDetector(
                        onTap: () {}, // 阻止点击穿透
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 音量控制卡片
                              Container(
                                width: 320,
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 音量图标
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        volume == 0 
                                            ? Icons.volume_off_rounded 
                                            : volume < 0.5 
                                                ? Icons.volume_down_rounded 
                                                : Icons.volume_up_rounded,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 24),
                                    
                                    // 标题
                                    const Text(
                                      '音量',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 32),
                                    
                                    // 纵向胶囊样式滑块
                                    CapsuleSlider(
                                      value: volume,
                                      onChanged: (value) {
                                        player.setVolume(value);
                                      },
                                    ),
                                    
                                    const SizedBox(height: 16),
                                    
                                    // 音量百分比
                                    Text(
                                      '${(volume * 100).toInt()}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // 提示文字
                              Text(
                                '点击任意位置关闭',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 胶囊样式纵向滑块
class CapsuleSlider extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const CapsuleSlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<CapsuleSlider> createState() => _CapsuleSliderState();
}

class _CapsuleSliderState extends State<CapsuleSlider> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final currentValue = _dragValue ?? widget.value;
    
    return GestureDetector(
      onVerticalDragStart: (details) {
        setState(() {
          _dragValue = currentValue;
        });
      },
      onVerticalDragUpdate: (details) {
        setState(() {
          // 200 是滑块的总高度
          final delta = -details.delta.dy / 200;
          _dragValue = (_dragValue! + delta).clamp(0.0, 1.0);
          widget.onChanged(_dragValue!);
        });
      },
      onVerticalDragEnd: (details) {
        setState(() {
          _dragValue = null;
        });
      },
      onTapDown: (details) {
        // 点击时直接跳转到对应位置
        final RenderBox box = context.findRenderObject() as RenderBox;
        final localPosition = details.localPosition;
        final value = 1.0 - (localPosition.dy / box.size.height);
        widget.onChanged(value.clamp(0.0, 1.0));
      },
      child: Container(
        width: 60,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: Colors.white.withOpacity(0.2),
        ),
        child: Stack(
          children: [
            // 填充部分（已使用的音量）
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 60,
                height: 200 * currentValue,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.deepPurple.withOpacity(0.8),
                      Colors.deepPurple,
                    ],
                  ),
                ),
              ),
            ),
            
            // 滑块手柄（横线）
            Positioned(
              left: 0,
              right: 0,
              bottom: 200 * currentValue - 2,
              child: Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            
            // 顶部小圆点
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
