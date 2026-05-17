import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';
import '../core/constants.dart';

class HistoryService {
  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;
  HistoryService._internal();

  Box<ConversionRecord> get _box =>
      Hive.box<ConversionRecord>(AppConstants.historyBox);

  List<ConversionRecord> getAll() {
    final records = _box.values.toList();
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  Future<void> add(ConversionRecord record) async {
    await _box.put(record.id, record);

    // Garder seulement les 50 dernières conversions
    if (_box.length > 50) {
      final keys = _box.keys.toList();
      await _box.delete(keys.first);
    }
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> clearAll() async {
    await _box.clear();
  }

  int get todayCount {
    final today = DateTime.now();
    return _box.values.where((r) {
      final d = r.createdAt;
      return d.year == today.year &&
          d.month == today.month &&
          d.day == today.day &&
          r.isSuccess;
    }).length;
  }
}
