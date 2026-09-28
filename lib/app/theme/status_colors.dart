import 'package:flutter/material.dart';

import '../../core/domain/tone.dart';
import 'app_colors.dart';

/// Couleurs sémantiques des statuts (texte + fond), par thème.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.neutral,
    required this.backgroundOpacity,
  });

  static const light = StatusColors(
    success: AppColors.successLight,
    warning: AppColors.warningLight,
    danger: AppColors.dangerLight,
    info: AppColors.infoLight,
    neutral: AppColors.neutralLight,
    backgroundOpacity: 0.10,
  );

  static const dark = StatusColors(
    success: AppColors.successDark,
    warning: AppColors.warningDark,
    danger: AppColors.dangerDark,
    info: AppColors.infoDark,
    neutral: AppColors.neutralDark,
    backgroundOpacity: 0.16,
  );

  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color neutral;
  final double backgroundOpacity;

  Color foreground(Tone tone) => switch (tone) {
    Tone.success => success,
    Tone.warning => warning,
    Tone.danger => danger,
    Tone.info => info,
    Tone.neutral => neutral,
  };

  Color background(Tone tone) =>
      foreground(tone).withValues(alpha: backgroundOpacity);

  static StatusColors of(BuildContext context) =>
      Theme.of(context).extension<StatusColors>() ?? light;

  @override
  StatusColors copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? neutral,
    double? backgroundOpacity,
  }) => StatusColors(
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    info: info ?? this.info,
    neutral: neutral ?? this.neutral,
    backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
  );

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      info: Color.lerp(info, other.info, t) ?? info,
      neutral: Color.lerp(neutral, other.neutral, t) ?? neutral,
      backgroundOpacity:
          backgroundOpacity + (other.backgroundOpacity - backgroundOpacity) * t,
    );
  }
}
