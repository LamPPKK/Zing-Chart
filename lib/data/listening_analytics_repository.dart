import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/listening_analytics.dart';

abstract interface class ListeningAnalyticsRepository {
  Future<ListeningAnalyticsSnapshot?> load();

  Future<void> save(ListeningAnalyticsSnapshot snapshot);
}

class SharedPreferencesListeningAnalyticsRepository
    implements ListeningAnalyticsRepository {
  SharedPreferencesListeningAnalyticsRepository({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences;

  static const storageKey = 'listening_analytics_v1';
  SharedPreferencesAsync? _preferences;

  @override
  Future<ListeningAnalyticsSnapshot?> load() async {
    try {
      final preferences = _preferences ??= SharedPreferencesAsync();
      final encoded = await preferences.getString(storageKey);
      if (encoded == null || encoded.isEmpty) return null;
      final decoded = jsonDecode(encoded);
      return decoded is Map<String, dynamic>
          ? ListeningAnalyticsSnapshot.fromJson(decoded)
          : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(ListeningAnalyticsSnapshot snapshot) async {
    final preferences = _preferences ??= SharedPreferencesAsync();
    await preferences.setString(storageKey, snapshot.encode());
  }
}

class MemoryListeningAnalyticsRepository
    implements ListeningAnalyticsRepository {
  MemoryListeningAnalyticsRepository([this.snapshot]);

  ListeningAnalyticsSnapshot? snapshot;
  int saveCalls = 0;

  @override
  Future<ListeningAnalyticsSnapshot?> load() async => snapshot;

  @override
  Future<void> save(ListeningAnalyticsSnapshot snapshot) async {
    saveCalls++;
    this.snapshot = snapshot;
  }
}
