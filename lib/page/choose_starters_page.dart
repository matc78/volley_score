import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:volley_score/page/match_live_page.dart';

class ChooseStartersPage extends StatefulWidget {
  final String teamId;
  final String teamName;
  final String homeTeamId;
  final String awayTeamId;

  const ChooseStartersPage({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.homeTeamId,
    required this.awayTeamId,
  });

  @override
  State<ChooseStartersPage> createState() => _ChooseStartersPageState();
}

class _ChooseStartersPageState extends State<ChooseStartersPage> {
  static const mikasaBlue = Color(0xFF0033A0);
  static const mikasaYellow = Color(0xFFFFD600);

  List<String> selectedPlayers = [];
  String? liberoId; // OPTIONNEL

  @override
  Widget build(BuildContext context) {
    bool canStart = selectedPlayers.length == 6;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text("Sélection des titulaires".toUpperCase()),
      ),

      body: Column(
        children: [
          const SizedBox(height: 10),

          Text(
            "Équipe : ${widget.teamName}",
            style: const TextStyle(
              color: mikasaYellow,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("teams")
                  .doc(widget.teamId)
                  .collection("players")
                  .orderBy("lastName")
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                final players = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: players.length + 1, // +1 = Ajouter joueur
                  itemBuilder: (context, index) {
                    // ---------------------- AJOUTER UN JOUEUR ----------------------
                    if (index == players.length) {
                      return GestureDetector(
                        onTap: () => _showAddPlayerDialog(context),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: mikasaYellow, width: 2),
                          ),
                          child: Row(
                            children: const [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: Colors.white24,
                                child: Icon(
                                  Icons.add,
                                  color: mikasaYellow,
                                  size: 28,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  "Ajouter un joueur",
                                  style: TextStyle(
                                    color: mikasaYellow,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // ---------------------- JOUEUR ----------------------
                    final p = players[index];
                    final id = p.id;
                    final first = p["firstName"] ?? "";
                    final last = p["lastName"] ?? "";
                    final number = p["number"]?.toString() ?? "";
                    final photo = p["photoUrl"] ?? "";

                    final isStarter = selectedPlayers.contains(id);
                    final isLibero = liberoId == id;
                    final borderColor = isLibero
                        ? mikasaBlue
                        : (isStarter ? mikasaYellow : Colors.white24);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          // ========================
                          // 1️⃣ CHOIX DES 6 TITULAIRES
                          // ========================
                          if (selectedPlayers.length < 6) {
                            if (isStarter) {
                              selectedPlayers.remove(id);
                            } else {
                              selectedPlayers.add(id);
                            }
                            // Si un titulaire est retiré → libéro potentiellement invalide
                            if (isStarter && liberoId == id) {
                              liberoId = null;
                            }
                            return;
                          }

                          // ========================
                          // 2️⃣ LIBÉRO OPTIONNEL
                          // ========================
                          if (!selectedPlayers.contains(id)) {
                            // joueur non titulaire → peut être libéro
                            if (isLibero) {
                              liberoId = null;
                            } else {
                              liberoId = id;
                            }
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isStarter || isLibero
                              ? mikasaBlue.withOpacity(0.25)
                              : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor, width: 2),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.white12,
                              backgroundImage: photo.isNotEmpty
                                  ? NetworkImage(photo)
                                  : null,
                              child: photo.isEmpty
                                  ? Text(
                                      number.isNotEmpty
                                          ? number
                                          : (first.isNotEmpty
                                                ? first[0].toUpperCase()
                                                : "?"),
                                      style: const TextStyle(
                                        color: mikasaBlue,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    )
                                  : null,
                            ),

                            const SizedBox(width: 16),

                            Expanded(
                              child: Text(
                                (number.isNotEmpty)
                                    ? "N°$number  ${last.toUpperCase()} $first"
                                    : "${last.toUpperCase()} $first",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            if (isStarter)
                              const Icon(
                                Icons.check_circle,
                                color: mikasaYellow,
                                size: 28,
                              ),

                            if (isLibero)
                              const Icon(
                                Icons.sports_volleyball_rounded,
                                color: Colors.cyanAccent,
                                size: 28,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ---------------------- TEXTE LIBÉRO ----------------------
          if (selectedPlayers.length == 6)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                liberoId == null
                    ? "Sélectionnez un LIBÉRO (optionnel)"
                    : "Libéro sélectionné",
                style: const TextStyle(
                  color: mikasaYellow,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          // ---------------------- BOUTON LANCER ----------------------
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: Opacity(
              opacity: canStart ? 1 : 0.3,
              child: IgnorePointer(
                ignoring: !canStart,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MatchLivePage(
                          analyzedTeamId: widget.teamId,
                          analyzedTeamName: widget.teamName,
                          homeTeamId: widget.homeTeamId,
                          awayTeamId: widget.awayTeamId,
                          starters: selectedPlayers,
                          liberoId: liberoId,
                        ),
                      ),
                    );
                  },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: mikasaYellow,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                  ),
                  child: const Text(
                    "LANCER LE MATCH",
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  //                   AJOUT D’UN JOUEUR
  // ============================================================
  void _showAddPlayerDialog(BuildContext context) {
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
    final numberCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            "Ajouter un joueur",
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
                  labelText: "Numéro (optionnel)",
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: firstCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Prénom",
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 8),
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
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Annuler",
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () async {
                final first = firstCtrl.text.trim();
                final last = lastCtrl.text.trim();
                final number = numberCtrl.text.trim();

                if (first.isEmpty && last.isEmpty && number.isEmpty) return;

                await FirebaseFirestore.instance
                    .collection("teams")
                    .doc(widget.teamId)
                    .collection("players")
                    .add({
                      "firstName": first,
                      "lastName": last,
                      "number": number,
                      "photoUrl": "",
                      "height": "",
                      "weight": "",
                      "createdAt": DateTime.now(),
                    });

                Navigator.pop(context);
              },
              child: const Text(
                "Ajouter",
                style: TextStyle(color: mikasaYellow),
              ),
            ),
          ],
        );
      },
    );
  }
}
