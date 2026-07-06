import 'dart:async';
import 'package:get/get.dart';
import '../core/services/game_service.dart';
import '../models/game.dart';

class LiveDrawController extends GetxController {
  final RxBool isLive = false.obs;

  static const _preWindow = Duration(minutes: 10);
  static const _postWindow = Duration(hours: 1);
  static const _manilaOffset = Duration(hours: 8);

  List<DrawTime> _schedule = [];
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    _loadSchedule();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _tick());
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  Future<void> _loadSchedule() async {
    try {
      final games = await GameService.fetchGames();
      final nationalGames = games
          .where((g) => g.drawType.toLowerCase() == 'national' && g.isActive)
          .toList();
      final seen = <String>{};
      final times = <DrawTime>[];
      for (final game in nationalGames) {
        for (final dt in game.drawTimes) {
          if (dt.id.isEmpty || seen.contains(dt.id)) continue;
          seen.add(dt.id);
          times.add(dt);
        }
      }
      _schedule = times;
      _tick();
    } catch (_) {}
  }

  void _tick() {
    if (_schedule.isEmpty) return;
    final manilaNow = DateTime.now().toUtc().add(_manilaOffset);
    bool live = false;
    for (final dt in _schedule) {
      final timeMap = _extractTime(dt.drawTime);
      final target = DateTime.utc(
        manilaNow.year, manilaNow.month, manilaNow.day,
        timeMap['hour'] ?? 0, timeMap['minute'] ?? 0,
      );
      final diff = target.difference(manilaNow);
      if (diff <= _preWindow && diff >= -_postWindow) {
        live = true;
        break;
      }
    }
    isLive.value = live;
  }

  Map<String, int> _extractTime(String drawTime) {
    try {
      String timeStr = drawTime;
      if (drawTime.contains('T')) {
        timeStr = drawTime.split('T')[1].replaceAll('Z', '');
      }
      final parts = timeStr.split(':');
      if (parts.length < 2) return {'hour': 0, 'minute': 0};
      return {
        'hour': int.tryParse(parts[0]) ?? 0,
        'minute': int.tryParse(parts[1]) ?? 0,
      };
    } catch (_) {
      return {'hour': 0, 'minute': 0};
    }
  }
}
