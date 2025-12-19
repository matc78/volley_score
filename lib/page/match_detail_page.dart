// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MatchDetailPage extends StatelessWidget {
  static const mikasaBlue = Color(0xFF0033A0);
  static const mikasaYellow = Color(0xFFF5F12D);

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: mikasaBlue,
        title: Text(
          "VS ${opponentName.toUpperCase()}",
          style: const TextStyle(
            color: mikasaBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset("assets/volley_bg2.png", fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.15)),
          ),
          Positioned.fill(
            child: FutureBuilder<_MatchSummary>(
              future: _loadSummary(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  if (snap.hasError) {
                    return Center(
                      child: Text(
                        "Erreur: ${snap.error}",
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                }

                final summary = snap.data!;

                return SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _headerScore(summary),
                        const SizedBox(height: 12),

                        // MEILLEURS JOUEURS
                        _sectionCard(
                          title: "Meilleurs joueurs",
                          children: summary.bestPlayers.isEmpty
                              ? [
                                  const Text(
                                    "Aucun",
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ]
                              : summary.bestPlayers.map((e) {
                                  return Text(
                                    "${e.name} : ${e.value} pts",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                }).toList(),
                        ),

                        const SizedBox(height: 10),

                        // JOUEURS LES PLUS PENALISÉS
                        _sectionCard(
                          title: "Joueurs les plus pénalisés",
                          children: summary.worstPlayers.isEmpty
                              ? [
                                  const Text(
                                    "Aucun",
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ]
                              : summary.worstPlayers.map((e) {
                                  return Text(
                                    "${_shortName(e.name)} : ${e.value} pts donnés",
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                }).toList(),
                        ),

                        const SizedBox(height: 10),

                        // ACTIONS COLLECTIVES EQUIPE
                        if (summary.teamActionsNoPlayer.isNotEmpty)
                          _sectionCard(
                            title: "Actions équipe (collectif)",
                            children: summary.teamActionsNoPlayer.entries.map((
                              e,
                            ) {
                              final pct = summary.totalFor > 0
                                  ? ((e.value / summary.totalFor) * 100)
                                        .toStringAsFixed(1)
                                  : "0";
                              return Text(
                                "${e.key} : ${e.value} pts ($pct%)",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }).toList(),
                          ),

                        const SizedBox(height: 10),

                        // DETAILS PAR ACTION (TOP JOUEURS)
                        if (summary.topByAction.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: summary.topByAction.entries.map((entry) {
                              final action = entry.key;
                              final tops = entry.value;

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: mikasaBlue.withOpacity(0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      action,
                                      style: const TextStyle(
                                        color: mikasaBlue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    ...tops.map(
                                      (e) => Text(
                                        "${_shortName(e.name)} : ${e.value} pts",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),

                        const SizedBox(height: 10),

                        // DETAIL DES SETS
                        const Text(
                          "Détail par set",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),

                        ...summary.sets.map(
                          (s) => _SetExpansion(
                            matchId: matchId,
                            setNumber: s.setNumber,
                            ourScore: s.our,
                            oppScore: s.opp,
                            teamId: teamId,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- HEADER SCORE ----------------

  Widget _headerScore(_MatchSummary summary) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: mikasaBlue.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text(
            "${teamName.toUpperCase()}  ${summary.setsUs} - ${summary.setsOpp}  ${opponentName.toUpperCase()}",
            style: const TextStyle(
              color: mikasaBlue,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            "Scores sets : ${summary.setScoresText}",
            style: const TextStyle(color: Colors.black87),
          ),
        ],
      ),
    );
  }

  // ---------------- SECTION CARD ----------------

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: mikasaBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: mikasaBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  // ---------------- LOAD SUMMARY CLEAN ----------------

  Future<_MatchSummary> _loadSummary() async {
    final matchDoc = await FirebaseFirestore.instance
        .collection("matches")
        .doc(matchId)
        .get();
    final matchData = matchDoc.data() ?? {};

    // LOAD SETS
    final setsSnap = await FirebaseFirestore.instance
        .collection("matches")
        .doc(matchId)
        .collection("sets")
        .orderBy("setNumber")
        .get();

    final setEntries = setsSnap.docs.map((d) {
      return _SetScore(
        setNumber: d["setNumber"] ?? 0,
        our: d["ourScore"] ?? 0,
        opp: d["oppScore"] ?? 0,
        winnerIsUs: d["winnerIsUs"] == true,
      );
    }).toList();

    final setsUs = setEntries.where((s) => s.winnerIsUs).length;
    final setsOpp = setEntries.length - setsUs;

    // LOAD EVENTS
    final events = await FirebaseFirestore.instance
        .collection("matches")
        .doc(matchId)
        .collection("events")
        .get();

    // LOAD PLAYERS
    final playersSnap = await FirebaseFirestore.instance
        .collection("teams")
        .doc(teamId)
        .collection("players")
        .get();

    final playerNames = {
      for (var p in playersSnap.docs)
        p.id:
            "${(p["lastName"] ?? '').toString().toUpperCase()} ${p["firstName"] ?? ''}"
                .trim(),
    };

    int totalFor = 0;
    int totalAgainst = 0;

    final best = <String, int>{};
    final worst = <String, int>{};

    final byAction = <String, Map<String, int>>{};
    final teamNoPlayer = <String, int>{};

    final topOppByAction = <String, Map<String, int>>{};
    final oppNoPlayer = <String, int>{};

    for (final evt in events.docs) {
      final data = evt.data();
      final bool isUs = data["isOurPoint"] == true;
      final bool isErr = data["isOurError"] == true;
      final String action = (data["actionType"] ?? "").toString();
      final scorer = data["scorerId"];
      final err = data["errorPlayerId"];

      if (isUs) {
        totalFor++;

        if (scorer == null) {
          teamNoPlayer[action] = (teamNoPlayer[action] ?? 0) + 1;
        } else {
          best[scorer] = (best[scorer] ?? 0) + 1;
          byAction.putIfAbsent(action, () => {});
          byAction[action]![scorer] = (byAction[action]![scorer] ?? 0) + 1;
        }
      } else {
        totalAgainst++;

        if (err == null) {
          oppNoPlayer[action] = (oppNoPlayer[action] ?? 0) + 1;
        } else {
          worst[err] = (worst[err] ?? 0) + 1;
          topOppByAction.putIfAbsent(action, () => {});
          topOppByAction[action]![err] =
              (topOppByAction[action]![err] ?? 0) + 1;
        }
      }
    }

    final bestPlayers =
        best.entries
            .map((e) => _Entry(playerNames[e.key] ?? e.key, e.value))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final worstPlayers =
        worst.entries
            .map((e) => _Entry(playerNames[e.key] ?? e.key, e.value))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final topByAction = {
      for (var entry in byAction.entries)
        entry.key:
            entry.value.entries
                .map((e) => _Entry(playerNames[e.key] ?? e.key, e.value))
                .toList()
              ..sort((a, b) => b.value.compareTo(a.value)),
    };

    final topByActionOpp = {
      for (var entry in topOppByAction.entries)
        entry.key:
            entry.value.entries
                .map((e) => _Entry(playerNames[e.key] ?? e.key, e.value))
                .toList()
              ..sort((a, b) => b.value.compareTo(a.value)),
    };

    return _MatchSummary(
      setsUs: setsUs,
      setsOpp: setsOpp,
      totalFor: totalFor,
      totalAgainst: totalAgainst,
      setScoresText: setEntries.map((s) => "${s.our}-${s.opp}").join(" / "),
      sets: setEntries,
      bestPlayers: bestPlayers.take(3).toList(),
      worstPlayers: worstPlayers.take(3).toList(),
      topByAction: topByAction,
      topByActionOpp: topByActionOpp,
      teamActionsNoPlayer: teamNoPlayer,
      oppActionsNoPlayer: oppNoPlayer,
    );
  }
}

class _SetExpansion extends StatelessWidget {
  final String matchId;
  final int setNumber;
  final int ourScore;
  final int oppScore;
  final String teamId;

  const _SetExpansion({
    required this.matchId,
    required this.setNumber,
    required this.ourScore,
    required this.oppScore,
    required this.teamId,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: Text("Set $setNumber : $ourScore - $oppScore"),
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("matches")
                .doc(matchId)
                .collection("events")
                .where("setNumber", isEqualTo: setNumber)
                .orderBy("createdAt")
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                );
              }

              final evts = snap.data!.docs;

              if (evts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text("Aucun événement"),
                );
              }

              return FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection("teams")
                    .doc(teamId)
                    .collection("players")
                    .get(),
                builder: (context, playersSnap) {
                  if (!playersSnap.hasData) return Container();

                  final players = {
                    for (var p in playersSnap.data!.docs)
                      p.id:
                          "${(p["lastName"] ?? '').toString().toUpperCase()} ${p["firstName"] ?? ''}",
                  };

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: evts.length,
                    itemBuilder: (context, idx) {
                      final data = evts[idx].data() as Map<String, dynamic>;
                      final bool isUs = data["isOurPoint"] == true;
                      final action = (data["actionType"] ?? "").toString();

                      final scorerId = data["scorerId"];
                      final errId = data["errorPlayerId"];

                      String who = "Collectif";

                      if (scorerId != null) {
                        who = players[scorerId] ?? scorerId;
                      } else if (errId != null) {
                        who = players[errId] ?? errId;
                      }

                      return ListTile(
                        leading: Icon(
                          isUs ? Icons.arrow_upward : Icons.arrow_downward,
                          color: isUs ? Colors.blue : Colors.red,
                        ),
                        title: Text(action.isNotEmpty ? action : "Événement"),
                        subtitle: Text(who),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

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
  final Map<String, List<_Entry>> topByAction;
  final Map<String, List<_Entry>> topByActionOpp;
  final Map<String, int> teamActionsNoPlayer;
  final Map<String, int> oppActionsNoPlayer;

  _MatchSummary({
    required this.setsUs,
    required this.setsOpp,
    required this.totalFor,
    required this.totalAgainst,
    required this.setScoresText,
    required this.sets,
    required this.bestPlayers,
    required this.worstPlayers,
    required this.topByAction,
    required this.topByActionOpp,
    required this.teamActionsNoPlayer,
    required this.oppActionsNoPlayer,
  });
}

String _shortName(String full) {
  final parts = full.trim().split(" ");
  if (parts.length <= 1) return full;
  return "${parts[0][0].toUpperCase()}. ${parts.sublist(1).join(" ")}";
}
