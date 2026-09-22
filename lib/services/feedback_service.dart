import 'package:flutter/services.dart';

import '../data/settings/app_settings.dart';

/// Key-press haptics and click sounds. The system click sound follows the
/// device's own touch-sound / silent settings.
class FeedbackService {
  const FeedbackService();

  void keyPress(AppSettings s) {
    switch (s.haptics) {
      case HapticLevel.off:
        break;
      case HapticLevel.light:
        HapticFeedback.selectionClick();
      case HapticLevel.medium:
        HapticFeedback.lightImpact();
    }
    if (s.keySound) SystemSound.play(SystemSoundType.click);
  }

  void error(AppSettings s) {
    if (s.haptics != HapticLevel.off) HapticFeedback.mediumImpact();
  }
}
