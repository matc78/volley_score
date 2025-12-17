import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:volley_score/page/choose_starters_page.dart';

class MatchSetupPage extends StatefulWidget {
  const MatchSetupPage({super.key});

  @override
  State<MatchSetupPage> createState() => _MatchSetupPageState();
}

class _MatchSetupPageState extends State<MatchSetupPage>
    with SingleTickerProviderStateMixin {
  static const mikasaBlue = Color(0xFF0033A0);
  static const mikasaRed = Color(0xFFC62828);
  static const mikasaYellow = Color(0xFFFFD600);

  // Teams names
  String? homeTeam;
  String? awayTeam;

  // Teams Firestore IDs
  String? homeTeamId;
  String? awayTeamId;

  // Team being analyzed
  String? trackedTeam;
  String? trackedTeamId;

  // Truncate display names
  String truncateTeamName(String name, {int max = 25}) {
    if (name.length <= max) return name;
    return '${name.substring(0, max)}...';
  }

  late AnimationController _vsController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _vsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..repeat(reverse: true);

    _shakeAnimation = Tween<double>(
      begin: -4,
      end: 4,
    ).chain(CurveTween(curve: Curves.easeInOut)).animate(_vsController);
  }

  @override
  void dispose() {
    _vsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool canStart = homeTeam != null && awayTeam != null && trackedTeam != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ← Back
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            const SizedBox(height: 80),

            // ------------------- HOME TEAM -------------------
            GestureDetector(
              onTap: () {
                if (homeTeam == null) {
                  _selectTeam(context, isHome: true);
                } else if (awayTeam != null) {
                  setState(() {
                    trackedTeam = homeTeam;
                    trackedTeamId = homeTeamId;
                  });
                }
              },
              onLongPress: () => _selectTeam(context, isHome: true),
              child: Container(
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                decoration: (trackedTeam != null && trackedTeam == homeTeam)
                    ? BoxDecoration(
                        border: Border.all(color: mikasaYellow, width: 4),
                        borderRadius: BorderRadius.circular(12),
                      )
                    : null,
                child: Text(
                  (homeTeam == null
                      ? "Choisir équipe à domicile"
                      : truncateTeamName(homeTeam!).toUpperCase()),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: mikasaBlue,
                    fontSize: 32,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // ------------------- VS ANIMATION -------------------
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        "VS",
                        style: TextStyle(
                          fontSize: 120,
                          fontWeight: FontWeight.w900,
                          color: Colors.orange.withOpacity(0.2),
                          shadows: [
                            Shadow(
                              blurRadius: 40,
                              color: Colors.deepOrange.withOpacity(0.9),
                            ),
                            Shadow(
                              blurRadius: 80,
                              color: Colors.red.withOpacity(0.6),
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        "VS",
                        style: TextStyle(
                          fontSize: 90,
                          fontWeight: FontWeight.w900,
                          color: mikasaYellow,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 40),

            // ------------------- AWAY TEAM -------------------
            GestureDetector(
              onTap: () {
                if (awayTeam == null) {
                  _selectTeam(context, isHome: false);
                } else if (homeTeam != null) {
                  setState(() {
                    trackedTeam = awayTeam;
                    trackedTeamId = awayTeamId;
                  });
                }
              },
              onLongPress: () => _selectTeam(context, isHome: false),
              child: Container(
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                decoration: (trackedTeam != null && trackedTeam == awayTeam)
                    ? BoxDecoration(
                        border: Border.all(color: mikasaYellow, width: 4),
                        borderRadius: BorderRadius.circular(12),
                      )
                    : null,
                child: Text(
                  (awayTeam == null
                      ? "Choisir équipe visiteuse"
                      : truncateTeamName(awayTeam!).toUpperCase()),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: mikasaRed,
                    fontSize: 32,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),

            // ---------- Indication équipe suivie ----------
            if (trackedTeam != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  "ÉQUIPE ANALYSÉE : ${truncateTeamName(trackedTeam!).toUpperCase()}",
                  style: const TextStyle(
                    color: mikasaYellow,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else if (homeTeam != null && awayTeam != null)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Text(
                  "Sélectionne l'équipe à analyser",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            const Spacer(),

            // ------------------- START MATCH BUTTON -------------------
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Opacity(
                opacity: canStart ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !canStart,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChooseStartersPage(
                            teamId: trackedTeamId!,
                            teamName: trackedTeam!,
                            homeTeamId: homeTeamId!,
                            awayTeamId: awayTeamId!,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mikasaYellow,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 18,
                      ),
                    ),
                    child: const Text(
                      "COMMENCER LE MATCH",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  //              TEAM SELECTION POPUP
  // =========================================================
  void _selectTeam(BuildContext context, {required bool isHome}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SizedBox(
          height: 450,
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text(
                "Sélectionner une équipe",
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),

              TextButton.icon(
                icon: const Icon(Icons.add, color: Colors.yellow),
                label: const Text(
                  "Créer une nouvelle équipe",
                  style: TextStyle(color: Colors.yellow),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _showCreateTeamDialog(isHome: isHome);
                },
              ),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("teams")
                      .orderBy("name")
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }

                    final teams = snapshot.data!.docs;

                    return ListView.builder(
                      itemCount: teams.length,
                      itemBuilder: (context, index) {
                        final team = teams[index];
                        final name = team["name"];

                        return ListTile(
                          title: Text(
                            name.toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            setState(() {
                              if (isHome) {
                                homeTeam = name;
                                homeTeamId = team.id;
                              } else {
                                awayTeam = name;
                                awayTeamId = team.id;
                              }
                            });

                            Navigator.pop(context);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  //                     CREATE TEAM
  // =========================================================
  void _showCreateTeamDialog({required bool isHome}) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            "Nouvelle équipe",
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "Nom de l'équipe",
              labelStyle: TextStyle(color: Colors.white70),
            ),
          ),
          actions: [
            TextButton(
              child: const Text(
                "Annuler",
                style: TextStyle(color: Colors.white70),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text("Créer", style: TextStyle(color: mikasaYellow)),
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;

                final newTeam = await FirebaseFirestore.instance
                    .collection("teams")
                    .add({"name": name, "createdAt": DateTime.now()});

                setState(() {
                  if (isHome) {
                    homeTeam = name;
                    homeTeamId = newTeam.id;
                  } else {
                    awayTeam = name;
                    awayTeamId = newTeam.id;
                  }
                });

                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }
}
