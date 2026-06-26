import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class DiscountWheelService {
  static const _lastSpinKey = 'discount_wheel_last_spin_ms';
  static const _activePercentKey = 'discount_wheel_active_percent';
  static const _activeUntilKey = 'discount_wheel_active_until_ms';
  static const spinCooldown = Duration(minutes: 10);
  static const prizeDuration = Duration(hours: 24);

  static const List<int> prizes = [5, 10, 15, 20, 5, 10, 0, 25];

  static Future<bool> canSpin() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_lastSpinKey);
    if (lastMs == null) return true;
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    return DateTime.now().difference(last) >= spinCooldown;
  }

  static Future<Duration?> timeUntilNextSpin() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_lastSpinKey);
    if (lastMs == null) return Duration.zero;
    final elapsed = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(lastMs),
    );
    if (elapsed >= spinCooldown) return Duration.zero;
    return spinCooldown - elapsed;
  }

  static Future<int?> activeDiscountPercent() async {
    final prefs = await SharedPreferences.getInstance();
    final untilMs = prefs.getInt(_activeUntilKey);
    if (untilMs == null) return null;
    if (DateTime.now().millisecondsSinceEpoch > untilMs) {
      await clearActiveDiscount();
      return null;
    }
    final percent = prefs.getInt(_activePercentKey) ?? 0;
    return percent > 0 ? percent : null;
  }

  static Future<void> clearActiveDiscount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activePercentKey);
    await prefs.remove(_activeUntilKey);
  }

  static Future<int> spin() async {
    final can = await canSpin();
    if (!can) {
      return -1;
    }

    final index = Random().nextInt(prizes.length);
    final prize = prizes[index];

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setInt(_lastSpinKey, now.millisecondsSinceEpoch);

    if (prize > 0) {
      await prefs.setInt(_activePercentKey, prize);
      await prefs.setInt(
        _activeUntilKey,
        now.add(prizeDuration).millisecondsSinceEpoch,
      );
    } else {
      await clearActiveDiscount();
    }

    return prize;
  }

  static int discountAmount(int subtotal, int percent) {
    if (percent <= 0 || subtotal <= 0) return 0;
    return ((subtotal * percent) / 100).round();
  }
}
