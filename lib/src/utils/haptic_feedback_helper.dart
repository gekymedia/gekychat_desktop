import 'package:flutter/services.dart';
import 'dart:io';

/// Haptic feedback helper for tactile responses on supported platforms
/// Enhances UX by providing physical feedback for important actions
class HapticFeedbackHelper {
  /// Light impact - for subtle interactions (button taps, selections)
  static Future<void> light() async {
    if (!_isSupported()) return;
    await HapticFeedback.lightImpact();
  }

  /// Medium impact - for standard interactions (message sent, item deleted)
  static Future<void> medium() async {
    if (!_isSupported()) return;
    await HapticFeedback.mediumImpact();
  }

  /// Heavy impact - for important actions (errors, confirmations)
  static Future<void> heavy() async {
    if (!_isSupported()) return;
    await HapticFeedback.heavyImpact();
  }

  /// Selection - for scrolling through items or sliding
  static Future<void> selection() async {
    if (!_isSupported()) return;
    await HapticFeedback.selectionClick();
  }

  /// Vibrate - for notifications and alerts
  static Future<void> vibrate() async {
    if (!_isSupported()) return;
    await HapticFeedback.vibrate();
  }

  /// Success feedback - for successful operations
  static Future<void> success() async {
    await medium();
  }

  /// Error feedback - for errors and warnings
  static Future<void> error() async {
    await heavy();
  }

  /// Confirmation feedback - for destructive actions
  static Future<void> confirmation() async {
    await heavy();
  }

  /// Check if haptic feedback is supported on this platform
  static bool _isSupported() {
    // Desktop platforms typically don't have haptic feedback
    // Mobile platforms (via Flutter) do support it
    // For desktop with touchpad/trackpad, macOS supports it
    return Platform.isAndroid || 
           Platform.isIOS || 
           Platform.isMacOS; // Modern MacBooks have taptic engine
  }

  /// Custom pattern - double tap
  static Future<void> doubleTap() async {
    if (!_isSupported()) return;
    await light();
    await Future.delayed(const Duration(milliseconds: 50));
    await light();
  }

  /// Custom pattern - triple tap  
  static Future<void> tripleTap() async {
    if (!_isSupported()) return;
    await light();
    await Future.delayed(const Duration(milliseconds: 50));
    await light();
    await Future.delayed(const Duration(milliseconds: 50));
    await light();
  }
}

/// Extension for convenient haptic feedback on widgets
extension HapticExtension on BuildContext {
  Future<void> hapticLight() => HapticFeedbackHelper.light();
  Future<void> hapticMedium() => HapticFeedbackHelper.medium();
  Future<void> hapticHeavy() => HapticFeedbackHelper.heavy();
  Future<void> hapticSelection() => HapticFeedbackHelper.selection();
  Future<void> hapticSuccess() => HapticFeedbackHelper.success();
  Future<void> hapticError() => HapticFeedbackHelper.error();
}
