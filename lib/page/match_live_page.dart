import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MatchLivePage extends StatefulWidget {
  final String analyzedTeamId;
  final String analyzedTeamName;
  final String homeTeamId;
  final String awayTeamId;
  final List<String> starters;
  final String? liberoId;

  const MatchLivePage({
    super.key,
    required this.analyzedTeamId,
    required this.analyzedTeamName,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.starters,
    this.liberoId,
  });

  @override
  State<MatchLivePage> createState() => _MatchLivePageState();
}

class _MatchLivePageState extends State<MatchLivePage> {
  static const mikasaBlue = Color(0xFF0033A0);
  static const mikasaYellow = Color(0xFFFFD600);
  static const mikasaRed = Color(0xFFC62828);

  int ourScore = 0;
  int oppScore = 0;

  String? matchId;

  // pour annuler dernier point
  String? lastEventId;
  int lastDeltaOur = 0;
  int lastDeltaOpp = 0;

  int minute = 1; // minute du match (timeline)

  bool isSwapped = false;

  @override
  void initState() {
    super.initState();
    _createMatchDocument();
  }

  Future<void> _createMatchDocument() async {
    final doc = await FirebaseFirestore.instance.collection("matches").add({
      "analyzedTeamId": widget.analyzedTeamId,
      "analyzedTeamName": widget.analyzedTeamName,
      "homeTeamId": widget.homeTeamId,
      "awayTeamId": widget.awayTeamId,
      "starters": widget.starters,
      "liberoId": widget.liberoId,
      "ourScore": 0,
      "oppScore": 0,
      "createdAt": DateTime.now(),
      "isFinished": false,
    });

    setState(() {
      matchId = doc.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canInteract = matchId != null;

    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: mikasaYellow,
        title: Text("MATCH EN COURS"),
        actions: [
          IconButton(
            onPressed: () {
              setState(() => isSwapped = !isSwapped);
            },
            icon: const Icon(Icons.swap_horiz, color: mikasaYellow),
            tooltip: "Inverser les équipes",
          ),
          IconButton(
            onPressed: canInteract ? _confirmFinishMatch : null,
            icon: const Icon(Icons.flag, color: mikasaYellow),
          ),
        ],
      ),

      body: Column(
        children: [
          const SizedBox(height: 16),

          const SizedBox(height: 25),

          _buildScoreWithPlusButtons(),

          const SizedBox(height: 20),

          Expanded(child: _buildTimeline()),

          const SizedBox(height: 10),

          _buildUndoButton(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ============================================================
  //                       SCOREBOARD
  // ============================================================

  Widget _buildScoreWithPlusButtons() {
    final leftIsUs = !isSwapped;
    final rightIsUs = isSwapped;

    final leftName = leftIsUs ? widget.analyzedTeamName : "Adversaire";
    final rightName = rightIsUs ? widget.analyzedTeamName : "Adversaire";

    final leftColor = leftIsUs ? mikasaBlue : mikasaRed;
    final rightColor = rightIsUs ? mikasaBlue : mikasaRed;

    final leftScore = leftIsUs ? ourScore : oppScore;
    final rightScore = rightIsUs ? ourScore : oppScore;

    return Column(
      children: [
        // noms des équipes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                leftName.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: leftColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Text(
                rightName.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: rightColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.add_circle, size: 45, color: leftColor),
              onPressed: leftIsUs ? _onOurPoint : _onOpponentPoint,
            ),

            const SizedBox(width: 12),

            _scoreBox(leftScore, leftColor),

            const SizedBox(width: 12),
            const Text(
              "-",
              style: TextStyle(color: Colors.white, fontSize: 40),
            ),
            const SizedBox(width: 12),

            _scoreBox(rightScore, rightColor),

            const SizedBox(width: 12),

            IconButton(
              icon: Icon(Icons.add_circle, size: 45, color: rightColor),
              onPressed: rightIsUs ? _onOurPoint : _onOpponentPoint,
            ),
          ],
        ),
      ],
    );
  }

  Widget _scoreBox(int score, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        "$score",
        style: const TextStyle(
          color: Colors.white,
          fontSize: 42,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ============================================================
  //                         TIMELINE
  // ============================================================

  Widget _buildTimeline() {
    if (matchId == null) return const SizedBox();

    final stream = FirebaseFirestore.instance
        .collection("matches")
        .doc(matchId)
        .collection("events")
        .orderBy("createdAt", descending: false) // timeline dans le bon sens
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final events = snapshot.data!.docs;

        int ourPointNumber = 0;
        int oppPointNumber = 0;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final e = events[index];
            final bool isOurPoint = e["isOurPoint"] == true;
            final scorerId = e["scorerId"];

            // --- Numérotation séparée ---
            final pointNumber = isOurPoint
                ? ++ourPointNumber
                : ++oppPointNumber;

            final bool isLeftSide = isSwapped ? !isOurPoint : isOurPoint;
            final Color arrowColor = isOurPoint ? mikasaBlue : mikasaRed;

            return FutureBuilder<DocumentSnapshot>(
              future: scorerId != null
                  ? FirebaseFirestore.instance
                        .collection("teams")
                        .doc(widget.analyzedTeamId)
                        .collection("players")
                        .doc(scorerId)
                        .get()
                  : null,
              builder: (context, snap) {
                String playerName;

                if (scorerId == null) {
                  playerName = isOurPoint
                      ? widget.analyzedTeamName
                      : "Adversaire";
                } else if (!snap.hasData || !snap.data!.exists) {
                  playerName = "Joueur inconnu";
                } else {
                  final data = snap.data!.data() as Map<String, dynamic>;
                  final last = data["lastName"] ?? "";
                  final first = data["firstName"] ?? "";
                  playerName = "${last.toUpperCase()} $first";
                }

                // --- Construction miroir ---
                Widget row;
                if (isLeftSide) {
                  // ==================== CÔTÉ GAUCHE ====================
                  row = Row(
                    children: [
                      Text(
                        "$pointNumber ",
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Icon(Icons.arrow_upward, color: arrowColor, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          playerName,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  );
                } else {
                  // ==================== CÔTÉ DROITE (MIROIR) ====================
                  row = Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          playerName,
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_downward, color: arrowColor, size: 18),
                      Text(
                        " $pointNumber",
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: row,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildUndoButton() {
    return TextButton.icon(
      onPressed: (matchId != null && lastEventId != null) ? _undoLast : null,
      icon: const Icon(Icons.undo, color: Colors.white70),
      label: const Text(
        "Annuler le dernier point",
        style: TextStyle(color: Colors.white70),
      ),
    );
  }

  // ============================================================
  //                      LOGIQUE DES POINTS
  // ============================================================

  Future<void> _onOurPoint() async {
    setState(() {
      ourScore++;
      lastDeltaOur = 1;
      lastDeltaOpp = 0;
    });

    final playerId = await _choosePlayerPopup(true);

    await _saveEvent(isOurPoint: true, scorerId: playerId, isOurError: false);
  }

  Future<void> _onOpponentPoint() async {
    setState(() {
      oppScore++;
      lastDeltaOur = 0;
      lastDeltaOpp = 1;
    });

    final errorPlayerId = await _choosePlayerPopup(false);

    await _saveEvent(
      isOurPoint: false,
      scorerId: null,
      isOurError: errorPlayerId != null,
      errorPlayerId: errorPlayerId,
    );
  }

  // ============================================================
  //                   SAVE EVENT DB + timeline
  // ============================================================

  Future<void> _saveEvent({
    required bool isOurPoint,
    String? scorerId,
    required bool isOurError,
    String? errorPlayerId,
  }) async {
    if (matchId == null) return;

    final ref = FirebaseFirestore.instance
        .collection("matches")
        .doc(matchId)
        .collection("events");

    final doc = await ref.add({
      "isOurPoint": isOurPoint,
      "scorerId": scorerId,
      "isOurError": isOurError,
      "errorPlayerId": errorPlayerId,
      "ourScoreAfter": ourScore,
      "oppScoreAfter": oppScore,
      "createdAt": DateTime.now(),
    });

    lastEventId = doc.id;

    await FirebaseFirestore.instance.collection("matches").doc(matchId).update({
      "ourScore": ourScore,
      "oppScore": oppScore,
    });
  }

  // ============================================================
  //                          UNDO
  // ============================================================

  Future<void> _undoLast() async {
    if (matchId == null || lastEventId == null) return;

    setState(() {
      ourScore -= lastDeltaOur;
      oppScore -= lastDeltaOpp;

      if (ourScore < 0) ourScore = 0;
      if (oppScore < 0) oppScore = 0;
    });

    await FirebaseFirestore.instance
        .collection("matches")
        .doc(matchId)
        .collection("events")
        .doc(lastEventId)
        .delete();

    await FirebaseFirestore.instance.collection("matches").doc(matchId).update({
      "ourScore": ourScore,
      "oppScore": oppScore,
    });

    lastEventId = null;
    lastDeltaOur = 0;
    lastDeltaOpp = 0;
  }

  // ============================================================
  //                  POPUP SELECTION JOUEUR
  // ============================================================

  Future<String?> _choosePlayerPopup(bool isUs) async {
    final snapshot = await FirebaseFirestore.instance
        .collection("teams")
        .doc(widget.analyzedTeamId)
        .collection("players")
        .get();

    final players = snapshot.docs
        .where(
          (doc) =>
              widget.starters.contains(doc.id) || doc.id == widget.liberoId,
        )
        .toList();

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.70,
          maxChildSize: 0.90,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 10),

                Text(
                  isUs ? "Qui a marqué ?" : "Erreur de qui ?",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text(
                    "Je ne sais pas / collectif",
                    style: TextStyle(color: mikasaYellow),
                  ),
                ),

                const Divider(color: Colors.white24),

                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      final p = players[index];
                      final id = p.id;
                      final first = p["firstName"] ?? "";
                      final last = p["lastName"] ?? "";
                      final number = p["number"]?.toString() ?? "";

                      final isLibero = widget.liberoId == id;

                      return ListTile(
                        onTap: () => Navigator.pop(context, id),
                        leading: CircleAvatar(
                          backgroundColor: isLibero
                              ? Colors.cyanAccent
                              : Colors.white24,
                          child: Text(
                            number.isNotEmpty
                                ? number
                                : (first.isNotEmpty
                                      ? first[0].toUpperCase()
                                      : "?"),
                            style: TextStyle(
                              color: isLibero ? Colors.black : mikasaBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          "${last.toUpperCase()} $first",
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: isLibero
                            ? const Text(
                                "LIBÉRO",
                                style: TextStyle(
                                  color: Colors.cyanAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  //                    FIN DU MATCH
  // ============================================================

  Future<void> _confirmFinishMatch() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Terminer le match ?"),
          content: const Text(
            "Tu pourras consulter les statistiques plus tard.",
          ),
          actions: [
            TextButton(
              child: const Text("Annuler"),
              onPressed: () => Navigator.pop(context, false),
            ),
            TextButton(
              child: const Text("Terminer"),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        );
      },
    );

    if (confirm == true && matchId != null) {
      await FirebaseFirestore.instance
          .collection("matches")
          .doc(matchId)
          .update({"isFinished": true});

      if (mounted) Navigator.pop(context);
    }
  }
}
