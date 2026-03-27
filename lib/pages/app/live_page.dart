import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/design_system.dart';
import '../../core/services/draw_time_service.dart';

class LivePage extends StatefulWidget {
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  static const _preWindow = Duration(minutes: 10);
  static const _postWindow = Duration(hours: 1);

  // Draw schedule fetched from API
  List<Map<String, int>> _schedule = [];

  DateTime? _nextDraw;
  String _timeLeft = '';
  bool _isLive = false;
  Timer? _timer;
  WebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadSchedule() async {
    try {
      final drawTimes = await DrawTimeService.fetchDrawTimes();
      final schedule = <Map<String, int>>[];

      for (final drawTime in drawTimes) {
        final timeMap = drawTime.extractTime();
        schedule.add(timeMap);
      }

      if (mounted) {
        setState(() {
          _schedule = schedule;
        });
        // Trigger initial tick with updated schedule
        _tick();
      }
    } catch (e) {
      debugPrint('Error loading schedule: $e');
      // Fall back to empty schedule or default values
    }
  }

  void _tick() {
    if (_schedule.isEmpty) return;

    final now = DateTime.now().toUtc();
    final nowMs = now.millisecondsSinceEpoch;

    DateTime? found;

    // First: find any draw currently within the live window
    outer:
    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      for (final s in _schedule) {
        final target = DateTime.utc(
          now.year,
          now.month,
          now.day + dayOffset,
          s['hour']! - 8, // convert UTC+8 → UTC
          s['minute']!,
        );
        final diff = target.millisecondsSinceEpoch - nowMs;
        if (diff <= _preWindow.inMilliseconds &&
            diff >= -_postWindow.inMilliseconds) {
          found = target;
          break outer;
        }
      }
    }

    // If not within live window, find next upcoming draw
    if (found == null) {
      outer:
      for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
        for (final s in _schedule) {
          final target = DateTime.utc(
            now.year,
            now.month,
            now.day + dayOffset,
            s['hour']! - 8,
            s['minute']!,
          );
          if (target.millisecondsSinceEpoch > nowMs) {
            found = target;
            break outer;
          }
        }
      }
    }

    if (!mounted) return;

    final diff = found != null ? found.millisecondsSinceEpoch - nowMs : null;
    final isLive =
        diff != null &&
        diff <= _preWindow.inMilliseconds &&
        diff >= -_postWindow.inMilliseconds;

    String timeLeft = '';
    if (!isLive && diff != null) {
      final total = Duration(
        milliseconds: diff.clamp(0, double.maxFinite.toInt()),
      );
      final days = total.inDays;
      final hours = total.inHours % 24;
      final mins = total.inMinutes % 60;
      final secs = total.inSeconds % 60;
      final parts = <String>[];
      if (days > 0) parts.add('${days}d');
      if (hours > 0) parts.add('${hours}h');
      parts.add('${mins.toString().padLeft(2, '0')}m');
      parts.add('${secs.toString().padLeft(2, '0')}s');
      timeLeft = parts.join(' ');
    } else if (isLive) {
      timeLeft = 'Live';
    }

    setState(() {
      _nextDraw = found;
      _isLive = isLive;
      _timeLeft = timeLeft;
    });

    // Initialize or clear webview based on live status
    if (isLive && _webViewController == null) {
      _initWebView();
    } else if (!isLive && _webViewController != null) {
      setState(() {
        _webViewController = null;
      });
    }
  }

  void _initWebView() {
    const channelId = 'UCpOm2kv1upnIFoOT7rSp6hg';
    const htmlContent =
        '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="referrer" content="origin">
  <style>
    * { margin: 0; padding: 0; }
    body { width: 100%; height: 100vh; background: #000; }
    iframe { width: 100%; height: 100%; }
  </style>
</head>
<body>
  <iframe 
    src="https://www.youtube.com/embed/live_stream?channel=$channelId&autoplay=1&mute=1"
    frameborder="0"
    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
    allowfullscreen>
  </iframe>
</body>
</html>
    ''';

    final controller = WebViewController();
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadHtmlString(htmlContent, baseUrl: 'https://www.onstite.app/');

    setState(() {
      _webViewController = controller;
    });
  }

  String _formatNextDraw() {
    if (_nextDraw == null) return '—';
    // Display in Asia/Manila (UTC+8); convert manually: UTC+8 = UTC + 8h
    final pst = _nextDraw!.add(const Duration(hours: 8));
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = pst.hour % 12 == 0 ? 12 : pst.hour % 12;
    final ampm = pst.hour >= 12 ? 'PM' : 'AM';
    final mins = pst.minute.toString().padLeft(2, '0');
    return '${months[pst.month - 1]} ${pst.day}, $hour:$mins $ampm';
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
        child: _isLive && _webViewController != null
            ? WebViewWidget(controller: _webViewController!)
            : _buildPlaceholder(),
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
                  : 'Live draw will start shortly',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.7),
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
            color: Colors.black.withOpacity(0.04),
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
                  'Next scheduled draw (PST)',
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
                'Starts in',
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
      final hour = s['hour']!;
      final minute = s['minute']!;
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
          ...formattedTimes.map(
            (time) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Philippine Standard Time',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
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
          color: Colors.white.withOpacity(0.12),
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
