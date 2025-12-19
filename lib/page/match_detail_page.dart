import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class MatchDetailPage extends StatefulWidget {
  final String teamId;
  final String teamName;
  final String opponentName;
  final String matchId;

  const MatchDetailPage({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.opponentName,
    required this.matchId,
  });

  @override
  State<MatchDetailPage> createState() => _MatchDetailPageState();
}

class _MatchDetailPageState extends State<MatchDetailPage>
    with SingleTickerProviderStateMixin {
  static const mikasaBlue = Color(0xFF0033A0);

  late Future<_MatchSummary> _future;
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _future = _loadSummary();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset("assets/volley_bg2.png", fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.15)),
          ),
          SafeArea(
            child: Column(
              children: [
                _topBar(context),
                Expanded(
                  child: FutureBuilder<_MatchSummary>(
                    future: _future,
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        if (snap.hasError) {
                          return Center(
                            child: Text(
                              "Erreur : ${snap.error}",
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        }
                        return const Center(child: CircularProgressIndicator());
                      }

                      final s = snap.data!;
                      return FadeTransition(
                        opacity: _anim,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _headerScore(s),
                              const SizedBox(height: 16),

                              _buildCard(
                                title: "Totaux",
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _pill(
                                      "${widget.teamName} : ${s.totalFor}",
                                      mikasaBlue,
                                    ),
                                    _pill(
                                      "${widget.opponentName} : ${s.totalAgainst}",
                                      Colors.red,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),
                              _buildBarChart(s),

                              const SizedBox(height: 16),
                              _buildCard(
                                title: "Meilleurs marqueurs",
                                child: _listPlayers(
                                  s.bestPlayers,
                                  suffix: "pts",
                                ),
                              ),

                              const SizedBox(height: 16),
                              _buildCard(
                                title: "Joueurs les plus pénalisés",
                                titleColor: Colors.red,
                                child: _listPlayers(
                                  s.worstPlayers,
                                  suffix: "pts donnés",
                                ),
                              ),

                              if (s.teamActionsNoPlayer.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                _buildCard(
                                  title:
                                      "Actions gagnées (collectif / sans joueur)",
                                  child: _listActions(s.teamActionsNoPlayer),
                                ),
                              ],

                              if (s.topByAction.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                _buildTopActionsGrid(
                                  s.topByAction,
                                  s.totalFor,
                                  mikasaBlue,
                                ),
                              ],

                              if (s.topByActionOpp.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                _buildTopActionsGrid(
                                  s.topByActionOpp,
                                  s.totalAgainst,
                                  Colors.red,
                                ),
                              ],

                              if (s.oppActionsNoPlayer.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                _buildCard(
                                  title:
                                      "Actions concédées (collectif / sans joueur)",
                                  titleColor: Colors.red,
                                  child: _listActions(s.oppActionsNoPlayer),
                                ),
                              ],

                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: mikasaBlue),
          ),
          const Spacer(),
          Text(
            "VS ${widget.opponentName.toUpperCase()}",
            style: const TextStyle(
              color: mikasaBlue,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _headerScore(_MatchSummary s) {
    return _buildCard(
      title:
          "${widget.teamName.toUpperCase()} ${s.setsUs} - ${s.setsOpp} ${widget.opponentName.toUpperCase()}",
      child: Text(
        "Scores sets : ${s.setScoresText}",
        style: const TextStyle(color: Colors.black54),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required Widget child,
    Color titleColor = mikasaBlue,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 4),
            color: Colors.black12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _listPlayers(List<_Entry> list, {required String suffix}) {
    if (list.isEmpty) {
      return const Text("Aucun", style: TextStyle(color: Colors.black54));
    }
    return Column(
      children: list
          .map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(e.name)),
                  Text(
                    "${e.value} $suffix",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _listActions(Map<String, int> map) {
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries
          .map(
            (e) => Chip(
              label: Text("${e.key} : ${e.value}"),
              backgroundColor: Colors.grey.shade200,
            ),
          )
          .toList(),
    );
  }

  Widget _buildTopActionsGrid(
    Map<String, List<_Entry>> map,
    int total,
    Color color,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: map.entries.map((entry) {
        return Container(
          width: 180,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.key,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              ...entry.value.map((e) => Text("${e.name} : ${e.value}")),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBarChart(_MatchSummary s) {
    if (s.bestPlayers.isEmpty) {
      return _buildCard(
        title: "Graphique des marqueurs",
        child: const Text("Pas de données"),
      );
    }

    final bars = s.bestPlayers.asMap().entries.map((entry) {
      final idx = entry.key;
      final e = entry.value;
      return BarChartGroupData(
        x: idx,
        barRods: [
          BarChartRodData(
            toY: e.value.toDouble(),
            color: mikasaBlue,
            width: 18,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();

    return _buildCard(
      title: "Graphique des marqueurs",
      child: SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            barGroups: bars,
            gridData: const FlGridData(show: true),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 28),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= s.bestPlayers.length) {
                      return const SizedBox.shrink();
                    }
                    final label = _extractNumberLabel(s.bestPlayers[idx].name);
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _extractNumberLabel(String fullName) {
    final match = RegExp(r"N°\s*([0-9]+)").firstMatch(fullName);
    if (match != null) return match.group(1)!;
    return fullName;
  }

  // ---------------------------------------------------------------------------
  // DATA
  // ---------------------------------------------------------------------------

  Future<_MatchSummary> _loadSummary() async {
    final setsSnap = await FirebaseFirestore.instance
        .collection("matches")
        .doc(widget.matchId)
        .collection("sets")
        .orderBy("setNumber")
        .get();

    final sets = setsSnap.docs
        .map(
          (d) => _SetScore(
            setNumber: d["setNumber"],
            our: d["ourScore"],
            opp: d["oppScore"],
            winnerIsUs: d["winnerIsUs"] == true,
          ),
        )
        .toList();

    final totalFor = sets.fold<int>(0, (p, s) => p + s.our);
    final totalAgainst = sets.fold<int>(0, (p, s) => p + s.opp);

    final playersSnap = await FirebaseFirestore.instance
        .collection("teams")
        .doc(widget.teamId)
        .collection("players")
        .get();

    final playerNames = {
      for (final p in playersSnap.docs)
        p.id:
            "N°${p["number"] ?? ""} ${(p["lastName"] ?? "").toString().toUpperCase()} ${(p["firstName"] ?? "")}",
    };

    final eventsSnap = await FirebaseFirestore.instance
        .collection("matches")
        .doc(widget.matchId)
        .collection("events")
        .get();

    final Map<String, int> best = {};
    final Map<String, int> worst = {};
    final Map<String, int> teamNo = {};
    final Map<String, int> oppNo = {};
    final Map<String, Map<String, int>> byAction = {};
    final Map<String, Map<String, int>> byActionOpp = {};

    for (final d in eventsSnap.docs) {
      final data = d.data();
      if (!data.containsKey("isOurPoint")) continue;

      final isUs = data["isOurPoint"] == true;
      final action = (data["actionType"] ?? "Collectif").toString();
      final scorer = (data["scorerId"] ?? "").toString();
      final err = (data["errorPlayerId"] ?? "").toString();
      final isErr = data["isOurError"] == true;

      if (isUs) {
        if (scorer.isNotEmpty) {
          best[scorer] = (best[scorer] ?? 0) + 1;
          byAction.putIfAbsent(action, () => {});
          byAction[action]![scorer] = (byAction[action]![scorer] ?? 0) + 1;
        } else {
          teamNo[action] = (teamNo[action] ?? 0) + 1;
        }
      } else {
        if (isErr && err.isNotEmpty) {
          worst[err] = (worst[err] ?? 0) + 1;
          byActionOpp.putIfAbsent(action, () => {});
          byActionOpp[action]![err] = (byActionOpp[action]![err] ?? 0) + 1;
        } else {
          oppNo[action] = (oppNo[action] ?? 0) + 1;
        }
      }
    }

    Map<String, List<_Entry>> mapToEntries(Map<String, Map<String, int>> src) {
      return src.map(
        (k, v) => MapEntry(
          k,
          v.entries
              .map((e) => _Entry(playerNames[e.key] ?? e.key, e.value))
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value)),
        ),
      );
    }

    return _MatchSummary(
      setsUs: sets.where((s) => s.winnerIsUs).length,
      setsOpp: sets.where((s) => !s.winnerIsUs).length,
      totalFor: totalFor,
      totalAgainst: totalAgainst,
      setScoresText: sets.map((s) => "${s.our}-${s.opp}").join(" / "),
      sets: sets,
      bestPlayers:
          best.entries
              .map((e) => _Entry(playerNames[e.key] ?? e.key, e.value))
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value)),
      worstPlayers:
          worst.entries
              .map((e) => _Entry(playerNames[e.key] ?? e.key, e.value))
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value)),
      teamActionsNoPlayer: teamNo,
      oppActionsNoPlayer: oppNo,
      topByAction: mapToEntries(byAction),
      topByActionOpp: mapToEntries(byActionOpp),
      playerNames: playerNames,
      playerPhotos: const {},
    );
  }
}

// ---------------------------------------------------------------------------
// MODELS
// ---------------------------------------------------------------------------

class _SetScore {
  final int setNumber;
  final int our;
  final int opp;
  final bool winnerIsUs;

  _SetScore({
    required this.setNumber,
    required this.our,
    required this.opp,
    required this.winnerIsUs,
  });
}

class _Entry {
  final String name;
  final int value;
  _Entry(this.name, this.value);
}

class _MatchSummary {
  final int setsUs;
  final int setsOpp;
  final int totalFor;
  final int totalAgainst;
  final String setScoresText;
  final List<_SetScore> sets;

  final List<_Entry> bestPlayers;
  final List<_Entry> worstPlayers;

  final Map<String, int> teamActionsNoPlayer;
  final Map<String, int> oppActionsNoPlayer;

  final Map<String, List<_Entry>> topByAction;
  final Map<String, List<_Entry>> topByActionOpp;

  final Map<String, String> playerNames;
  final Map<String, String> playerPhotos;

  _MatchSummary({
    required this.setsUs,
    required this.setsOpp,
    required this.totalFor,
    required this.totalAgainst,
    required this.setScoresText,
    required this.sets,
    required this.bestPlayers,
    required this.worstPlayers,
    required this.teamActionsNoPlayer,
    required this.oppActionsNoPlayer,
    required this.topByAction,
    required this.topByActionOpp,
    required this.playerNames,
    required this.playerPhotos,
  });
}
