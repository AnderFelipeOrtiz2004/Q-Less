import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  FavoritesService._();

  static String _keyForUser(int userId) => 'favorite_product_ids_$userId';

  static Future<Set<int>> getFavoriteIds({required int userId}) async {
    if (userId <= 0) return {};
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyForUser(userId));
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .where((id) => id > 0)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveFavoriteIds({
    required int userId,
    required Set<int> ids,
  }) async {
    if (userId <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyForUser(userId),
      jsonEncode(ids.toList()..sort()),
    );
  }

  static Future<bool> isFavorite({
    required int userId,
    required int productId,
  }) async {
    final ids = await getFavoriteIds(userId: userId);
    return ids.contains(productId);
  }

  static Future<bool> toggleFavorite({
    required int userId,
    required int productId,
  }) async {
    final ids = await getFavoriteIds(userId: userId);
    if (ids.contains(productId)) {
      ids.remove(productId);
      await saveFavoriteIds(userId: userId, ids: ids);
      return false;
    }
    ids.add(productId);
    await saveFavoriteIds(userId: userId, ids: ids);
    return true;
  }
}
