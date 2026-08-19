import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:cached_network_image/cached_network_image.dart';
import '../services/listening_stats_service.dart';
import '../services/player_service.dart';
import '../services/auth_service.dart';
import '../utils/theme_manager.dart';
import '../models/track.dart';

/// 听歌日历页面
class ListeningCalendarPage extends StatefulWidget {
  const ListeningCalendarPage({super.key});

  @override
  State<ListeningCalendarPage> createState() => _ListeningCalendarPageState();
}

class _ListeningCalendarPageState extends State<ListeningCalendarPage> {
  final ListeningStatsService _statsService = ListeningStatsService();

  late int _currentYear;
  late int _currentMonth;
  CalendarHeatmapData? _heatmapData;
  DayDetailData? _dayDetail;
  DateTime? _selectedDate;
  bool _isLoading = true;
  bool _isLoadingDay = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentYear = now.year;
    _currentMonth = now.month;
    _loadCalendarData();
  }

  Future<void> _loadCalendarData() async {
    setState(() => _isLoading = true);
    final data = await _statsService.fetchCalendarHeatmap(_currentYear, _currentMonth);
    if (mounted) {
      setState(() {
        _heatmapData = data;
        _isLoading = false;
        _selectedDate = null;
        _dayDetail = null;
      });
    }
  }

  Future<void> _loadDayDetail(DateTime date) async {
    setState(() {
      _selectedDate = date;
      _isLoadingDay = true;
    });
    final detail = await _statsService.fetchDayDetail(date);
    if (mounted) {
      setState(() {
        _dayDetail = detail;
        _isLoadingDay = false;
      });
    }
  }

  void _previousMonth() {
    setState(() {
      _currentMonth--;
      if (_currentMonth < 1) {
        _currentMonth = 12;
        _currentYear--;
      }
    });
    _loadCalendarData();
  }

  void _nextMonth() {
    final now = DateTime.now();
    // 不允许翻到未来月份
    if (_currentYear == now.year && _currentMonth >= now.month) return;
    setState(() {
      _currentMonth++;
      if (_currentMonth > 12) {
        _currentMonth = 1;
        _currentYear++;
      }
    });
    _loadCalendarData();
  }

  bool get _canGoNext {
    final now = DateTime.now();
    return !(_currentYear == now.year && _currentMonth >= now.month);
  }

  String get _monthTitle {
    return '$_currentYear年$_currentMonth月';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCupertino = ThemeManager().isCupertinoFramework;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isExpressive = !ThemeManager().isFluentFramework &&
        !ThemeManager().isCupertinoFramework &&
        (Platform.isAndroid || Platform.isIOS);

    if (isCupertino) {
      return _buildCupertinoPage(context, isDark);
    }
    
    if (ThemeManager().isFluentFramework) {
      return _buildFluentPage(context, isDark);
    }

    return Scaffold(
      backgroundColor: isExpressive ? colorScheme.surfaceContainerLow : colorScheme.surface,
      appBar: AppBar(
        title: const Text('听歌日历'),
        backgroundColor: isExpressive ? colorScheme.surfaceContainerLow : colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: _buildBody(context, colorScheme, isDark, isExpressive),
    );
  }

  Widget _buildCupertinoPage(BuildContext context, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      type: MaterialType.transparency,
      child: CupertinoPageScaffold(
        backgroundColor: isDark ? const Color(0xFF000000) : CupertinoColors.systemGroupedBackground,
        navigationBar: CupertinoNavigationBar(
          middle: const Text('听歌日历'),
          backgroundColor: (isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white).withOpacity(0.9),
          border: null,
        ),
        child: SafeArea(
          child: _buildBody(context, colorScheme, isDark, false),
        ),
      ),
    );
  }

  Widget _buildFluentPage(BuildContext context, bool isDark) {
    // Fluent 环境下手动构造主题
    final themeData = ThemeManager().buildThemeData(isDark ? Brightness.dark : Brightness.light);
    final colorScheme = themeData.colorScheme;
    
    return fluent.ScaffoldPage(
      padding: EdgeInsets.zero,
      header: fluent.PageHeader(
        leading: Padding(
          padding: const EdgeInsets.only(right: 8.0, left: 16.0),
          child: fluent.IconButton(
            icon: const Icon(fluent.FluentIcons.back, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: const Text('听歌日历', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Microsoft YaHei')),
      ),
      content: Theme(
        data: themeData,
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            child: _buildBody(context, colorScheme, isDark, false),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ColorScheme colorScheme, bool isDark, bool isExpressive) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 总计统计卡片
        if (_heatmapData != null)
          _buildSummaryCard(colorScheme, isDark, isExpressive),
        const SizedBox(height: 16),
        // 月份切换 + 日历网格
        _buildCalendarCard(colorScheme, isDark, isExpressive),
        const SizedBox(height: 16),
        // 选中日期的播放详情
        if (_selectedDate != null)
          _buildDayDetailSection(colorScheme, isDark, isExpressive),
        // 底部留白
        SizedBox(height: MediaQuery.of(context).padding.bottom + 80),
      ],
    );
  }

  /// 总计统计卡片
  Widget _buildSummaryCard(ColorScheme colorScheme, bool isDark, bool isExpressive) {
    final data = _heatmapData!;
    final monthPlayCount = data.heatmap.values.fold<int>(0, (sum, c) => sum + c);
    final monthActiveDays = data.heatmap.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withOpacity(0.7),
            colorScheme.tertiaryContainer.withOpacity(0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(isExpressive ? 24 : 16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('本月播放', monthPlayCount.toString(), colorScheme),
          Container(width: 1, height: 40, color: colorScheme.outline.withOpacity(0.2)),
          _buildSummaryItem('活跃天数', '$monthActiveDays 天', colorScheme),
          Container(width: 1, height: 40, color: colorScheme.outline.withOpacity(0.2)),
          _buildSummaryItem('累计天数', '${data.totalDays} 天', colorScheme),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, ColorScheme colorScheme) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: colorScheme.primary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// 日历卡片
  Widget _buildCalendarCard(ColorScheme colorScheme, bool isDark, bool isExpressive) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(isExpressive ? 24 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 月份切换栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left_rounded, color: colorScheme.primary),
                  onPressed: _previousMonth,
                ),
                Text(
                  _monthTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: _canGoNext ? colorScheme.primary : colorScheme.outline.withOpacity(0.3),
                  ),
                  onPressed: _canGoNext ? _nextMonth : null,
                ),
              ],
            ),
          ),
          // 星期标题行
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['一', '二', '三', '四', '五', '六', '日'].map((day) {
                return SizedBox(
                  width: 40,
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // 日历网格
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            _buildCalendarGrid(colorScheme, isDark),
          const SizedBox(height: 12),
          // 图例
          _buildLegend(colorScheme),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// 日历网格
  Widget _buildCalendarGrid(ColorScheme colorScheme, bool isDark) {
    final firstDayOfMonth = DateTime(_currentYear, _currentMonth, 1);
    final daysInMonth = DateTime(_currentYear, _currentMonth + 1, 0).day;
    // 星期一为0，星期日为6
    final startWeekday = (firstDayOfMonth.weekday - 1) % 7;

    final today = DateTime.now();
    final heatmap = _heatmapData?.heatmap ?? {};

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1,
        ),
        itemCount: startWeekday + daysInMonth,
        itemBuilder: (context, index) {
          if (index < startWeekday) {
            return const SizedBox(); // 空白占位
          }

          final day = index - startWeekday + 1;
          final date = DateTime(_currentYear, _currentMonth, day);
          final dateStr = '${_currentYear}-${_currentMonth.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
          final count = heatmap[dateStr] ?? 0;
          final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
          final isSelected = _selectedDate?.year == date.year &&
              _selectedDate?.month == date.month &&
              _selectedDate?.day == date.day;
          final isFuture = date.isAfter(today);

          return GestureDetector(
            onTap: isFuture || count == 0 ? null : () => _loadDayDetail(date),
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary
                    : count > 0
                        ? _getHeatColor(count, colorScheme, isDark)
                        : (isDark ? Colors.white.withOpacity(0.04) : Colors.grey.withOpacity(0.06)),
                borderRadius: BorderRadius.circular(10),
                border: isToday
                    ? Border.all(color: colorScheme.primary, width: 2)
                    : null,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      day.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isToday || isSelected ? FontWeight.w900 : FontWeight.w500,
                        color: isSelected
                            ? colorScheme.onPrimary
                            : isFuture
                                ? colorScheme.onSurface.withOpacity(0.2)
                                : colorScheme.onSurface,
                      ),
                    ),
                    if (count > 0 && !isSelected)
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary.withOpacity(0.8),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 热力颜色计算
  Color _getHeatColor(int count, ColorScheme colorScheme, bool isDark) {
    if (count <= 0) return Colors.transparent;
    // 根据播放次数映射不同深度
    final double intensity;
    if (count <= 3) {
      intensity = 0.15;
    } else if (count <= 10) {
      intensity = 0.3;
    } else if (count <= 20) {
      intensity = 0.5;
    } else if (count <= 40) {
      intensity = 0.7;
    } else {
      intensity = 0.9;
    }
    return colorScheme.primary.withOpacity(intensity);
  }

  /// 图例
  Widget _buildLegend(ColorScheme colorScheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '少',
            style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
          ),
          const SizedBox(width: 4),
          ...[0.15, 0.3, 0.5, 0.7, 0.9].map((opacity) => Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(opacity),
                  borderRadius: BorderRadius.circular(3),
                ),
              )),
          const SizedBox(width: 4),
          Text(
            '多',
            style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  /// 选中日期的播放详情
  Widget _buildDayDetailSection(ColorScheme colorScheme, bool isDark, bool isExpressive) {
    if (_selectedDate == null) return const SizedBox.shrink();

    final dateStr = '${_selectedDate!.month}月${_selectedDate!.day}日';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(Icons.music_note_rounded, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '$dateStr 播放记录',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              if (_dayDetail != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_dayDetail!.count} 首',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // 播放列表
        if (_isLoadingDay)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_dayDetail == null || _dayDetail!.records.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '暂无播放记录',
                style: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
              ),
            ),
          )
        else
          ...(_dayDetail!.records.asMap().entries.map((entry) {
            return _buildTrackItem(entry.value, entry.key, colorScheme, isDark, isExpressive);
          })),
      ],
    );
  }

  /// 单条播放记录
  Widget _buildTrackItem(DayPlayRecord record, int index, ColorScheme colorScheme, bool isDark, bool isExpressive) {
    final time = '${record.playedAt.hour.toString().padLeft(2, '0')}:${record.playedAt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(isExpressive ? 20 : 12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              PlayerService().playTrack(record.toTrack());
            },
            borderRadius: BorderRadius.circular(isExpressive ? 20 : 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // 时间标签
                  Container(
                    width: 48,
                    alignment: Alignment.center,
                    child: Text(
                      time,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary.withOpacity(0.7),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 封面
                  ClipRRect(
                    borderRadius: BorderRadius.circular(isExpressive ? 12 : 8),
                    child: CachedNetworkImage(
                      imageUrl: record.picUrl,
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 46,
                        height: 46,
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(Icons.music_note, size: 20, color: colorScheme.onSurfaceVariant.withOpacity(0.3)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 46,
                        height: 46,
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(Icons.music_note, size: 20, color: colorScheme.onSurfaceVariant.withOpacity(0.3)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 歌曲信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.trackName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${record.artists} · ${record.album}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 来源图标
                  Text(_getSourceIcon(record.source), style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getSourceIcon(String source) {
    switch (source.toLowerCase()) {
      case 'netease': return '🎵';
      case 'qq': return '🎶';
      case 'kugou': return '🎼';
      case 'kuwo': return '🎸';
      case 'apple': return '🍎';
      case 'spotify': return '🟢';
      case 'local': return '📁';
      default: return '🎵';
    }
  }
}
