import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent_ui;
import '../../utils/theme_manager.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import '../../services/layout_preference_service.dart';
import '../../services/player_background_service.dart';
import '../../services/window_background_service.dart';
import '../../services/lyric_style_service.dart';
import '../../services/lyric_font_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_color_picker_dialog.dart';
import '../../widgets/fluent_settings_card.dart';
import '../../widgets/cupertino/cupertino_settings_widgets.dart';
import 'player_background_dialog.dart';
import 'window_background_dialog.dart';
import '../../widgets/material/material_settings_widgets.dart';

/// 外观设置详情内容（二级页面内容，嵌入在设置页面中）
class AppearanceSettingsContent extends StatefulWidget {
  final VoidCallback onBack;
  final bool embed;

  const AppearanceSettingsContent({
    super.key,
    required this.onBack,
    this.embed = false,
  });

  /// 构建 Fluent UI 面包屑导航（Windows 11 24H2 风格）
  Widget buildFluentBreadcrumb(BuildContext context) {
    final theme = fluent_ui.FluentTheme.of(context);
    final typography = theme.typography;

    // Windows 11 设置页面的面包屑样式：
    // - 无返回按钮
    // - 父级页面文字颜色较浅，可点击
    // - 当前页面文字颜色正常
    // - 字体大小与 PageHeader 的 title 一致（使用 typography.title）
    return Row(
      children: [
        // 父级：设置（颜色较浅，可点击）
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onBack,
            child: Text(
              '设置',
              style: typography.title?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            fluent_ui.FluentIcons.chevron_right,
            size: 14,
            color: theme.resources.textFillColorSecondary,
          ),
        ),
        // 当前页面：外观（正常颜色）
        Text('外观', style: typography.title),
      ],
    );
  }

  @override
  State<AppearanceSettingsContent> createState() =>
      _AppearanceSettingsContentState();
}

class _AppearanceSettingsContentState extends State<AppearanceSettingsContent> {
  @override
  Widget build(BuildContext context) {
    final isFluentUI = ThemeManager().isDesktopFluentUI;
    final isCupertinoUI =
        (Platform.isIOS || Platform.isAndroid) &&
        ThemeManager().isCupertinoFramework;

    if (isFluentUI) {
      return _buildFluentUI(context);
    }

    if (isCupertinoUI) {
      return _buildCupertinoUI(context);
    }

    return _buildMaterialUI(context);
  }

  /// 构建 Material UI 版本
  Widget _buildMaterialUI(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final content = ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        // 主题模式
        MD3SettingsSection(
          title: '主题',
          children: [
            MD3SwitchTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: '深色模式',
              subtitle: '启用深色主题',
              value: ThemeManager().isDarkMode,
              onChanged: (value) {
                ThemeManager().toggleDarkMode(value);
                setState(() {});
              },
            ),
            MD3SwitchTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: '跟随系统主题色',
              subtitle: _getFollowSystemColorSubtitle(),
              value: ThemeManager().followSystemColor,
              onChanged: (value) async {
                await ThemeManager().setFollowSystemColor(
                  value,
                  context: context,
                );
                setState(() {});
              },
            ),
            MD3SettingsTile(
              leading: const Icon(Icons.color_lens_outlined),
              title: '主题色',
              subtitle: _getCurrentThemeColorName(),
              trailing: ThemeManager().followSystemColor
                  ? Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: Theme.of(context).disabledColor,
                    )
                  : const Icon(Icons.chevron_right),
              onTap: ThemeManager().followSystemColor
                  ? null
                  : () => _showThemeColorPicker(),
              enabled: !ThemeManager().followSystemColor,
            ),
          ],
        ),

        // 移动端专属设置
        if (Platform.isAndroid || Platform.isIOS)
          MD3SettingsSection(
            title: '界面风格',
            children: [
              MD3SettingsTile(
                leading: const Icon(Icons.phone_iphone_outlined),
                title: '界面风格',
                subtitle: _getMobileThemeFrameworkSubtitle(),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showMobileThemeFrameworkDialog(),
              ),
            ],
          ),

        // 播放器设置
        MD3SettingsSection(
          title: '播放器',
          children: [
            MD3SettingsTile(
              leading: const Icon(Icons.style_outlined),
              title: '全屏播放器样式',
              subtitle: LyricStyleService().getStyleDescription(
                LyricStyleService().currentStyle,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showPlayerStyleDialog(),
            ),
            MD3SettingsTile(
              leading: const Icon(Icons.font_download_outlined),
              title: '歌词字体',
              subtitle: LyricFontService().currentFontName,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLyricFontDialog(),
            ),
            MD3SettingsTile(
              leading: const Icon(Icons.wallpaper_outlined),
              title: '播放器背景',
              subtitle:
                  '${PlayerBackgroundService().getBackgroundTypeName()} - ${PlayerBackgroundService().getBackgroundTypeDescription()}',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showPlayerBackgroundDialog(),
            ),
            MD3SettingsTile(
              leading: const Icon(Icons.photo_size_select_actual_outlined),
              title: '窗口背景',
              subtitle: _getWindowBackgroundSubtitle(),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showWindowBackgroundDialog(),
            ),
          ],
        ),

        // 桌面端专属设置
        if (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
          MD3SettingsSection(
            title: '桌面端',
            children: [
              MD3SettingsTile(
                leading: const Icon(Icons.layers_outlined),
                title: '桌面主题样式',
                subtitle: _getThemeFrameworkSubtitle(),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemeFrameworkDialog(),
              ),
              MD3SettingsTile(
                leading: const Icon(Icons.view_quilt_outlined),
                title: '布局模式',
                subtitle: LayoutPreferenceService().getLayoutDescription(),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLayoutModeDialog(),
              ),
              if (Platform.isWindows)
                MD3SettingsTile(
                  leading: const Icon(Icons.blur_on),
                  title: '窗口材质',
                  subtitle: _windowEffectLabel(ThemeManager().windowEffect),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showWindowEffectDialog(),
                ),
            ],
          ),
      ],
    );

    if (widget.embed) {
      return content;
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('外观设置'),
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: content,
    );
  }

  Widget _buildMaterialSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(child: Column(children: children)),
      ],
    );
  }

  /// 构建 Cupertino UI 版本
  Widget _buildCupertinoUI(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? CupertinoColors.black
        : CupertinoColors.systemGroupedBackground;

    final content = CupertinoScrollbar(
      child: ListView(
        children: [
          // 主题设置（Cupertino 模式下只显示深色模式开关，主题色固定为 iOS 蓝色）
          CupertinoSettingsSection(
            header: '主题',
            children: [
              CupertinoSettingsTile(
                icon: CupertinoIcons.moon_fill,
                iconColor: CupertinoColors.systemIndigo,
                title: '深色模式',
                trailing: CupertinoSwitch(
                  value: ThemeManager().isDarkMode,
                  onChanged: (value) {
                    ThemeManager().toggleDarkMode(value);
                    setState(() {});
                  },
                ),
              ),
            ],
          ),

          // 界面风格设置
          CupertinoSettingsSection(
            header: '界面风格',
            children: [
              CupertinoSettingsTile(
                icon: CupertinoIcons.device_phone_portrait,
                iconColor: ThemeManager.iosBlue,
                title: '界面风格',
                subtitle: _getMobileThemeFrameworkSubtitle(),
                showChevron: true,
                onTap: () => _showMobileThemeFrameworkDialog(),
              ),
            ],
          ),

          // 播放器设置
          CupertinoSettingsSection(
            header: '播放器',
            children: [
              CupertinoSettingsTile(
                icon: CupertinoIcons.music_note,
                iconColor: CupertinoColors.systemPink,
                title: '全屏播放器样式',
                subtitle: LyricStyleService().getStyleDescription(
                  LyricStyleService().currentStyle,
                ),
                showChevron: true,
                onTap: () => _showCupertinoPlayerStyleDialog(),
              ),
              CupertinoSettingsTile(
                icon: CupertinoIcons.textformat,
                iconColor: CupertinoColors.systemOrange,
                title: '歌词字体',
                subtitle: LyricFontService().currentFontName,
                showChevron: true,
                onTap: () => _showCupertinoLyricFontDialog(),
              ),
              CupertinoSettingsTile(
                icon: CupertinoIcons.photo_fill,
                iconColor: CupertinoColors.systemTeal,
                title: '播放器背景',
                subtitle: PlayerBackgroundService().getBackgroundTypeName(),
                showChevron: true,
                onTap: () => _showPlayerBackgroundDialog(),
              ),
            ],
          ),
        ],
      ),
    );

    if (widget.embed) {
      return Container(color: backgroundColor, child: content);
    }

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: backgroundColor.withOpacity(0.8),
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: widget.onBack,
          child: const Icon(CupertinoIcons.back),
        ),
        middle: const Text('外观'),
      ),
      child: SafeArea(child: content),
    );
  }

  void _showCupertinoThemeColorPicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        height: 400,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoTheme.of(context).barBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                '选择主题色',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    childAspectRatio: 1,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: ThemeColors.presets.length,
                  itemBuilder: (context, index) {
                    final colorScheme = ThemeColors.presets[index];
                    final isSelected =
                        ThemeManager().seedColor.value ==
                        colorScheme.color.value;

                    return GestureDetector(
                      onTap: () {
                        ThemeManager().setSeedColor(colorScheme.color);
                        Navigator.pop(context);
                        setState(() {});
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: CupertinoColors.white,
                                  width: 3,
                                )
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: colorScheme.color.withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                                CupertinoIcons.checkmark,
                                color: CupertinoColors.white,
                                size: 24,
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
              CupertinoButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showCustomColorPicker();
                },
                child: const Text('自定义颜色'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCupertinoPlayerStyleDialog() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('选择全屏播放器样式'),
        actions: LyricStyle.values
            .where((style) => style != LyricStyle.defaultStyle)
            .map((style) {
              final isSelected = LyricStyleService().currentStyle == style;
              return CupertinoActionSheetAction(
                isDefaultAction: isSelected,
                onPressed: () {
                  LyricStyleService().setStyle(style);
                  Navigator.pop(context);
                  setState(() {});
                },
                child: Text(LyricStyleService().getStyleName(style)),
              );
            })
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
  }

  /// 构建 Fluent UI 版本
  Widget _buildFluentUI(BuildContext context) {
    final children = [
      // 主题设置
      FluentSettingsGroup(
        title: '主题',
        children: [
          // 主题模式
          FluentSettingsTile(
            icon: fluent_ui.FluentIcons.clear_night,
            title: '主题模式',
            subtitle: _themeModeLabel(ThemeManager().themeMode),
            trailing: SizedBox(
              width: 180,
              child: fluent_ui.ComboBox<ThemeMode>(
                placeholder: const Text('选择主题模式'),
                value: ThemeManager().themeMode,
                items: const [
                  fluent_ui.ComboBoxItem<ThemeMode>(
                    value: ThemeMode.light,
                    child: Text('亮色'),
                  ),
                  fluent_ui.ComboBoxItem<ThemeMode>(
                    value: ThemeMode.dark,
                    child: Text('暗色'),
                  ),
                  fluent_ui.ComboBoxItem<ThemeMode>(
                    value: ThemeMode.system,
                    child: Text('跟随系统'),
                  ),
                ],
                onChanged: (mode) {
                  if (mode != null) {
                    ThemeManager().setThemeMode(mode);
                    if (mounted) setState(() {});
                  }
                },
              ),
            ),
          ),
          // 主题色设置（折叠项）
          fluent_ui.Card(
            padding: EdgeInsets.zero,
            child: fluent_ui.Expander(
              initiallyExpanded: false,
              header: Row(
                children: [
                  const Icon(fluent_ui.FluentIcons.color_solid, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('主题色设置')),
                  Text(
                    ThemeManager().followSystemColor ? '跟随系统' : '自定义',
                    style: fluent_ui.FluentTheme.of(context).typography.caption,
                  ),
                ],
              ),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('跟随系统主题色')),
                      fluent_ui.ToggleSwitch(
                        checked: ThemeManager().followSystemColor,
                        onChanged: (value) async {
                          await ThemeManager().setFollowSystemColor(
                            value,
                            context: context,
                          );
                          if (mounted) setState(() {});
                        },
                      ),
                    ],
                  ),
                  if (!ThemeManager().followSystemColor) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(child: Text('自定义主题色')),
                        fluent_ui.Button(
                          onPressed: _showFluentThemeColorDialog,
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: ThemeManager().seedColor,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color:
                                        (fluent_ui.FluentTheme.of(
                                              context,
                                            ).brightness ==
                                            Brightness.light)
                                        ? Colors.black.withOpacity(0.12)
                                        : Colors.white.withOpacity(0.18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('选择颜色'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),

      // 播放器设置
      FluentSettingsGroup(
        title: '播放器',
        children: [
          FluentSettingsTile(
            icon: fluent_ui.FluentIcons.music_note,
            title: '全屏播放器样式',
            subtitle: LyricStyleService().getStyleDescription(
              LyricStyleService().currentStyle,
            ),
            trailing: SizedBox(
              width: 200,
              child: fluent_ui.ComboBox<LyricStyle>(
                value: LyricStyleService().currentStyle,
                items: LyricStyle.values
                    .where((style) => style != LyricStyle.defaultStyle)
                    .map((style) {
                      return fluent_ui.ComboBoxItem<LyricStyle>(
                        value: style,
                        child: Text(LyricStyleService().getStyleName(style)),
                      );
                    })
                    .toList(),
                onChanged: (style) {
                  if (style != null) {
                    LyricStyleService().setStyle(style);
                    if (mounted) setState(() {});
                  }
                },
              ),
            ),
          ),
          FluentSettingsTile(
            icon: fluent_ui.FluentIcons.font_color_a,
            title: '歌词字体',
            subtitle: LyricFontService().currentFontName,
            trailing: const Icon(fluent_ui.FluentIcons.chevron_right, size: 12),
            onTap: () => _showLyricFontDialog(),
          ),
          FluentSettingsTile(
            icon: fluent_ui.FluentIcons.picture_library,
            title: '播放器背景',
            subtitle:
                '${PlayerBackgroundService().getBackgroundTypeName()} - ${PlayerBackgroundService().getBackgroundTypeDescription()}',
            trailing: const Icon(fluent_ui.FluentIcons.chevron_right, size: 12),
            onTap: () => _showPlayerBackgroundDialog(),
          ),
          FluentSettingsTile(
            icon: fluent_ui.FluentIcons.photo_collection,
            title:
                '窗口背景${(AuthService().currentUser?.isSponsor ?? false) ? '' : ' 🎁'}',
            subtitle: _getWindowBackgroundSubtitle(),
            trailing: const Icon(fluent_ui.FluentIcons.chevron_right, size: 12),
            onTap: () => _showWindowBackgroundDialog(),
          ),
        ],
      ),
      const SizedBox(height: 16),

      // 桌面端设置
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
        FluentSettingsGroup(
          title: '桌面端',
          children: [
            FluentSettingsTile(
              icon: fluent_ui.FluentIcons.design,
              title: '桌面主题样式',
              subtitle: _getThemeFrameworkSubtitle(),
              trailing: const Icon(
                fluent_ui.FluentIcons.chevron_right,
                size: 12,
              ),
              onTap: () => _showThemeFrameworkDialog(),
            ),
            // 窗口材质（目前仅 Windows 支持）
            if (Platform.isWindows)
              FluentSettingsTile(
                icon: fluent_ui.FluentIcons.transition_effect,
                title: '窗口材质',
                subtitle: _windowEffectLabel(ThemeManager().windowEffect),
                trailing: SizedBox(
                  width: 200,
                  child: fluent_ui.ComboBox<WindowEffect>(
                    value:
                        ThemeManager().themeMode ==
                            ThemeMode
                                .system // 这里原本逻辑可能有误，应直接取 windowEffect，但先保持原样仅放开平台
                        ? ThemeManager().windowEffect
                        : ThemeManager().windowEffect,
                    items: [
                      const fluent_ui.ComboBoxItem(
                        value: WindowEffect.disabled,
                        child: Text('默认'),
                      ),
                      fluent_ui.ComboBoxItem(
                        value: WindowEffect.mica,
                        enabled: ThemeManager().isMicaSupported,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('云母'),
                            if (!ThemeManager().isMicaSupported) ...[
                              const SizedBox(width: 8),
                              Text(
                                '(需要 Win11)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: fluent_ui.FluentTheme.of(
                                    context,
                                  ).resources.textFillColorDisabled,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const fluent_ui.ComboBoxItem(
                        value: WindowEffect.acrylic,
                        child: Text('亚克力'),
                      ),
                      const fluent_ui.ComboBoxItem(
                        value: WindowEffect.transparent,
                        child: Text('透明'),
                      ),
                    ],
                    onChanged: (effect) async {
                      if (effect != null) {
                        await ThemeManager().setWindowEffect(effect);
                        if (mounted) setState(() {});
                      }
                    },
                  ),
                ),
              ),
            // 布局模式
            FluentSettingsTile(
              icon: fluent_ui.FluentIcons.view_all,
              title: '布局模式',
              subtitle: LayoutPreferenceService().getLayoutDescription(),
              trailing: const Icon(
                fluent_ui.FluentIcons.chevron_right,
                size: 12,
              ),
              onTap: () => _showLayoutModeDialog(),
            ),
          ],
        ),
    ];

    if (widget.embed) {
      return fluent_ui.ListView(
        padding: const EdgeInsets.all(24),
        children: children,
      );
    }

    return fluent_ui.ScaffoldPage.scrollable(
      header: fluent_ui.PageHeader(
        title: widget.buildFluentBreadcrumb(context),
      ),
      padding: const EdgeInsets.all(24),
      children: children,
    );
  }

  // ============ 辅助方法 ============

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return '亮色';
      case ThemeMode.dark:
        return '暗色';
      case ThemeMode.system:
        return '跟随系统';
    }
  }

  String _getCurrentThemeColorName() {
    if (ThemeManager().followSystemColor) {
      return '${ThemeManager().getThemeColorSource()} (当前跟随系统)';
    }
    final currentIndex = ThemeManager().getCurrentColorIndex();
    if (currentIndex == -1) return '自定义';
    return ThemeColors.presets[currentIndex].name;
  }

  String _getFollowSystemColorSubtitle() {
    if (ThemeManager().followSystemColor) {
      if (Platform.isAndroid) {
        return '自动获取 Material You 动态颜色 (Android 12+)';
      } else if (Platform.isWindows) {
        return '从系统个性化设置读取强调色';
      }
      return '自动跟随系统主题色';
    } else {
      return '手动选择主题色';
    }
  }

  String _getThemeFrameworkSubtitle() {
    switch (ThemeManager().themeFramework) {
      case ThemeFramework.material:
        return 'Material Design 3（默认推荐）';
      case ThemeFramework.fluent:
        return 'Fluent UI（Windows 原生风格）';
    }
  }

  String _getMobileThemeFrameworkSubtitle() {
    switch (ThemeManager().mobileThemeFramework) {
      case MobileThemeFramework.material:
        return 'Material Design 3（默认）';
      case MobileThemeFramework.cupertino:
        return 'Cupertino（iOS 风格）';
      case MobileThemeFramework.oculus:
        return 'Oculus（现代简约风格）';
    }
  }

  String _getWindowBackgroundSubtitle() {
    final service = WindowBackgroundService();
    final isSponsor = AuthService().currentUser?.isSponsor ?? false;

    if (!isSponsor) {
      return '赞助用户可设置自定义窗口背景图片';
    }

    if (!service.enabled) {
      return '未启用';
    }

    if (service.hasValidImage) {
      return '已启用 - 模糊度: ${service.blurAmount.toStringAsFixed(0)}';
    }

    return '已启用但未设置图片';
  }

  String _windowEffectLabel(WindowEffect effect) {
    switch (effect) {
      case WindowEffect.disabled:
        return '默认';
      case WindowEffect.mica:
        return '云母';
      case WindowEffect.acrylic:
        return '亚克力';
      case WindowEffect.transparent:
        return '透明';
      default:
        return '默认';
    }
  }

  // ============ 对话框方法 ============

  void _showFluentThemeColorDialog() {
    Color temp = ThemeManager().seedColor;
    fluent_ui.showDialog(
      context: context,
      builder: (context) => fluent_ui.ContentDialog(
        title: const Text('选择主题色'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 480),
          child: Material(
            type: MaterialType.transparency,
            child: SingleChildScrollView(
              child: ColorPicker(
                pickerColor: temp,
                onColorChanged: (color) {
                  temp = color;
                },
                enableAlpha: false,
                displayThumbColor: true,
                pickerAreaHeightPercent: 0.75,
                portraitOnly: true,
                labelTypes: const [],
                hexInputBar: false,
              ),
            ),
          ),
        ),
        actions: [
          fluent_ui.Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          fluent_ui.FilledButton(
            onPressed: () {
              ThemeManager().setSeedColor(temp);
              if (mounted) setState(() {});
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showThemeColorPicker() {
    if (Platform.isAndroid || Platform.isIOS) {
      _showMobileThemeColorPicker();
    } else {
      _showDesktopThemeColorPicker();
    }
  }

  void _showMobileThemeColorPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '选择主题色',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: _ThemeColorGrid(
                    onColorSelected: () {
                      Navigator.pop(context);
                      setState(() {});
                    },
                    onCustomTap: () {
                      Navigator.pop(context);
                      _showCustomColorPicker();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDesktopThemeColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择主题色'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450, maxHeight: 600),
          child: SingleChildScrollView(
            child: _ThemeColorGrid(
              onColorSelected: () {
                Navigator.pop(context);
                setState(() {});
              },
              onCustomTap: () {
                Navigator.pop(context);
                _showCustomColorPicker();
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showCustomColorPicker() {
    if (Platform.isAndroid || Platform.isIOS) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            top: 12,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              CustomColorPickerDialog(
                isBottomSheet: true,
                currentColor: ThemeManager().seedColor,
                onColorSelected: (color) {
                  ThemeManager().setSeedColor(color);
                  setState(() {});
                },
              ),
            ],
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => CustomColorPickerDialog(
          currentColor: ThemeManager().seedColor,
          onColorSelected: (color) {
            ThemeManager().setSeedColor(color);
            setState(() {});
          },
        ),
      );
    }
  }

  void _showLayoutModeDialog() {
    final isFluentUI = ThemeManager().isDesktopFluentUI;

    if (isFluentUI) {
      fluent_ui.showDialog(
        context: context,
        builder: (context) => fluent_ui.ContentDialog(
          title: const Text('选择布局模式'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              fluent_ui.RadioButton(
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('桌面模式'),
                    Text(
                      '侧边导航栏，横屏宽屏布局 (1320x880)',
                      style: fluent_ui.FluentTheme.of(
                        context,
                      ).typography.caption,
                    ),
                  ],
                ),
                checked:
                    LayoutPreferenceService().layoutMode == LayoutMode.desktop,
                onChanged: (v) {
                  LayoutPreferenceService().setLayoutMode(LayoutMode.desktop);
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
              const SizedBox(height: 8),
              fluent_ui.RadioButton(
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('移动模式'),
                    Text(
                      '底部导航栏，竖屏手机布局 (400x850)',
                      style: fluent_ui.FluentTheme.of(
                        context,
                      ).typography.caption,
                    ),
                  ],
                ),
                checked:
                    LayoutPreferenceService().layoutMode == LayoutMode.mobile,
                onChanged: (v) {
                  LayoutPreferenceService().setLayoutMode(LayoutMode.mobile);
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
            ],
          ),
          actions: [
            fluent_ui.Button(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('选择布局模式'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<LayoutMode>(
                title: const Text('桌面模式'),
                subtitle: const Text('侧边导航栏，横屏宽屏布局'),
                secondary: const Icon(Icons.desktop_windows),
                value: LayoutMode.desktop,
                groupValue: LayoutPreferenceService().layoutMode,
                onChanged: (value) {
                  LayoutPreferenceService().setLayoutMode(value!);
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
              RadioListTile<LayoutMode>(
                title: const Text('移动模式'),
                subtitle: const Text('底部导航栏，竖屏手机布局'),
                secondary: const Icon(Icons.smartphone),
                value: LayoutMode.mobile,
                groupValue: LayoutPreferenceService().layoutMode,
                onChanged: (value) {
                  LayoutPreferenceService().setLayoutMode(value!);
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    }
  }

  void _showPlayerStyleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择全屏播放器样式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: LyricStyle.values
              .where((style) => style != LyricStyle.defaultStyle)
              .map((style) {
                return RadioListTile<LyricStyle>(
                  title: Text(LyricStyleService().getStyleName(style)),
                  subtitle: Text(
                    LyricStyleService().getStyleDescription(style),
                  ),
                  value: style,
                  groupValue: LyricStyleService().currentStyle,
                  onChanged: (value) {
                    if (value != null) {
                      LyricStyleService().setStyle(value);
                      Navigator.pop(context);
                      setState(() {});
                    }
                  },
                );
              })
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showPlayerBackgroundDialog() {
    final isFluentUI = ThemeManager().isDesktopFluentUI;
    final isCupertinoUI =
        (Platform.isIOS || Platform.isAndroid) &&
        ThemeManager().isCupertinoFramework;

    if (isCupertinoUI) {
      showCupertinoDialog(
        context: context,
        builder: (context) => PlayerBackgroundDialog(
          onChanged: () {
            if (mounted) setState(() {});
          },
        ),
      );
    } else if (isFluentUI) {
      fluent_ui.showDialog(
        context: context,
        builder: (context) => PlayerBackgroundDialog(
          onChanged: () {
            if (mounted) setState(() {});
          },
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => PlayerBackgroundDialog(
          onChanged: () {
            if (mounted) setState(() {});
          },
        ),
      );
    }
  }

  void _showWindowBackgroundDialog() {
    fluent_ui.showDialog(
      context: context,
      builder: (context) => WindowBackgroundDialog(
        onChanged: () {
          if (mounted) setState(() {});
        },
      ),
    );
  }

  void _showMobileThemeFrameworkDialog() {
    final isCupertino = ThemeManager().isCupertinoFramework;

    if (isCupertino) {
      // Cupertino 风格的底部弹窗
      showCupertinoModalPopup<void>(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: const Text('选择界面风格'),
          message: const Text('切换后界面将自动刷新'),
          actions: [
            CupertinoActionSheetAction(
              isDefaultAction:
                  ThemeManager().mobileThemeFramework ==
                  MobileThemeFramework.material,
              onPressed: () {
                ThemeManager().setMobileThemeFramework(
                  MobileThemeFramework.material,
                );
                Navigator.pop(context);
                setState(() {});
              },
              child: const Text('Material Design 3'),
            ),
            CupertinoActionSheetAction(
              isDefaultAction:
                  ThemeManager().mobileThemeFramework ==
                  MobileThemeFramework.cupertino,
              onPressed: () {
                ThemeManager().setMobileThemeFramework(
                  MobileThemeFramework.cupertino,
                );
                Navigator.pop(context);
                setState(() {});
              },
              child: const Text('Cupertino（iOS 风格）'),
            ),
            CupertinoActionSheetAction(
              isDefaultAction:
                  ThemeManager().mobileThemeFramework ==
                  MobileThemeFramework.oculus,
              onPressed: () {
                ThemeManager().setMobileThemeFramework(
                  MobileThemeFramework.oculus,
                );
                Navigator.pop(context);
                setState(() {});
              },
              child: const Text('Oculus（现代简约风格）'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ),
      );
    } else {
      // Material 风格的对话框
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('选择界面风格'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<MobileThemeFramework>(
                title: const Text('Material Design 3'),
                subtitle: const Text('Android 原生设计风格'),
                secondary: const Icon(Icons.android),
                value: MobileThemeFramework.material,
                groupValue: ThemeManager().mobileThemeFramework,
                onChanged: (value) {
                  if (value == null) return;
                  ThemeManager().setMobileThemeFramework(value);
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
              RadioListTile<MobileThemeFramework>(
                title: const Text('Cupertino'),
                subtitle: const Text('iOS 原生设计风格'),
                secondary: const Icon(Icons.phone_iphone),
                value: MobileThemeFramework.cupertino,
                groupValue: ThemeManager().mobileThemeFramework,
                onChanged: (value) {
                  if (value == null) return;
                  ThemeManager().setMobileThemeFramework(value);
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
              RadioListTile<MobileThemeFramework>(
                title: const Text('Oculus'),
                subtitle: const Text('现代简约设计风格'),
                secondary: const Icon(Icons.blur_on),
                value: MobileThemeFramework.oculus,
                groupValue: ThemeManager().mobileThemeFramework,
                onChanged: (value) {
                  if (value == null) return;
                  ThemeManager().setMobileThemeFramework(value);
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    }
  }

  void _showThemeFrameworkDialog() {
    final isFluentUI = ThemeManager().isDesktopFluentUI;
    if (isFluentUI) {
      fluent_ui.showDialog(
        context: context,
        builder: (context) => fluent_ui.ContentDialog(
          title: const Text('选择桌面主题样式'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              fluent_ui.RadioButton(
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Material Design 3'),
                    Text(
                      '保持现有设计语言，适合跨平台体验',
                      style: fluent_ui.FluentTheme.of(
                        context,
                      ).typography.caption,
                    ),
                  ],
                ),
                checked:
                    ThemeManager().themeFramework == ThemeFramework.material,
                onChanged: (v) {
                  ThemeManager().setThemeFramework(ThemeFramework.material);
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
              const SizedBox(height: 8),
              fluent_ui.RadioButton(
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Fluent UI'),
                    Text(
                      '与 Windows 11 外观保持一致',
                      style: fluent_ui.FluentTheme.of(
                        context,
                      ).typography.caption,
                    ),
                  ],
                ),
                checked: ThemeManager().themeFramework == ThemeFramework.fluent,
                onChanged: (v) {
                  ThemeManager().setThemeFramework(ThemeFramework.fluent);
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
            ],
          ),
          actions: [
            fluent_ui.Button(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('选择桌面主题样式'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeFramework>(
                title: const Text('Material Design 3'),
                subtitle: const Text('保持现有设计语言，适合跨平台体验'),
                secondary: const Icon(Icons.layers_outlined),
                value: ThemeFramework.material,
                groupValue: ThemeManager().themeFramework,
                onChanged: (value) {
                  if (value == null) return;
                  ThemeManager().setThemeFramework(value);
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
              RadioListTile<ThemeFramework>(
                title: const Text('Fluent UI'),
                subtitle: const Text('与 Windows 11 外观保持一致'),
                secondary: const Icon(Icons.desktop_windows),
                value: ThemeFramework.fluent,
                groupValue: ThemeManager().themeFramework,
                onChanged: (value) {
                  if (value == null) return;
                  ThemeManager().setThemeFramework(value);
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    }
  }

  void _showWindowEffectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择窗口材质'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<WindowEffect>(
              title: const Text('默认'),
              subtitle: const Text('不应用特殊的窗口效果'),
              value: WindowEffect.disabled,
              groupValue: ThemeManager().windowEffect,
              onChanged: (value) async {
                if (value != null) {
                  await ThemeManager().setWindowEffect(value);
                  Navigator.pop(context);
                  setState(() {});
                }
              },
            ),
            RadioListTile<WindowEffect>(
              title: const Text('云母 (Mica)'),
              subtitle: Text(
                ThemeManager().isMicaSupported
                    ? 'Windows 11 原生材质效果'
                    : '当前系统不支持（仅限 Win11）',
              ),
              value: WindowEffect.mica,
              groupValue: ThemeManager().windowEffect,
              onChanged: ThemeManager().isMicaSupported
                  ? (value) async {
                      if (value != null) {
                        await ThemeManager().setWindowEffect(value);
                        Navigator.pop(context);
                        setState(() {});
                      }
                    }
                  : null,
            ),
            RadioListTile<WindowEffect>(
              title: const Text('亚克力 (Acrylic)'),
              subtitle: const Text('经典的毛玻璃半透明效果'),
              value: WindowEffect.acrylic,
              groupValue: ThemeManager().windowEffect,
              onChanged: (value) async {
                if (value != null) {
                  await ThemeManager().setWindowEffect(value);
                  Navigator.pop(context);
                  setState(() {});
                }
              },
            ),
            RadioListTile<WindowEffect>(
              title: const Text('透明'),
              subtitle: const Text('完全透明的窗口背景'),
              value: WindowEffect.transparent,
              groupValue: ThemeManager().windowEffect,
              onChanged: (value) async {
                if (value != null) {
                  await ThemeManager().setWindowEffect(value);
                  Navigator.pop(context);
                  setState(() {});
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 显示歌词字体选择对话框 (Fluent UI / Material)
  void _showLyricFontDialog() {
    final isFluentUI = ThemeManager().isDesktopFluentUI;

    if (isFluentUI) {
      fluent_ui.showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => fluent_ui.ContentDialog(
            title: const Text('选择歌词字体'),
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 预设字体列表
                  Text(
                    '预设字体',
                    style: fluent_ui.FluentTheme.of(
                      context,
                    ).typography.subtitle,
                  ),
                  const SizedBox(height: 8),
                  ...LyricFontService.platformFonts.map((font) {
                    final isSelected =
                        LyricFontService().fontType == 'preset' &&
                        LyricFontService().presetFontId == font.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: fluent_ui.RadioButton(
                        checked: isSelected,
                        onChanged: (v) async {
                          await LyricFontService().setPresetFont(font.id);
                          setDialogState(() {});
                          if (mounted) setState(() {});
                        },
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              font.name,
                              style: TextStyle(
                                fontFamily: font.fontFamily,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              font.description,
                              style: fluent_ui.FluentTheme.of(
                                context,
                              ).typography.caption,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),
                  const fluent_ui.Divider(),
                  const SizedBox(height: 16),

                  // 自定义字体
                  Text(
                    '自定义字体',
                    style: fluent_ui.FluentTheme.of(
                      context,
                    ).typography.subtitle,
                  ),
                  const SizedBox(height: 8),
                  if (LyricFontService().fontType == 'custom' &&
                      LyricFontService().customFontPath != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: fluent_ui.InfoBar(
                        title: Text(
                          '当前使用: ${LyricFontService().customFontPath!.split(Platform.pathSeparator).last}',
                        ),
                        severity: fluent_ui.InfoBarSeverity.success,
                      ),
                    ),
                  Row(
                    children: [
                      fluent_ui.Button(
                        onPressed: () async {
                          final success = await LyricFontService()
                              .pickAndLoadCustomFont();
                          if (success) {
                            setDialogState(() {});
                            if (mounted) setState(() {});
                          }
                        },
                        child: const Text('选择字体文件'),
                      ),
                      const SizedBox(width: 8),
                      if (LyricFontService().fontType == 'custom')
                        fluent_ui.Button(
                          onPressed: () async {
                            await LyricFontService().clearCustomFont();
                            setDialogState(() {});
                            if (mounted) setState(() {});
                          },
                          child: const Text('清除自定义字体'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '支持 .ttf, .otf, .ttc 格式的字体文件',
                    style: fluent_ui.FluentTheme.of(context).typography.caption,
                  ),
                ],
              ),
            ),
            actions: [
              fluent_ui.Button(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ],
          ),
        ),
      );
    } else {
      // Material UI 对话框
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('选择歌词字体'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 预设字体列表
                    Text(
                      '预设字体',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...LyricFontService.platformFonts.map((font) {
                      final isSelected =
                          LyricFontService().fontType == 'preset' &&
                          LyricFontService().presetFontId == font.id;
                      return RadioListTile<String>(
                        value: font.id,
                        groupValue: LyricFontService().fontType == 'preset'
                            ? LyricFontService().presetFontId
                            : null,
                        onChanged: (value) async {
                          if (value != null) {
                            await LyricFontService().setPresetFont(value);
                            setDialogState(() {});
                            if (mounted) setState(() {});
                          }
                        },
                        title: Text(
                          font.name,
                          style: TextStyle(
                            fontFamily: font.fontFamily,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(font.description),
                        dense: true,
                        selected: isSelected,
                      );
                    }),

                    const Divider(height: 24),

                    // 自定义字体
                    Text(
                      '自定义字体',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (LyricFontService().fontType == 'custom' &&
                        LyricFontService().customFontPath != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '当前使用: ${LyricFontService().customFontPath!.split(Platform.pathSeparator).last}',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final success = await LyricFontService()
                                .pickAndLoadCustomFont();
                            if (success) {
                              setDialogState(() {});
                              if (mounted) setState(() {});
                            }
                          },
                          icon: const Icon(Icons.folder_open),
                          label: const Text('选择字体文件'),
                        ),
                        const SizedBox(width: 8),
                        if (LyricFontService().fontType == 'custom')
                          TextButton(
                            onPressed: () async {
                              await LyricFontService().clearCustomFont();
                              setDialogState(() {});
                              if (mounted) setState(() {});
                            },
                            child: const Text('清除'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '支持 .ttf, .otf, .ttc 格式的字体文件',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ],
          ),
        ),
      );
    }
  }

  /// 显示歌词字体选择对话框 (Cupertino)
  void _showCupertinoLyricFontDialog() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Material(
          type: MaterialType.transparency,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: CupertinoTheme.of(context).barBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  // 拖动指示器
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // 标题
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '选择歌词字体',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // 内容
                  Expanded(
                    child: CupertinoScrollbar(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // 预设字体
                          const Padding(
                            padding: EdgeInsets.only(top: 16, bottom: 8),
                            child: Text(
                              '预设字体',
                              style: TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.systemGrey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ...LyricFontService.platformFonts.map((font) {
                            final isSelected =
                                LyricFontService().fontType == 'preset' &&
                                LyricFontService().presetFontId == font.id;
                            return CupertinoListTile(
                              title: Text(
                                font.name,
                                style: TextStyle(
                                  fontFamily: font.fontFamily,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(font.description),
                              trailing: isSelected
                                  ? const Icon(
                                      CupertinoIcons.checkmark,
                                      color: CupertinoColors.activeBlue,
                                    )
                                  : null,
                              onTap: () async {
                                await LyricFontService().setPresetFont(font.id);
                                setDialogState(() {});
                                if (mounted) setState(() {});
                              },
                            );
                          }),

                          // 自定义字体
                          const Padding(
                            padding: EdgeInsets.only(top: 24, bottom: 8),
                            child: Text(
                              '自定义字体',
                              style: TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.systemGrey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (LyricFontService().fontType == 'custom' &&
                              LyricFontService().customFontPath != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: CupertinoColors.activeGreen.withOpacity(
                                  0.1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    CupertinoIcons.checkmark_circle_fill,
                                    color: CupertinoColors.activeGreen,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '当前使用: ${LyricFontService().customFontPath!.split(Platform.pathSeparator).last}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Row(
                            children: [
                              CupertinoButton(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                color: CupertinoColors.activeBlue,
                                onPressed: () async {
                                  final success = await LyricFontService()
                                      .pickAndLoadCustomFont();
                                  if (success) {
                                    setDialogState(() {});
                                    if (mounted) setState(() {});
                                  }
                                },
                                child: const Text(
                                  '选择字体文件',
                                  style: TextStyle(
                                    color: CupertinoColors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (LyricFontService().fontType == 'custom')
                                CupertinoButton(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  onPressed: () async {
                                    await LyricFontService().clearCustomFont();
                                    setDialogState(() {});
                                    if (mounted) setState(() {});
                                  },
                                  child: const Text('清除'),
                                ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 8, bottom: 24),
                            child: Text(
                              '支持 .ttf, .otf, .ttc 格式的字体文件',
                              style: TextStyle(
                                fontSize: 12,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 关闭按钮
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        color: CupertinoColors.systemGrey5,
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          '关闭',
                          style: TextStyle(color: CupertinoColors.label),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeColorGrid extends StatelessWidget {
  final VoidCallback onColorSelected;
  final VoidCallback onCustomTap;

  const _ThemeColorGrid({
    required this.onColorSelected,
    required this.onCustomTap,
  });

  @override
  Widget build(BuildContext context) {
    final currentIndex = ThemeManager().getCurrentColorIndex();
    final theme = Theme.of(context);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: ThemeColors.presets.length + 1,
      itemBuilder: (context, index) {
        if (index == ThemeColors.presets.length) {
          final isCustomSelected = currentIndex == -1;
          return _buildCustomButton(context, isCustomSelected);
        }

        final colorPreset = ThemeColors.presets[index];
        final isSelected = index == currentIndex;

        return _ColorSwatch(
          color: colorPreset.color,
          name: colorPreset.name,
          icon: colorPreset.icon,
          isSelected: isSelected,
          onTap: () {
            ThemeManager().setSeedColor(colorPreset.color);
            onColorSelected();
          },
        );
      },
    );
  }

  Widget _buildCustomButton(BuildContext context, bool isSelected) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    return InkWell(
      onTap: onCustomTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52,
            height: 52,
            padding: EdgeInsets.all(isSelected ? 3 : 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isSelected ? Border.all(color: color, width: 2) : null,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                isSelected ? Icons.check : Icons.add,
                color: color,
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '自定义',
            style: theme.textTheme.labelMedium?.copyWith(
              color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final String name;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.name,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52,
            height: 52,
            padding: EdgeInsets.all(isSelected ? 3 : 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isSelected ? Border.all(color: color, width: 2) : null,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                isSelected ? Icons.check : icon,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
