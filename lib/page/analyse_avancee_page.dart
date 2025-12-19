import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyseAvanceePage extends StatefulWidget {
  final String matchId;
  final String teamId;
  final String teamName;

  const AnalyseAvanceePage({
    super.key,
    required this.matchId,
    required this.teamId,
    required this.teamName,
  });

  @override
  State<AnalyseAvanceePage> createState() => _AnalyseAvanceePageState();
}

class _AnalyseAvanceePageState extends State<AnalyseAvanceePage>
    with SingleTickerProviderStateMixin {
  static const mikasaBlue = Color(0xFF0033A0);

  late Future<_AdvancedData> _future;
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _future = _loadAdvanced();
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
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: mikasaBlue,
        elevation: 0.6,
        title: Text("Analyse avancée".toUpperCase()),
      ),
      body: FutureBuilder<_AdvancedData>(
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

          final d = snap.data!;
          return FadeTransition(
            opacity: CurvedAnimation(parent: _anim, curve: Curves.easeOut),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _card(
                    title: "KPIs",
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _kpi("Points", d.totalFor.toString(), Colors.blue),
                        _kpi(
                          "Erreurs attribuées",
                          d.totalErrors.toString(),
                          Colors.red,
                        ),
                        _kpi(
                          "Efficacité",
                          d.totalFor + d.totalErrors == 0
                              ? "-"
                              : "${((d.totalFor / (d.totalFor + d.totalErrors)) * 100).toStringAsFixed(1)}%",
                          Colors.green,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  _card(
                    title: "Points par joueur",
                    subtitle: "Top 8",
                    child: _barChart(d.topPoints, color: Colors.blue),
                  ),

                  const SizedBox(height: 16),

                  _card(
                    title: "Erreurs par joueur",
                    subtitle: "Top 8",
                    child: _barChart(d.topErrors, color: Colors.red),
                  ),

                  const SizedBox(height: 16),

                  _card(
                    title: "Répartition des actions (points pour nous)",
                    subtitle: "Basé sur actionType",
                    child: d.actionsFor.isEmpty
                        ? const Text(
                            "Pas d’actions enregistrées.",
                            style: TextStyle(color: Colors.black54),
                          )
                        : _pieChart(d.actionsFor),
                  ),

                  const SizedBox(height: 16),

                  _card(
                    title: "Répartition des actions (points adverses)",
                    subtitle: "Basé sur actionType",
                    child: d.actionsAgainst.isEmpty
                        ? const Text(
                            "Pas d’actions enregistrées.",
                            style: TextStyle(color: Colors.black54),
                          )
                        : _pieChart(d.actionsAgainst),
                  ),

                  const SizedBox(height: 16),

                  _card(
                    title: "Heatmap (zones 1–6)",
                    subtitle:
                        "Si tu stockes un champ zone (1..6) sur tes events.",
                    child: d.zoneCounts.isEmpty
                        ? const Text(
                            "Aucune donnée de zone (ajoute un champ `zone` dans tes events).",
                            style: TextStyle(color: Colors.black54),
                          )
                        : _heatmap(d.zoneCounts),
                  ),

                  const SizedBox(height: 16),

                  _card(
                    title: "Table efficacité joueurs",
                    subtitle: "points / (points + erreurs attribuées)",
                    child: _effTable(d.players),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ======================= UI =======================

  Widget _card({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: mikasaBlue.withOpacity(0.18)),
        boxShadow: const [
          BoxShadow(
            offset: Offset(0, 4),
            blurRadius: 10,
            color: Colors.black12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: mikasaBlue,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _barChart(List<_Entry> entries, {required Color color}) {
    if (entries.isEmpty) {
      return const Text(
        "Pas de données.",
        style: TextStyle(color: Colors.black54),
      );
    }

    final bars = entries.asMap().entries.map((entry) {
      final i = entry.key;
      final v = entry.value.value;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: v.toDouble(),
            color: color,
            width: 18,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      );
    }).toList();

    return SizedBox(
      height: 240,
      child: BarChart(
        BarChartData(
          barGroups: bars,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 28),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= entries.length) return const SizedBox();
                  final name = entries[idx].name;
                  final short = name.length > 10
                      ? "${name.substring(0, 10)}…"
                      : name;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(short, style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pieChart(Map<String, int> map) {
    final total = map.values.fold<int>(0, (p, v) => p + v);
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sections = <PieChartSectionData>[];
    for (int i = 0; i < entries.length; i++) {
      final e = entries[i];
      final pct = total == 0 ? 0.0 : (e.value / total) * 100.0;
      sections.add(
        PieChartSectionData(
          value: e.value.toDouble(),
          title: "${pct.toStringAsFixed(0)}%",
          radius: 60,
          titleStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(sections: sections, centerSpaceRadius: 30),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: entries.take(10).map((e) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: mikasaBlue.withOpacity(0.06),
                border: Border.all(color: mikasaBlue.withOpacity(0.16)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text("${e.key} : ${e.value}"),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _heatmap(Map<int, int> zones) {
    // zones 1..6
    int maxV = 1;
    for (final v in zones.values) {
      if (v > maxV) maxV = v;
    }

    Widget cell(int zone) {
      final v = zones[zone] ?? 0;
      final opacity = (v / maxV).clamp(0.05, 1.0);
      return Expanded(
        child: Container(
          height: 60,
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(opacity),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Center(
            child: Text(
              "Zone $zone\n$v",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(children: [cell(4), cell(3), cell(2)]),
        Row(children: [cell(5), cell(6), cell(1)]),
      ],
    );
  }

  Widget _effTable(List<_PlayerEff> players) {
    if (players.isEmpty) {
      return const Text(
        "Pas de joueurs.",
        style: TextStyle(color: Colors.black54),
      );
    }

    final sorted = [...players]
      ..sort((a, b) => b.efficiency.compareTo(a.efficiency));

    return Column(
      children: sorted.map((p) {
        final pct = (p.efficiency * 100).toStringAsFixed(1);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  p.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                "${p.points} pts",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 10),
              Text(
                "${p.errors} err",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.green.withOpacity(0.25)),
                ),
                child: Text(
                  "$pct%",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ======================= Data load =======================

  Future<_AdvancedData> _loadAdvanced() async {
    // players map
    final playersSnap = await FirebaseFirestore.instance
        .collection("teams")
        .doc(widget.teamId)
        .collection("players")
        .get();

    final Map<String, String> playerNames = {};
    for (final p in playersSnap.docs) {
      final data = p.data();
      final last = (data["lastName"] ?? "").toString().trim();
      final first = (data["firstName"] ?? "").toString().trim();
      final number = (data["number"] ?? "").toString().trim();

      String display;
      if (last.isEmpty && first.isEmpty) {
        display = number.isNotEmpty ? "N°$number" : "Joueur";
      } else {
        display = "${last.toUpperCase()} $first".trim();
        if (number.isNotEmpty) display = "N°$number  $display";
      }
      playerNames[p.id] = display;
    }

    // events
    final eventsSnap = await FirebaseFirestore.instance
        .collection("matches")
        .doc(widget.matchId)
        .collection("events")
        .get();

    final Map<String, int> points = {};
    final Map<String, int> errors = {};
    final Map<String, int> actionsFor = {};
    final Map<String, int> actionsAgainst = {};
    final Map<int, int> zoneCounts = {}; // if zone exists

    int totalFor = 0;
    int totalErrors = 0;

    for (final d in eventsSnap.docs) {
      final data = d.data();
      final isOurPoint = data["isOurPoint"] == true;
      final isOurError = data["isOurError"] == true;

      final action = (data["actionType"] ?? "").toString().trim();
      final zoneRaw = data["zone"]; // optional int 1..6
      if (zoneRaw is int && zoneRaw >= 1 && zoneRaw <= 6) {
        zoneCounts[zoneRaw] = (zoneCounts[zoneRaw] ?? 0) + 1;
      }

      if (isOurPoint) {
        totalFor++;
        if (action.isNotEmpty)
          actionsFor[action] = (actionsFor[action] ?? 0) + 1;

        final scorerId = (data["scorerId"] ?? "").toString().trim();
        if (scorerId.isNotEmpty) {
          points[scorerId] = (points[scorerId] ?? 0) + 1;
        }
      } else {
        if (action.isNotEmpty) {
          actionsAgainst[action] = (actionsAgainst[action] ?? 0) + 1;
        }

        if (isOurError) {
          totalErrors++;
          final errId = (data["errorPlayerId"] ?? "").toString().trim();
          if (errId.isNotEmpty) {
            errors[errId] = (errors[errId] ?? 0) + 1;
          }
        }
      }
    }

    // build player eff list (only those involved)
    final ids = <String>{...points.keys, ...errors.keys};
    final players = ids.map((id) {
      final p = points[id] ?? 0;
      final e = errors[id] ?? 0;
      final denom = (p + e);
      final eff = denom == 0 ? 0.0 : p / denom;
      return _PlayerEff(
        id: id,
        name: playerNames[id] ?? id,
        points: p,
        errors: e,
        efficiency: eff,
      );
    }).toList();

    List<_Entry> topPoints =
        points.entries
            .map((e) => _Entry(playerNames[e.key] ?? e.key, e.value))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    topPoints = topPoints.take(8).toList();

    List<_Entry> topErrors =
        errors.entries
            .map((e) => _Entry(playerNames[e.key] ?? e.key, e.value))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    topErrors = topErrors.take(8).toList();

    return _AdvancedData(
      totalFor: totalFor,
      totalErrors: totalErrors,
      topPoints: topPoints,
      topErrors: topErrors,
      players: players,
      actionsFor: actionsFor,
      actionsAgainst: actionsAgainst,
      zoneCounts: zoneCounts,
    );
  }
}

// ======================= Models =======================

class _Entry {
  final String name;
  final int value;
  _Entry(this.name, this.value);
}

class _PlayerEff {
  final String id;
  final String name;
  final int points;
  final int errors;
  final double efficiency;

  _PlayerEff({
    required this.id,
    required this.name,
    required this.points,
    required this.errors,
    required this.efficiency,
  });
}

class _AdvancedData {
  final int totalFor;
  final int totalErrors;

  final List<_Entry> topPoints;
  final List<_Entry> topErrors;

  final List<_PlayerEff> players;

  final Map<String, int> actionsFor;
  final Map<String, int> actionsAgainst;

  final Map<int, int> zoneCounts;

  _AdvancedData({
    required this.totalFor,
    required this.totalErrors,
    required this.topPoints,
    required this.topErrors,
    required this.players,
    required this.actionsFor,
    required this.actionsAgainst,
    required this.zoneCounts,
  });
}
