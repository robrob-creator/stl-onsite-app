import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/game_service.dart';
import '../../core/services/summary_report_service.dart';
import '../../models/game.dart';
import '../../models/summary_report.dart';

class SummaryReportPage extends StatefulWidget {
  final String date;
  final String makerId;
  const SummaryReportPage({Key? key, required this.date, required this.makerId})
    : super(key: key);

  @override
  State<SummaryReportPage> createState() => _SummaryReportPageState();
}

class _SummaryReportPageState extends State<SummaryReportPage> {
  List<Game> _games = [];
  int _selectedGameIndex = 0;
  bool _loadingGames = true;
  Future<SummaryReportModel>? _futureReport;

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    try {
      final games = await GameService.fetchGames();
      final activeGames = games.where((g) => g.isActive).toList();
      if (!mounted) return;
      setState(() {
        _games = activeGames;
        _loadingGames = false;
        if (activeGames.isNotEmpty) {
          _futureReport = _fetchReport(activeGames[0].id);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingGames = false;
      });
    }
  }

  Future<SummaryReportModel> _fetchReport(String gameId) {
    return SummaryReportService.fetchSummaryReport(
      date: widget.date,
      gameId: gameId,
      makerId: widget.makerId,
    );
  }

  void _onGameTabTapped(int index) {
    if (index == _selectedGameIndex) return;
    setState(() {
      _selectedGameIndex = index;
      _futureReport = _fetchReport(_games[index].id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Summary Report'),
        leading: BackButton(),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(
                DateFormat(
                  'EEE, MMM.dd, yyyy',
                ).format(DateTime.parse(widget.date)),
              ),
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                side: const BorderSide(color: Color(0xFFE0E0E0)),
                foregroundColor: Colors.black,
                backgroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: _loadingGames
          ? const Center(child: CircularProgressIndicator())
          : _games.isEmpty
          ? const Center(child: Text('No active games found.'))
          : Column(
              children: [
                _buildGameTabs(),
                Expanded(child: _buildReportContent()),
              ],
            ),
    );
  }

  Widget _buildGameTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(_games.length, (index) {
          final game = _games[index];
          final isSelected = _selectedGameIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onGameTabTapped(index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  game.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.blue : Colors.black54,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildReportContent() {
    return FutureBuilder<SummaryReportModel>(
      future: _futureReport,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.games.isEmpty) {
          return const Center(child: Text('No data'));
        }
        final game = snapshot.data!.games.first;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          itemCount: game.drawTimes.length,
          itemBuilder: (context, i) {
            final draw = game.drawTimes[i];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDrawTime(draw.drawTime),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryRow('Total Bets', draw.totalBets),
                    _buildSummaryRow('Total Hits', draw.hits),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF232C4D),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Summary',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            _formatNet(draw.net),
                            style: TextStyle(
                              color: draw.net < 0
                                  ? Colors.redAccent
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          Text(
            '₱ ${value.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }

  String _formatDrawTime(String drawTime) {
    // Convert "18:45:00" to "6:45 PM Draw"
    try {
      final time = DateFormat('HH:mm:ss').parse(drawTime);
      return DateFormat('h:mm a').format(time) + ' Draw';
    } catch (_) {
      return drawTime;
    }
  }

  String _formatNet(double net) {
    if (net < 0) {
      return '- ₱ ${net.abs().toStringAsFixed(2)}';
    }
    return '₱ ${net.toStringAsFixed(2)}';
  }
}
