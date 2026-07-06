import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/design_system.dart';
import '../../core/services/draw_results_service.dart';
import '../../core/services/draw_time_service.dart';
import '../../core/services/game_service.dart';
import '../../core/services/websocket_service.dart';

class LivePage extends StatefulWidget {
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  static const _preWindow = Duration(minutes: 10);
  static const _postWindow = Duration(hours: 1);
  static const _manilaOffset = Duration(hours: 8);

  List<DrawTimeData> _schedule = [];
  DateTime? _nextDraw;
  int? _liveScheduleIndex;
  int? _nextScheduleIndex;
  String _timeLeft = '';
  bool _isLive = false;
  Timer? _timer;
  WebViewController? _webViewController;
  List<LiveDrawResult> _latestResults = [];
  bool _isLoadingResults = true;
  String? _resultsError;
  VoidCallback? _removeDrawResultListener;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _loadSchedule();
    _loadLatestResults();
    _bindRealtimeUpdates();
    // Also listen to possible server events that announce the live stream start
    try {
      final ws = Get.find<WebSocketService>();
      ws.on('draw.started', (_) {
        _loadLatestResults();
        _tick();
      });
      ws.on('draw.streaming', (_) {
        _loadLatestResults();
        _tick();
      });
    } catch (_) {}

    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _removeDrawResultListener?.call();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadSchedule() async {
    try {
      // First, attempt to fetch games and extract draw times for games
      // explicitly configured as National. This is authoritative and avoids
      // showing multiple local draw times.
      List<DrawTimeData> scheduleToUse = [];
      try {
        final games = await GameService.fetchGames();
        final nationalGames = games.where((g) => (g.drawType).toLowerCase() == 'national' && g.isActive).toList();

        // Collect draw times from national games and deduplicate by id
        final seen = <String>{};
        for (final game in nationalGames) {
          for (final dt in game.drawTimes) {
            if (dt.id.isEmpty) continue;
            if (seen.contains(dt.id)) continue;
            seen.add(dt.id);
            scheduleToUse.add(DrawTimeData(
              id: dt.id,
              drawTime: dt.drawTime,
              cutoffMinutes: dt.cutoffMinutes,
              isActive: dt.isActive,
              createdAt: dt.createdAt,
              deletedAt: dt.deletedAt,
              drawType: 'national',
              gameId: game.id,
              isNational: true,
            ));
          }
        }

        // If we found national draw times via games, use them (sorted)
        if (scheduleToUse.isNotEmpty) {
          scheduleToUse.sort((a, b) {
            final aTime = a.extractTime();
            final bTime = b.extractTime();
            final aMinutes = (aTime['hour'] ?? 0) * 60 + (aTime['minute'] ?? 0);
            final bMinutes = (bTime['hour'] ?? 0) * 60 + (bTime['minute'] ?? 0);
            return aMinutes.compareTo(bMinutes);
          });
        } else {
          // Fallback: use draw times endpoint and filter by isNational flag
          final drawTimes = await DrawTimeService.fetchDrawTimes();
          final nationalOnly = drawTimes.where((dt) => dt.isNational).toList();
          if (nationalOnly.isNotEmpty) {
            scheduleToUse = nationalOnly;
          } else {
            // Last resort: no strong national metadata — show nothing to avoid
            // clutter. The UI will show an empty schedule.
            scheduleToUse = [];
          }
        }
      } catch (e) {
        debugPrint('Failed to fetch games/draw-times for national filtering: $e');
        // On error, keep schedule empty to avoid showing incorrect local times
        scheduleToUse = [];
      }

      if (mounted) {
        setState(() {
          _schedule = scheduleToUse;
        });
        _tick();
      }
    } catch (e) {
      debugPrint('Error loading schedule: $e');
    }
  }

  void _bindRealtimeUpdates() {
    try {
      final ws = Get.find<WebSocketService>();
      _removeDrawResultListener = ws.on('draw_result.posted', (_) {
        _loadLatestResults();
        _tick();
      });
    } catch (_) {
      _removeDrawResultListener = null;
    }
  }

  Future<void> _loadLatestResults() async {
    try {
      final results = await DrawResultsService.getLatestResults(
        drawDate: _currentManilaDate(),
      );
      if (!mounted) return;

      // Determine if any recent result indicates a live draw (within postWindow)
      final manilaNow = DateTime.now().toUtc().add(_manilaOffset);
      bool liveFromResults = results.any((r) {
        if (r.updatedAt == null) return false;
        final parsed = DateTime.tryParse(r.updatedAt!);
        if (parsed == null) return false;
        final updated = parsed.toUtc().add(_manilaOffset);
        final diff = manilaNow.difference(updated).abs();
        return diff <= _postWindow;
      });

      setState(() {
        _latestResults = results;
        _isLoadingResults = false;
        _resultsError = null;
        // If schedule already determined live, keep it true; otherwise use results
        _isLive = _isLive || liveFromResults;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _latestResults = [];
        _isLoadingResults = false;
        _resultsError = e.toString();
      });
    }
  }

  void _tick() {
    if (_schedule.isEmpty || !mounted) {
      return;
    }

    final manilaNow = DateTime.now().toUtc().add(_manilaOffset);
    DateTime? liveDraw;
    DateTime? nextDraw;
    int? liveIndex;
    int? nextIndex;

    for (int dayOffset = 0; dayOffset < 2; dayOffset++) {
      for (var i = 0; i < _schedule.length; i++) {
        final timeMap = _schedule[i].extractTime();
        // Use DateTime.utc so target and manilaNow are both UTC — avoids phone
        // timezone offset corrupting the difference calculation.
        final target = DateTime.utc(
          manilaNow.year,
          manilaNow.month,
          manilaNow.day + dayOffset,
          timeMap['hour'] ?? 0,
          timeMap['minute'] ?? 0,
        );
        final diff = target.difference(manilaNow);

        if (liveDraw == null && diff <= _preWindow && diff >= -_postWindow) {
          liveDraw = target;
          liveIndex = i;
        }

        if (nextDraw == null && diff > Duration.zero) {
          nextDraw = target;
          nextIndex = i;
        }
      }
    }

    final activeDraw = liveDraw ?? nextDraw;
    final diff = activeDraw?.difference(manilaNow);

    setState(() {
      _isLive = liveDraw != null;
      _nextDraw = activeDraw;
      _liveScheduleIndex = liveIndex;
      _nextScheduleIndex = nextIndex;
      _timeLeft = liveDraw != null
          ? 'Live now'
          : diff == null
          ? '—'
          : _formatDuration(diff);
    });
  }

  void _initWebView() {
    const channelId = 'UCpOm2kv1upnIFoOT7rSp6hg';
    final uri = Uri.parse(
      'https://www.youtube-nocookie.com/embed/live_stream'
      '?channel=$channelId&autoplay=1&mute=1&playsinline=1&rel=0',
    );
    final controller = WebViewController();
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadRequest(uri);

    // Assign directly — called from initState before first build so setState is not needed
    _webViewController = controller;
  }

  String _currentManilaDate() {
    final manilaNow = DateTime.now().toUtc().add(_manilaOffset);
    return DateFormat('yyyy-MM-dd').format(manilaNow);
  }

  String _formatDuration(Duration duration) {
    final normalized = duration.isNegative ? Duration.zero : duration;
    final hours = normalized.inHours;
    final minutes = normalized.inMinutes.remainder(60);
    final seconds = normalized.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return '${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
  }

  String _formatScheduleTime(DrawTimeData drawTime) {
    final time = drawTime.extractTime();
    final date = DateTime(2000, 1, 1, time['hour'] ?? 0, time['minute'] ?? 0);
    return DateFormat.jm().format(date);
  }

  String _formatNextDraw() {
    if (_nextDraw == null) return '—';
    return DateFormat('MMM d, h:mm a').format(_nextDraw!);
  }

  String _formatLiveUpdatedAt(String? updatedAt) {
    if (updatedAt == null || updatedAt.isEmpty) {
      return 'Just now';
    }
    final parsed = DateTime.tryParse(updatedAt);
    if (parsed == null) {
      return 'Just now';
    }
    return DateFormat('h:mm a').format(parsed.toUtc().add(_manilaOffset));
  }

  String _drawLabelForResult(LiveDrawResult result) {
    final match = _schedule.cast<DrawTimeData?>().firstWhere(
      (item) => item?.id == result.drawTimeId,
      orElse: () => null,
    );
    if (match == null) {
      return result.drawDate;
    }
    return _formatScheduleTime(match);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Live Draw'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _buildVideoArea(),
            const SizedBox(height: 16),
            _buildScheduleInfo(),
            const SizedBox(height: 24),
            _buildScheduleList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PCSO Live Draw',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Watch live lottery draws',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _isLive ? const Color(0xFFFEE2E2) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLive) ...[_PulsingDot(), const SizedBox(width: 6)],
              Text(
                _isLive ? 'LIVE' : 'Next Draw',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _isLive
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF6B7280),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoArea() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Always attempt to render the WebView if controller is ready so users
            // can preview or join the stream even before schedule flags _isLive.
            if (_webViewController != null)
              Positioned.fill(
                child: WebViewWidget(controller: _webViewController!),
              )
            else
              Positioned.fill(child: _buildPlaceholder()),

            // When not live, show a translucent overlay with the placeholder UI
            if (!_isLive)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.45),
                  child: Center(child: _buildPlaceholder()),
                ),
              ),

            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _isLive
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF111827).withOpacity(0.82),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _isLive ? 'LIVE NOW' : 'STANDBY',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF111827), Color(0xFF1F2937), Color(0xFF374151)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AnimatedPlayButton(),
            const SizedBox(height: 16),
            Text(
              _isLive ? 'Streaming now' : 'Please stay tuned',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isLive
                  ? 'Live draw is currently streaming'
                  : 'The next live draw will start shortly',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLive
                      ? 'Current draw (Philippines)'
                      : 'Next draw (Philippines)',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatNextDraw(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _isLive ? 'Status' : 'Starts in',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                _isLive ? '🔴 Live now' : _timeLeft,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: _isLive ? const Color(0xFFDC2626) : AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleList() {
    // Format schedule times for display
    final formattedTimes = _schedule.map((s) {
      final time = s.extractTime();
      final hour = time['hour'] ?? 0;
      final minute = time['minute'] ?? 0;
      final displayHour = hour % 12 == 0 ? 12 : hour % 12;
      final ampm = hour >= 12 ? 'PM' : 'AM';
      final minStr = minute.toString().padLeft(2, '0');
      return '$displayHour:$minStr $ampm';
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daily Draw Schedule',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 10),
        if (_schedule.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Loading schedule...',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          )
        else
          ...formattedTimes.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: entry.key == _liveScheduleIndex
                          ? const Color(0xFFDC2626)
                          : entry.key == _nextScheduleIndex
                          ? AppColors.primary
                          : const Color(0xFFD1D5DB),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 14,
                      color: entry.key == _liveScheduleIndex
                          ? const Color(0xFF111827)
                          : const Color(0xFF4B5563),
                      fontWeight: entry.key == _liveScheduleIndex
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: entry.key == _liveScheduleIndex
                          ? const Color(0xFFFEE2E2)
                          : entry.key == _nextScheduleIndex
                          ? const Color(0xFFDBEAFE)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      entry.key == _liveScheduleIndex
                          ? 'LIVE'
                          : entry.key == _nextScheduleIndex
                          ? 'NEXT'
                          : 'SCHEDULED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: entry.key == _liveScheduleIndex
                            ? const Color(0xFFDC2626)
                            : entry.key == _nextScheduleIndex
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        _buildLatestResults(),
      ],
    );
  }

  Widget _buildLatestResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Latest Draw Results',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 10),
        if (_isLoadingResults)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Loading latest results...',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          )
        else if (_resultsError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Unable to load draw results right now.',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          )
        else if (_latestResults.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No draw results posted yet for today.',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          )
        else
          ..._latestResults.take(5).map((result) {
            final resultValue = result.result.isEmpty
                ? '-'
                : result.result.join('-');
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _drawLabelForResult(result),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Updated ${_formatLiveUpdatedAt(result.updatedAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    resultValue,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

// Pulsing red dot for LIVE badge
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.7,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFFDC2626),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// Animated play button for the placeholder
class _AnimatedPlayButton extends StatefulWidget {
  @override
  State<_AnimatedPlayButton> createState() => _AnimatedPlayButtonState();
}

class _AnimatedPlayButtonState extends State<_AnimatedPlayButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          size: 40,
          color: Colors.white,
        ),
      ),
    );
  }
}
