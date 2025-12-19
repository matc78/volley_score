import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MatchSummaryPage extends StatefulWidget {
  final String matchId;
  final String analyzedTeamName;
  final String opponentName;
  final int? setNumber; // null => full match

  const MatchSummaryPage({
    super.key,
    required this.matchId,
    required this.analyzedTeamName,
    required this.opponentName,
    this.setNumber,
  });

  @override
  State<MatchSummaryPage> createState() => _MatchSummaryPageState();
}

class _MatchSummaryPageState extends State<MatchSummaryPage> {
  late Future<_SummaryData> _future;

  static const mikasaBlue = Color(0xFF0033A0);
  static const mikasaYellow = Color(0xFFFFD600);
  static const mikasaRed = Color(0xFFC62828);

  @override
  void initState() {
    super.initState();
    _future = _loadSummary();
  }

  // =======================================================
  //                LOAD SUMMARY + PLAYER NAMES
  // =======================================================

  Future<_SummaryData> _loadSummary() async {
    // Load events ----------------------------------------
    Query eventsQuery = FirebaseFirestore.instance
        .collection("matches")
        .doc(widget.matchId)
        .collection("events");

    if (widget.setNumber != null) {
      eventsQuery = eventsQuery.where("setNumber", isEqualTo: widget.setNumber);
    }

    final snap = await eventsQuery.get();
    final docs = snap.docs;

    // Load players ----------------------------------------
    final playersSnap = await FirebaseFirestore.instance
        .collection("matches")
        .doc(widget.matchId)
        .collection("players")
        .get();

    final allPlayers = {
      for (var p in playersSnap.docs)
        p.id:
            "${(p["lastName"] ?? "").toString().toUpperCase()} ${p["firstName"] ?? ""}"
                .trim(),
    };

    // Stats containers ------------------------------------
    final actionCounts = <String, int>{};
    final pointsForByPlayer = <String, int>{};
    final pointsAgainstByPlayer = <String, int>{};

    int totalFor = 0;
    int totalAgainst = 0;

    for (final d in docs) {
      final data = d.data() as Map<String, dynamic>;

      final bool isOurPoint = data["isOurPoint"] == true;
      final bool isOurError = data["isOurError"] == true;
      final String action = (data["actionType"] ?? "").toString();

      actionCounts[action] = (actionCounts[action] ?? 0) + 1;

      if (isOurPoint) {
        totalFor++;
        final scorer = data["scorerId"];
        if (scorer != null) {
          pointsForByPlayer[scorer] = (pointsForByPlayer[scorer] ?? 0) + 1;
        }
      } else if (isOurError) {
        totalAgainst++;
        final err = data["errorPlayerId"];
        if (err != null) {
          pointsAgainstByPlayer[err] = (pointsAgainstByPlayer[err] ?? 0) + 1;
        }
      }
    }

    return _SummaryData(
      totalFor: totalFor,
      totalAgainst: totalAgainst,
      actionCounts: actionCounts,
      pointsForByPlayer: pointsForByPlayer,
      pointsAgainstByPlayer: pointsAgainstByPlayer,
      playersMap: allPlayers,
    );
  }

  // =======================================================
  //                          UI
  // =======================================================

  @override
  Widget build(BuildContext context) {
    final isSetView = widget.setNumber != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          isSetView ? "RÉCAP SET ${widget.setNumber}" : "RÉCAP MATCH",
          style: const TextStyle(color: mikasaYellow),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: mikasaYellow),
      ),
      body: FutureBuilder<_SummaryData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: mikasaYellow),
            );
          }

          final data = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildScoreCard(data),
                const SizedBox(height: 20),

                _buildActionCard(data),
                const SizedBox(height: 20),

                _buildTopScorersCard(data),
                const SizedBox(height: 20),

                _buildErrorsCard(data),
              ],
            ),
          );
        },
      ),
    );
  }

  // =======================================================
  //                    DESIGN SECTION CARDS
  // =======================================================

  Widget _buildScoreCard(_SummaryData data) {
    return _summaryCard(
      title: "Score",
      content: Column(
        children: [
          Text(
            "${widget.analyzedTeamName} : ${data.totalFor}",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: mikasaBlue,
            ),
          ),
          Text(
            "${widget.opponentName} : ${data.totalAgainst}",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: mikasaRed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(_SummaryData data) {
    return _summaryCard(
      title: "Par type d’action",
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: data.actionCounts.entries
            .map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  "• ${e.key} : ${e.value}",
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTopScorersCard(_SummaryData data) {
    return _summaryCard(
      title: "Meilleurs marqueurs",
      content: _buildPlayerList(
        data.pointsForByPlayer,
        data.totalFor,
        data.playersMap,
        emptyText: "Aucun point marqué",
      ),
    );
  }

  Widget _buildErrorsCard(_SummaryData data) {
    return _summaryCard(
      title: "Points concédés (erreurs)",
      content: _buildPlayerList(
        data.pointsAgainstByPlayer,
        data.totalAgainst,
        data.playersMap,
        emptyText: "Aucune erreur",
      ),
    );
  }

  // =======================================================
  //                  PLAYER LIST + NAME RESOLUTION
  // =======================================================

  Widget _buildPlayerList(
    Map<String, int> map,
    int total,
    Map<String, String> players, {
    required String emptyText,
  }) {
    if (map.isEmpty) {
      return Text(emptyText, style: const TextStyle(color: Colors.white54));
    }

    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: sorted.map((e) {
        final name = players[e.key] ?? "Joueur inconnu";
        final pct = total > 0
            ? ((e.value / total) * 100).toStringAsFixed(1)
            : "0";

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Text(
                "• ",
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                "${e.value} pts  ($pct%)",
                style: const TextStyle(color: mikasaYellow),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // =======================================================
  //                     REUSABLE CARD WIDGET
  // =======================================================

  Widget _summaryCard({required String title, required Widget content}) {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: mikasaYellow,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            content,
          ],
        ),
      ),
    );
  }
}

// =======================================================
//                   SUMMARY DATA MODEL
// =======================================================

class _SummaryData {
  final int totalFor;
  final int totalAgainst;
  final Map<String, int> actionCounts;
  final Map<String, int> pointsForByPlayer;
  final Map<String, int> pointsAgainstByPlayer;
  final Map<String, String> playersMap;

  _SummaryData({
    required this.totalFor,
    required this.totalAgainst,
    required this.actionCounts,
    required this.pointsForByPlayer,
    required this.pointsAgainstByPlayer,
    required this.playersMap,
  });
}
