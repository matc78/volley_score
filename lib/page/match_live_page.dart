import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volley_score/page/match_summary_page.dart';

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

class _MatchLivePageState extends State<MatchLivePage>
    with WidgetsBindingObserver {
  static const mikasaBlue = Color(0xFF0033A0);
  static const mikasaYellow = Color(0xFFFFD600);
  static const mikasaRed = Color(0xFFC62828);

  int ourScore = 0;
  int oppScore = 0;

  String? matchId;
  String opponentName = "Adversaire";
  int setsUs = 0;
  int setsOpp = 0;
  int currentSet = 1;
  bool setEnded = false;
  bool matchFinished = false;
  final ScrollController _timelineController = ScrollController();
  late Set<String> activePlayers;
  String? opponentId;

  // pour annuler le dernier point
  String? lastEventId;
  int lastDeltaOur = 0;
  int lastDeltaOpp = 0;

  bool isSwapped = false; // inversion visuelle des équipes

  @override
  void initState() {
    super.initState();
    activePlayers = widget.starters.toSet();
    WidgetsBinding.instance.addObserver(this);
    _loadOpponentName();
    _restoreSavedState().then((_) {
      if (matchId == null) {
        _createMatchDocument();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timelineController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _persistState();
    }
  }

  Future<void> _loadOpponentName() async {
    if (widget.analyzedTeamId == widget.homeTeamId) {
      opponentId = widget.awayTeamId;
    } else if (widget.analyzedTeamId == widget.awayTeamId) {
      opponentId = widget.homeTeamId;
    }

    if (opponentId == null) return;

    final doc = await FirebaseFirestore.instance
        .collection("teams")
        .doc(opponentId)
        .get();

    if (doc.exists) {
      final name = (doc.data()?["name"] ?? "").toString().trim();
      if (name.isNotEmpty) {
        setState(() => opponentName = name);
      }
    }
  }

  Future<void> _restoreSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMatchId = prefs.getString("currentMatchId");
    final savedAnalyzed = prefs.getString("currentAnalyzedTeamId");
    final savedHome = prefs.getString("currentHomeTeamId");
    final savedAway = prefs.getString("currentAwayTeamId");

    final isSameContext =
        savedAnalyzed == widget.analyzedTeamId &&
        savedHome == widget.homeTeamId &&
        savedAway == widget.awayTeamId;

    if (savedMatchId != null && savedMatchId.isNotEmpty && isSameContext) {
      setState(() {
        matchId = savedMatchId;
        ourScore = prefs.getInt("currentOurScore") ?? 0;
        oppScore = prefs.getInt("currentOppScore") ?? 0;
        isSwapped = prefs.getBool("currentIsSwapped") ?? false;
        opponentName = prefs.getString("currentOpponentName") ?? opponentName;
        setsUs = prefs.getInt("currentSetsUs") ?? 0;
        setsOpp = prefs.getInt("currentSetsOpp") ?? 0;
        currentSet = prefs.getInt("currentSetNumber") ?? 1;
        setEnded = prefs.getBool("currentSetEnded") ?? false;
        matchFinished = prefs.getBool("currentMatchFinished") ?? false;
      });
    }
  }

  Future<void> _persistState() async {
    if (matchId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("currentMatchId", matchId!);
    await prefs.setString("currentAnalyzedTeamId", widget.analyzedTeamId);
    await prefs.setString("currentHomeTeamId", widget.homeTeamId);
    await prefs.setString("currentAwayTeamId", widget.awayTeamId);
    await prefs.setInt("currentOurScore", ourScore);
    await prefs.setInt("currentOppScore", oppScore);
    await prefs.setBool("currentIsSwapped", isSwapped);
    await prefs.setString("currentOpponentName", opponentName);
    await prefs.setInt("currentSetsUs", setsUs);
    await prefs.setInt("currentSetsOpp", setsOpp);
    await prefs.setInt("currentSetNumber", currentSet);
    await prefs.setBool("currentSetEnded", setEnded);
    await prefs.setBool("currentMatchFinished", matchFinished);
  }

  Future<void> _clearSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("currentMatchId");
    await prefs.remove("currentAnalyzedTeamId");
    await prefs.remove("currentHomeTeamId");
    await prefs.remove("currentAwayTeamId");
    await prefs.remove("currentOurScore");
    await prefs.remove("currentOppScore");
    await prefs.remove("currentIsSwapped");
    await prefs.remove("currentOpponentName");
    await prefs.remove("currentSetsUs");
    await prefs.remove("currentSetsOpp");
    await prefs.remove("currentSetNumber");
    await prefs.remove("currentSetEnded");
    await prefs.remove("currentMatchFinished");
  }

  Future<void> _createMatchDocument() async {
    final doc = await FirebaseFirestore.instance.collection("matches").add({
      "analyzedTeamId": widget.analyzedTeamId,
      "analyzedTeamName": widget.analyzedTeamName,
      "homeTeamId": widget.homeTeamId,
      "awayTeamId": widget.awayTeamId,
      "opponentName": opponentName,
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

    await _persistState();
  }

  @override
  Widget build(BuildContext context) {
    final canInteract = matchId != null;

    return WillPopScope(
      onWillPop: _confirmExit,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: mikasaYellow,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: mikasaYellow),
            onPressed: () async {
              final leave = await _confirmExit();
              if (leave && mounted) Navigator.pop(context);
            },
          ),
          title: const Text("MATCH EN COURS"),
          actions: [
            IconButton(
              onPressed: () {
                setState(() => isSwapped = !isSwapped);
                _persistState();
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
            _buildScoreWithPlusButtons(),
            const SizedBox(height: 20),
            Expanded(child: _buildTimeline()),
            if (setEnded)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: mikasaYellow,
                              foregroundColor: Colors.black,
                            ),
                            onPressed:
                                matchFinished ? _finishMatchDirect : _startNextSet,
                            child: Text(
                              matchFinished
                                  ? "Fin du match"
                                  : "Commencer le prochain set",
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (matchFinished)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MatchSummaryPage(
                                      matchId: matchId!,
                                      analyzedTeamName: widget.analyzedTeamName,
                                      opponentName: opponentName,
                                      setNumber: null,
                                    ),
                                  ),
                                );
                              },
                              child: const Text(
                                "Récap match",
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildUndoButton(),
                const SizedBox(width: 12),
                _buildSubstitutionButton(),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ============================================================
  //                       SCOREBOARD
  // ============================================================

  Widget _buildScoreWithPlusButtons() {
    final leftIsUs = !isSwapped;
    final rightIsUs = isSwapped;

    final leftName = leftIsUs ? widget.analyzedTeamName : opponentName;
    final rightName = rightIsUs ? widget.analyzedTeamName : opponentName;

    final leftColor = leftIsUs ? mikasaBlue : mikasaRed;
    final rightColor = rightIsUs ? mikasaBlue : mikasaRed;

    final leftScore = leftIsUs ? ourScore : oppScore;
    final rightScore = rightIsUs ? ourScore : oppScore;
    final leftSets = leftIsUs ? setsUs : setsOpp;
    final rightSets = rightIsUs ? setsUs : setsOpp;

    return Column(
      children: [
        // noms d’équipes au-dessus
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
              onPressed: setEnded
                  ? null
                  : (leftIsUs ? _onOurPoint : _onOpponentPoint),
            ),
            const SizedBox(width: 12),
            _scoreBox(
              leftScore,
              leftColor,
              setCount: leftSets,
              alignSetTopLeft: true,
            ),
            const SizedBox(width: 12),
            const Text(
              "-",
              style: TextStyle(color: Colors.white, fontSize: 40),
            ),
            const SizedBox(width: 12),
            _scoreBox(
              rightScore,
              rightColor,
              setCount: rightSets,
              alignSetTopLeft: false,
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: Icon(Icons.add_circle, size: 45, color: rightColor),
              onPressed: setEnded
                  ? null
                  : (rightIsUs ? _onOurPoint : _onOpponentPoint),
            ),
          ],
        ),
      ],
    );
  }

  Widget _scoreBox(
    int score,
    Color color, {
    required int setCount,
    required bool alignSetTopLeft,
  }) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Stack(
        children: [
          Align(
            alignment: alignSetTopLeft ? Alignment.topLeft : Alignment.topRight,
            child: Text(
              "$setCount",
              style: const TextStyle(
                color: mikasaYellow,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Center(
            child: Text(
              "$score",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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
        .orderBy("createdAt", descending: false)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final events = snapshot.data!.docs;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_timelineController.hasClients) {
            final max = _timelineController.position.maxScrollExtent;
            _timelineController.jumpTo(max);
          }
        });

        final Map<int, int> ourPointBySet = {};
        final Map<int, int> oppPointBySet = {};
        final Map<String, int> pointNumberById = {};

        for (final doc in events) {
          final data = doc.data() as Map<String, dynamic>;
          if (data["isSubstitution"] == true) continue;
          final bool isSetEnd = data["isSetEnd"] == true;
          if (isSetEnd) continue;
          final int setNum = (data["setNumber"] ?? 1) as int;
          final bool isOurPoint = data["isOurPoint"] == true;
          if (isOurPoint) {
            final next = (ourPointBySet[setNum] ?? 0) + 1;
            ourPointBySet[setNum] = next;
            pointNumberById[doc.id] = next;
          } else {
            final next = (oppPointBySet[setNum] ?? 0) + 1;
            oppPointBySet[setNum] = next;
            pointNumberById[doc.id] = next;
          }
        }
        return ListView.builder(
          reverse: true,
          controller: _timelineController,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final e = events[index];
            final data = e.data() as Map<String, dynamic>;
            final bool isSetEnd = data["isSetEnd"] == true;
            if (isSetEnd) {
              final int setNumber = (e["setNumber"] ?? currentSet) as int;
              final bool winnerIsUs = e["winnerIsUs"] == true;
              final int finalOur = (e["ourScoreAfter"] ?? ourScore) as int;
              final int finalOpp = (e["oppScoreAfter"] ?? oppScore) as int;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    const Divider(color: Colors.white24),
                    Text(
                      "Fin du set $setNumber : "
                      "${winnerIsUs ? widget.analyzedTeamName : opponentName} "
                      "($finalOur - $finalOpp)",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MatchSummaryPage(
                              matchId: matchId!,
                              analyzedTeamName: widget.analyzedTeamName,
                              opponentName: opponentName,
                              setNumber: setNumber,
                            ),
                          ),
                        );
                      },
                      child: Text(
                        "Récap set $setNumber",
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    const Divider(color: Colors.white24),
                  ],
                ),
              );
            }

            if (data["isSubstitution"] == true) {
              final inName = (data["inName"] ?? "Entrée") as String;
              final outName = (data["outName"] ?? "Sortie") as String;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: _buildSubstitutionRow(inName, outName),
              );
            }

            final bool isOurPoint = data["isOurPoint"] == true;
            final String actionType =
                (data["actionType"] ?? "") as String; // peut être vide

            // Id du joueur à afficher : marqueur pour nous, "coupable" pour eux
            final String? scorerId = isOurPoint
                ? e["scorerId"] as String?
                : e["errorPlayerId"] as String?;

            final pointNumber = pointNumberById[e.id] ?? 0;

            final bool isLeftSide = isSwapped
                ? !isOurPoint
                : isOurPoint; // miroir
            final Color arrowColor = isOurPoint ? mikasaBlue : mikasaRed;
            final IconData arrowIcon = isOurPoint
                ? Icons.arrow_upward
                : Icons.arrow_downward;

            // Cas sans joueur (ace adverse, attaque adverse, etc.)
            if (scorerId == null || scorerId.isEmpty) {
              final displayName = isOurPoint
                  ? widget.analyzedTeamName
                  : opponentName;
              final avatarText = displayName.isNotEmpty
                  ? displayName[0].toUpperCase()
                  : "?";

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _buildTimelineRow(
                  isLeftSide: isLeftSide,
                  pointNumber: pointNumber,
                  arrowColor: arrowColor,
                  arrowIcon: arrowIcon,
                  displayName: displayName,
                  actionType: actionType,
                  avatarText: avatarText,
                  avatarPhotoUrl: null,
                  isLibero: false,
                  isOurPoint: isOurPoint,
                ),
              );
            }

            // Sinon : on va chercher le joueur
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection("teams")
                  .doc(widget.analyzedTeamId)
                  .collection("players")
                  .doc(scorerId)
                  .get(),
              builder: (context, snap) {
                String displayName = "Joueur inconnu";
                String avatarText = "?";
                String? photoUrl;
                bool isLibero = (widget.liberoId == scorerId);

                if (snap.hasData && snap.data!.exists) {
                  final data = snap.data!.data() as Map<String, dynamic>;
                  final last = (data["lastName"] ?? "") as String;
                  final first = (data["firstName"] ?? "") as String;
                  final number = (data["number"] ?? "").toString();
                  photoUrl = (data["photoUrl"] ?? "") as String;

                  displayName = "${last.toUpperCase()} $first";
                  avatarText = number.isNotEmpty
                      ? number
                      : (first.isNotEmpty ? first[0].toUpperCase() : "?");
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _buildTimelineRow(
                    isLeftSide: isLeftSide,
                    pointNumber: pointNumber,
                    arrowColor: arrowColor,
                    arrowIcon: arrowIcon,
                    displayName: displayName,
                    actionType: actionType,
                    avatarText: avatarText,
                    avatarPhotoUrl: photoUrl,
                    isLibero: isLibero,
                    isOurPoint: isOurPoint,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTimelineRow({
    required bool isLeftSide,
    required int pointNumber,
    required Color arrowColor,
    required IconData arrowIcon,
    required String displayName,
    required String actionType,
    required String avatarText,
    required String? avatarPhotoUrl,
    required bool isLibero,
    required bool isOurPoint,
  }) {
    final bool showPhoto = avatarPhotoUrl != null && avatarPhotoUrl.isNotEmpty;
    final String avatarDisplayText = !isOurPoint
        ? (opponentName.isNotEmpty ? opponentName[0].toUpperCase() : "A")
        : (avatarText.isNotEmpty ? avatarText : "?");
    final Color avatarBgColor = isLibero ? Colors.cyanAccent : Colors.white;
    final Color avatarTextColor = !isOurPoint ? mikasaRed : mikasaBlue;

    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: avatarBgColor,
      backgroundImage: showPhoto ? NetworkImage(avatarPhotoUrl) : null,
      child: showPhoto
          ? null
          : Text(
              avatarDisplayText,
              style: TextStyle(
                color: avatarTextColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
    );

    final List<Widget> infoChildren = [];

    // Pour l'adversaire on affiche d'abord l'action puis le joueur.
    if (!isOurPoint && actionType.isNotEmpty) {
      infoChildren.add(
        Text(
          actionType,
          textAlign: isLeftSide ? TextAlign.left : TextAlign.right,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    infoChildren.add(
      Text(
        displayName,
        textAlign: isLeftSide ? TextAlign.left : TextAlign.right,
        style: isOurPoint
            ? const TextStyle(color: Colors.white)
            : const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );

    if (isOurPoint && actionType.isNotEmpty) {
      infoChildren.add(
        Text(
          actionType,
          textAlign: isLeftSide ? TextAlign.left : TextAlign.right,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      );
    }

    final infoColumn = Column(
      crossAxisAlignment: isLeftSide
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: infoChildren,
    );

    if (isLeftSide) {
      // côté gauche : numéro – flèche – avatar – nom
      return Row(
        children: [
          Text("$pointNumber ", style: const TextStyle(color: Colors.white70)),
          Icon(arrowIcon, color: arrowColor, size: 18),
          const SizedBox(width: 6),
          avatar,
          const SizedBox(width: 8),
          Expanded(child: infoColumn),
        ],
      );
    } else {
      // côté droit : nom – avatar – flèche – numéro
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(child: infoColumn),
          const SizedBox(width: 8),
          avatar,
          const SizedBox(width: 6),
          Icon(arrowIcon, color: arrowColor, size: 18),
          Text(" $pointNumber", style: const TextStyle(color: Colors.white70)),
        ],
      );
    }
  }

  Widget _buildSubstitutionRow(String inName, String outName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: mikasaYellow.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.swap_horiz, color: Colors.white70, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Changement",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "$inName pour $outName",
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
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

  Widget _buildSubstitutionButton() {
    return TextButton.icon(
      onPressed: _showSubstitutionDialog,
      icon: const Icon(Icons.swap_horiz, color: Colors.white70),
      label: const Text(
        "Changement",
        style: TextStyle(color: Colors.white70),
      ),
    );
  }

  Future<void> _showSubstitutionDialog() async {
    final snap = await FirebaseFirestore.instance
        .collection("teams")
        .doc(widget.analyzedTeamId)
        .collection("players")
        .orderBy("lastName")
        .get();

    List<DocumentSnapshot> players = snap.docs;

    List<DocumentSnapshot> activeList() => players
        .where((p) => activePlayers.contains(p.id) && p.id != widget.liberoId)
        .toList();
    List<DocumentSnapshot> benchList() => players
        .where((p) => !activePlayers.contains(p.id) && p.id != widget.liberoId)
        .toList();

    if (activeList().isEmpty || benchList().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucun changement possible.")),
      );
      return;
    }

    String? outId = activeList().isNotEmpty ? activeList().first.id : null;
    String? inId = benchList().isNotEmpty ? benchList().first.id : null;

    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final active = activeList();
            final bench = benchList();

            return AlertDialog(
              backgroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: const [
                  Icon(Icons.swap_horiz, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    "Changement de joueur",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Sort :",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: outId,
                    dropdownColor: Colors.black87,
                    iconEnabledColor: Colors.white,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dropdownDecoration(),
                    items: active
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(_formatPlayer(p)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setModalState(() => outId = v),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Entre :",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: inId,
                    dropdownColor: Colors.black87,
                    iconEnabledColor: Colors.white,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dropdownDecoration(),
                    items: bench
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(_formatPlayer(p)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setModalState(() => inId = v),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        final added = await _quickAddPlayer();
                        if (added != null) {
                          setModalState(() {
                            players = [...players, added];
                            if (inId == null) inId = added.id;
                          });
                        }
                      },
                      icon: const Icon(Icons.add, color: Colors.white70),
                      label: const Text(
                        "Ajouter un joueur",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text("Annuler",
                      style: TextStyle(color: Colors.white70)),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mikasaYellow,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: (outId != null && inId != null)
                      ? () async {
                          setState(() {
                            activePlayers.remove(outId);
                            activePlayers.add(inId!);
                          });
                          final outPlayer =
                              players.firstWhere((p) => p.id == outId);
                          final inPlayer = players.firstWhere((p) => p.id == inId);
                          await _addSubstitutionEvent(
                            outId!,
                            inId!,
                            _formatPlayer(outPlayer),
                            _formatPlayer(inPlayer),
                          );
                          Navigator.pop(context);
                        }
                      : null,
                  child: const Text("Valider"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white10,
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white24),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: mikasaYellow),
        borderRadius: BorderRadius.circular(10),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  String _formatPlayer(DocumentSnapshot p) {
    final number = (p["number"] ?? "").toString();
    final first = (p["firstName"] ?? "").toString();
    final last = (p["lastName"] ?? "").toString();
    final displayNumber = number.isNotEmpty ? "N°$number " : "";
    return "$displayNumber${last.toUpperCase()} $first";
  }

  Future<DocumentSnapshot?> _quickAddPlayer() async {
    final numberCtrl = TextEditingController();
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: const Text(
            "Nouveau joueur",
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: numberCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Numéro",
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              TextField(
                controller: firstCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Prénom",
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              TextField(
                controller: lastCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Nom",
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  const Text("Annuler", style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Ajouter", style: TextStyle(color: mikasaYellow)),
            ),
          ],
        );
      },
    );

    if (result != true) return null;

    final first = firstCtrl.text.trim();
    final last = lastCtrl.text.trim();
    final number = numberCtrl.text.trim();

    if (first.isEmpty && last.isEmpty && number.isEmpty) return null;

    final ref = await FirebaseFirestore.instance
        .collection("teams")
        .doc(widget.analyzedTeamId)
        .collection("players")
        .add({
          "firstName": first,
          "lastName": last.toUpperCase(),
          "number": number,
          "photoUrl": "",
          "createdAt": DateTime.now(),
        });

    return ref.get();
  }

  Future<bool> _confirmExit() async {
    _persistState();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Quitter le match ?"),
          content: const Text(
            "La progression sera conservée pour reprendre plus tard.",
          ),
          actions: [
            TextButton(
              child: const Text("Continuer"),
              onPressed: () => Navigator.pop(context, false),
            ),
            TextButton(
              child: const Text("Quitter"),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        );
      },
    );

    return confirm ?? false;
  }

  // ============================================================
  //                      LOGIQUE DES POINTS
  // ============================================================

  Future<void> _onOurPoint() async {
    if (setEnded) return;
    // 1) type d’action
    final actionType = await _chooseOurActionType();
    if (actionType == null) return;

    // 2) joueur (avec restrictions libéro) sauf action collective/erreur adverse
    String? playerId;
    const noPlayerNeeded = {
      "L'équipe a fait n'imp",
      "Service adverse raté",
      "Faute adverse (mordu/fil)",
    };
    if (!noPlayerNeeded.contains(actionType)) {
      playerId = await _choosePlayerForOurPoint(actionType);
    }

    // 3) enregistrement
    setState(() {
      ourScore++;
      lastDeltaOur = 1;
      lastDeltaOpp = 0;
    });

    await _saveEvent(
      isOurPoint: true,
      actionType: actionType,
      scorerId: playerId,
      isOurError: false,
      errorPlayerId: null,
      setNumber: currentSet,
    );

    await _checkSetEnd();
    await _persistState();
  }

  Future<void> _onOpponentPoint() async {
    if (setEnded) return;
    // 1) type d’action adverse
    final actionType = await _chooseOpponentActionType();
    if (actionType == null) return;

    // types qui demandent un coupable
    const needPlayerTypes = {
      "Réception ratée",
      "Block-out subi",
      "Block raté",
      "Défense ratée",
      "Service raté",
      "Faute (mordu/fil)",
    };
    const collectiveTeamTypes = {
      "L'équipe a fait n'imp",
      "L'équipe adverse a fait n'imp",
    };

    String? errorPlayerId;
    bool isOurError = false;

    if (collectiveTeamTypes.contains(actionType)) {
      // faute collective : pas de joueur, mais on marque comme erreur de l'équipe
      isOurError = true;
      errorPlayerId = null;
    } else if (needPlayerTypes.contains(actionType)) {
      errorPlayerId = await _choosePlayerForOpponentError(actionType);
      isOurError = errorPlayerId != null;
    }

    setState(() {
      oppScore++;
      lastDeltaOur = 0;
      lastDeltaOpp = 1;
    });

    await _saveEvent(
      isOurPoint: false,
      actionType: actionType,
      scorerId: null,
      isOurError: isOurError,
      errorPlayerId: errorPlayerId,
      setNumber: currentSet,
    );

    await _checkSetEnd();
    await _persistState();
  }

  // ============================================================
  //                   SAVE EVENT DB + timeline
  // ============================================================

  Future<void> _saveEvent({
    required bool isOurPoint,
    required String actionType,
    String? scorerId,
    required bool isOurError,
    String? errorPlayerId,
    required int setNumber,
  }) async {
    if (matchId == null) return;

    final ref = FirebaseFirestore.instance
        .collection("matches")
        .doc(matchId)
        .collection("events");

    final doc = await ref.add({
      "isOurPoint": isOurPoint,
      "actionType": actionType,
      "scorerId": scorerId,
      "isOurError": isOurError,
      "errorPlayerId": errorPlayerId,
      "setNumber": setNumber,
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

  Future<void> _addSubstitutionEvent(
    String outId,
    String inId,
    String outName,
    String inName,
  ) async {
    if (matchId == null) return;
    await FirebaseFirestore.instance
        .collection("matches")
        .doc(matchId)
        .collection("events")
        .add({
          "isSubstitution": true,
          "outId": outId,
          "inId": inId,
          "outName": outName,
          "inName": inName,
          "setNumber": currentSet,
          "ourScoreAfter": ourScore,
          "oppScoreAfter": oppScore,
          "createdAt": DateTime.now(),
        });
  }

  Future<void> _addSetEndEvent(bool winnerIsUs) async {
    if (matchId == null) return;
    await FirebaseFirestore.instance
        .collection("matches")
        .doc(matchId)
        .collection("events")
        .add({
          "isSetEnd": true,
          "setNumber": currentSet,
          "winnerIsUs": winnerIsUs,
          "ourScoreAfter": ourScore,
          "oppScoreAfter": oppScore,
          "createdAt": DateTime.now(),
        });
    // stocker un summary simple dans matches/{matchId}/sets/{currentSet}
    await FirebaseFirestore.instance
        .collection("matches")
        .doc(matchId)
        .collection("sets")
        .doc("set_$currentSet")
        .set({
          "setNumber": currentSet,
          "winnerIsUs": winnerIsUs,
          "ourScore": ourScore,
          "oppScore": oppScore,
          "createdAt": DateTime.now(),
        });
  }

  Future<void> _checkSetEnd() async {
    if (setEnded || matchFinished) return;
    final target = currentSet == 5 ? 15 : 25;
    if (ourScore >= target || oppScore >= target) {
      final winnerIsUs = ourScore > oppScore;
      setState(() {
        setEnded = true;
        if (winnerIsUs) {
          setsUs++;
        } else {
          setsOpp++;
        }
        if (setsUs == 3 || setsOpp == 3 || currentSet == 5) {
          matchFinished = true;
        }
      });
      await _addSetEndEvent(winnerIsUs);
      await _persistState();
    }
  }

  Future<void> _startNextSet() async {
    if (matchFinished || currentSet >= 5) return;
    setState(() {
      currentSet++;
      ourScore = 0;
      oppScore = 0;
      setEnded = false;
      lastEventId = null;
      lastDeltaOur = 0;
      lastDeltaOpp = 0;
    });
    await _persistState();
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

    await _persistState();
  }

  // ============================================================
  //                  POPUPS : TYPES D’ACTIONS
  // ============================================================

  Future<String?> _chooseOurActionType() async {
    const types = [
      "Attaque",
      "Block",
      "Block-out",
      "Ace",
      "Relance gagnante",
      "Bidouille",
      "Placée à 10 doigts",
      "L'équipe a fait n'imp",
      "Service adverse raté",
      "Faute adverse (mordu/fil)",
    ];

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                const Text(
                  "Type d’action",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const Divider(color: Colors.white24),
                ...types.map(
                  (t) => ListTile(
                    title: Text(t, style: const TextStyle(color: Colors.white)),
                    onTap: () => Navigator.pop(context, t),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _chooseOpponentActionType() async {
    const types = [
      "Réception ratée",
      "Block-out subi",
      "Block raté",
      "Défense ratée",
      "Ace adverse",
      "Attaque adverse",
      "Bidouille adverse",
      "Placée adverse",
      "Service raté",
      "Faute (mordu/fil)",
      "L'équipe a fait n'imp",
    ];

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                const Text(
                  "Type de point adverse",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const Divider(color: Colors.white24),
                ...types.map(
                  (t) => ListTile(
                    title: Text(t, style: const TextStyle(color: Colors.white)),
                    onTap: () => Navigator.pop(context, t),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  //                  POPUPS : CHOIX JOUEUR
  // ============================================================

  Future<String?> _choosePlayerForOurPoint(String actionType) async {
    // actions interdites pour le libéro
    const liberoForbidden = {
      "Attaque",
      "Block",
      "Block-out",
      "Ace",
      "Bidouille",
      "Placée à 10 doigts",
    };

    final snapshot = await FirebaseFirestore.instance
        .collection("teams")
        .doc(widget.analyzedTeamId)
        .collection("players")
        .get();

    final players = snapshot.docs
        .where((doc) {
          final id = doc.id;
          final isLibero = widget.liberoId == id;
          if (!isLibero) return true;
          // libéro exclu pour ces types
          return !liberoForbidden.contains(actionType);
        })
        .where((doc) {
          // on ne garde que titulaires + libéro
          return activePlayers.contains(doc.id) || doc.id == widget.liberoId;
        })
        .toList();

    return _showPlayerChooser(
      title: "Qui a marqué ?",
      allowCollective: true,
      players: players,
    );
  }

  Future<String?> _choosePlayerForOpponentError(String actionType) async {
    // pour ces actions, le libéro ne peut pas être fautif
    const liberoForbidden = {"Block-out subi", "Block raté"};

    final snapshot = await FirebaseFirestore.instance
        .collection("teams")
        .doc(widget.analyzedTeamId)
        .collection("players")
        .get();

    final players = snapshot.docs
        .where((doc) {
          final id = doc.id;
          final isLibero = widget.liberoId == id;
          if (!isLibero) return true;
          return !liberoForbidden.contains(actionType);
        })
        .where((doc) {
          return activePlayers.contains(doc.id) || doc.id == widget.liberoId;
        })
        .toList();

    return _showPlayerChooser(
      title: "Erreur de qui ?",
      allowCollective: true,
      players: players,
    );
  }

  Future<String?> _showPlayerChooser({
    required String title,
    required bool allowCollective,
    required List<QueryDocumentSnapshot> players,
  }) async {
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
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (allowCollective)
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
                      final first = (p["firstName"] ?? "") as String;
                      final last = (p["lastName"] ?? "") as String;
                      final number = (p["number"] ?? "").toString();
                      final photoUrl = (p["photoUrl"] ?? "") as String;
                      final isLibero = widget.liberoId == id;

                      final avatar = CircleAvatar(
                        radius: 22,
                        backgroundColor: isLibero
                            ? Colors.cyanAccent
                            : Colors.white24,
                        backgroundImage: photoUrl.isNotEmpty
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl.isEmpty
                            ? Text(
                                number.isNotEmpty
                                    ? number
                                    : (first.isNotEmpty
                                          ? first[0].toUpperCase()
                                          : "?"),
                                style: TextStyle(
                                  color: isLibero ? Colors.black : mikasaBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      );

                      return ListTile(
                        onTap: () => Navigator.pop(context, id),
                        leading: avatar,
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

      await _saveMatchResume();
      await _clearSavedState();

      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _finishMatchDirect() async {
    await _confirmFinishMatch();
    if (mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  Future<void> _saveMatchResume() async {
    if (matchId == null) return;
    final oppId = opponentId ??
        (widget.analyzedTeamId == widget.homeTeamId
            ? widget.awayTeamId
            : widget.homeTeamId);

    await FirebaseFirestore.instance
        .collection("teams")
        .doc(widget.analyzedTeamId)
        .collection("matchs")
        .doc(matchId)
        .set({
          "opponentId": oppId,
          "opponentName": opponentName,
          "setsUs": setsUs,
          "setsOpp": setsOpp,
          "createdAt": DateTime.now(),
        });
  }
}
