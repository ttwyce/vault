// =============================================================================
// Design Tokens —— 全站视觉决策的唯一来源
//
// 规则：业务代码禁止出现十六进制色值与魔法数字。
//       所有间距、圆角、字号、时长必须来自本文件。
// =============================================================================

import 'package:flutter/material.dart';

/// 原始调色板。语义映射见 `AppSemanticColors`。
abstract final class AppPalette {
  AppPalette._();

  // ---- 中性色：暖灰（纸感），而非冷灰 ----
  static const neutral0 = Color(0xFFFFFFFF);
  static const neutral25 = Color(0xFFFCFCFB);
  static const neutral50 = Color(0xFFFAFAF9);
  static const neutral100 = Color(0xFFF5F5F4);
  static const neutral200 = Color(0xFFE7E5E4);
  static const neutral300 = Color(0xFFD6D3D1);
  static const neutral400 = Color(0xFFA8A29E);
  static const neutral500 = Color(0xFF78716C);
  static const neutral600 = Color(0xFF57534E);
  static const neutral700 = Color(0xFF44403C);
  static const neutral800 = Color(0xFF292524);
  static const neutral900 = Color(0xFF1C1917);
  static const neutral950 = Color(0xFF0C0A09);
  static const neutral1000 = Color(0xFF080706);

  // 暗色专用的三级表面（比纯黑更柔和，避免 OLED 上的割裂感）
  static const darkSurface = Color(0xFF171412);
  static const darkSurfaceRaised = Color(0xFF211D1B);
  static const darkSurfaceSunken = Color(0xFF100E0D);
  static const darkBorder = Color(0xFF2A2523);
  static const darkBorderStrong = Color(0xFF3A3431);

  // ---- 主色：Teal（信任 / 冷静）----
  static const teal50 = Color(0xFFF0FDFA);
  static const teal100 = Color(0xFFCCFBF1);
  static const teal300 = Color(0xFF5EEAD4);
  static const teal400 = Color(0xFF2DD4BF);
  static const teal500 = Color(0xFF14B8A6);
  static const teal600 = Color(0xFF0D9488);
  static const teal700 = Color(0xFF0F766E);
  static const teal800 = Color(0xFF115E59);
  static const teal900 = Color(0xFF134E4A);

  // ---- AI 色：Violet（只用于 AI 生成内容，绝不作装饰）----
  static const violet50 = Color(0xFFF5F3FF);
  static const violet100 = Color(0xFFEDE9FE);
  static const violet300 = Color(0xFFC4B5FD);
  static const violet400 = Color(0xFFA78BFA);
  static const violet500 = Color(0xFF8B5CF6);
  static const violet600 = Color(0xFF6D5BD0);

  // ---- 语义色 ----
  static const green50 = Color(0xFFF0FDF4);
  static const green400 = Color(0xFF4ADE80);
  static const green600 = Color(0xFF15803D);

  static const amber50 = Color(0xFFFFFBEB);
  static const amber400 = Color(0xFFFBBF24);
  static const amber700 = Color(0xFFB45309);

  static const red50 = Color(0xFFFEF2F2);
  static const red400 = Color(0xFFF87171);
  static const red600 = Color(0xFFDC2626);
  static const red700 = Color(0xFFB91C1C);
}

// =============================================================================
// 间距：4px 基准
// =============================================================================
abstract final class AppSpacing {
  AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
  static const double huge = 64;

  /// 面板内边距
  static const double panelPadding = 24;

  /// 列表项左右内边距
  static const double listInsetX = 16;

  /// 列表项上下内边距（桌面更紧凑）
  static const double listInsetYCompact = 10;
  static const double listInsetYTouch = 12;

  /// 阅读区最大行宽（≈72ch）
  static const double readingMaxWidth = 720;
}

// =============================================================================
// 圆角
// =============================================================================
abstract final class AppRadius {
  AppRadius._();

  static const double xs = 4; // 标签、徽章
  static const double sm = 6; // 按钮、输入框
  static const double md = 10; // 卡片、悬停背景
  static const double lg = 14; // 面板、侧栏
  static const double xl = 20; // 弹窗、抽屉
  static const double full = 999;

  static const BorderRadius xsR = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smR = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdR = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgR = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlR = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius fullR = BorderRadius.all(Radius.circular(full));

  /// 用户消息气泡：右下角收窄
  static const BorderRadius bubbleUser = BorderRadius.only(
    topLeft: Radius.circular(md),
    topRight: Radius.circular(md),
    bottomLeft: Radius.circular(md),
    bottomRight: Radius.circular(xs),
  );
}

// =============================================================================
// 响应式断点
// =============================================================================
enum AppBreakpoint { compact, medium, expanded, large }

abstract final class AppBreakpoints {
  AppBreakpoints._();

  static const double mediumMin = 600;
  static const double expandedMin = 840;
  static const double largeMin = 1200;

  static AppBreakpoint of(double width) {
    if (width < mediumMin) return AppBreakpoint.compact;
    if (width < expandedMin) return AppBreakpoint.medium;
    if (width < largeMin) return AppBreakpoint.expanded;
    return AppBreakpoint.large;
  }
}

extension AppBreakpointX on AppBreakpoint {
  bool get isCompact => this == AppBreakpoint.compact;
  bool get isMedium => this == AppBreakpoint.medium;

  /// 是否显示三栏布局
  bool get isMultiPane =>
      this == AppBreakpoint.expanded || this == AppBreakpoint.large;

  /// 是否显示 AI 第四栏
  bool get canShowAssistantPane => this == AppBreakpoint.large;

  /// 是否使用触控尺寸（44px 目标）
  bool get isTouch => this == AppBreakpoint.compact || this == AppBreakpoint.medium;
}

// =============================================================================
// 动效
// =============================================================================
abstract final class AppMotion {
  AppMotion._();

  // 时长
  static const Duration micro = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 200);
  static const Duration panel = Duration(milliseconds: 280);
  static const Duration sheet = Duration(milliseconds: 320);

  /// 骨架屏呼吸
  static const Duration skeleton = Duration(milliseconds: 1200);

  // 曲线
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve move = Curves.easeInOutCubic;
  static const Curve emphasized = Cubic(0.2, 0, 0, 1);

  /// 页面切换位移量
  static const double pageSlide = 8;

  /// 尊重系统「减少动效」
  static Duration respect(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : d;
}

// =============================================================================
// 阴影：只用于浮层，暗色模式不用阴影
// =============================================================================
abstract final class AppElevation {
  AppElevation._();

  static const List<BoxShadow> popover = [
    BoxShadow(
      color: Color(0x1A1C1917), // 10% neutral900
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> modal = [
    BoxShadow(
      color: Color(0x291C1917), // 16% neutral900
      blurRadius: 48,
      offset: Offset(0, 16),
    ),
  ];

  static const List<BoxShadow> none = [];
}

// =============================================================================
// 字体
// =============================================================================
abstract final class AppFonts {
  AppFonts._();

  /// 需在 pubspec 中声明 assets/fonts/Inter-*.ttf；未声明时自动回退系统字体
  static const String ui = 'Inter';

  /// 等宽：密码、TOTP、代码
  static const String mono = 'JetBrainsMono';

  /// 阅读模式衬线：留空使用系统衬线（iOS Songti SC / Win SimSun）
  static const String? reading = null;
}

/// 字号阶梯。返回的 TextStyle 不含颜色，颜色由主题注入。
abstract final class AppTypeScale {
  AppTypeScale._();

  static const TextStyle display = TextStyle(
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
  );

  static const TextStyle h1 = TextStyle(
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 17,
    height: 24 / 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );

  /// 阅读模式正文
  static const TextStyle bodyLg = TextStyle(
    fontSize: 16,
    height: 26 / 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    height: 24 / 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static const TextStyle bodySm = TextStyle(
    fontSize: 14,
    height: 22 / 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static const TextStyle label = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
  );

  static const TextStyle badge = TextStyle(
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  static const TextStyle mono = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: 13,
    height: 20 / 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

// =============================================================================
// 尺寸常量
// =============================================================================
abstract final class AppSizes {
  AppSizes._();

  static const double iconSm = 16;
  static const double icon = 20;
  static const double iconLg = 24;

  /// 移动端最小触控目标
  static const double touchTarget = 44;

  /// 桌面端控件高度
  static const double controlHeightDesktop = 36;
  static const double controlHeightTouch = 44;

  static const double topBar = 48;
  static const double searchField = 40;
  static const double navRail = 240;
  static const double navRailCollapsed = 64;
  static const double listPaneMin = 280;
  static const double listPaneMax = 480;
  static const double listPaneDefault = 340;
  static const double assistantPane = 380;

  static const double statusDot = 6;
  static const double badgeHeight = 20;
}
