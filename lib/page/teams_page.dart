import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:volley_score/page/team_detail_page.dart';

class TeamsPage extends StatelessWidget {
  const TeamsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const mikasaBlue = Color(0xFF0033A0);
    const mikasaYellow = Color(0xFFF5F12D);

    return Scaffold(
      body: Stack(
        children: [
          // IMAGE DE FOND
          Positioned.fill(
            child: Image.asset("assets/volley_bg2.png", fit: BoxFit.cover),
          ),

          // DEGRADÉ POUR LISIBLE
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.15)),
          ),

          SafeArea(
            child: Column(
              children: [
                // HEADER
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: mikasaBlue),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "Équipes",
                        style: TextStyle(
                          color: mikasaBlue,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // LISTE DES ÉQUIPES
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("teams")
                        .orderBy("createdAt", descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            "Erreur de chargement",
                            style: TextStyle(color: Colors.white),
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final teams = snapshot.data!.docs;

                      if (teams.isEmpty) {
                        return const Center(
                          child: Text(
                            "Aucune équipe enregistrée",
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: teams.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final team = teams[index];
                          final name = (team["name"] ?? "")
                              .toString()
                              .toUpperCase();

                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection("teams")
                                .doc(team.id)
                                .collection("players")
                                .snapshots(),
                            builder: (context, playersSnapshot) {
                              int playerCount = 0;
                              if (playersSnapshot.hasData) {
                                playerCount = playersSnapshot.data!.docs.length;
                              }

                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.90),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: mikasaBlue,
                                    width: 1.4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 6,
                                      offset: const Offset(2, 2),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: mikasaBlue,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "$playerCount joueur${playerCount > 1 ? 's' : ''}",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    color: Colors.black54,
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TeamDetailPage(
                                          teamId: team.id,
                                          teamName: name,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // BOUTON AJOUT
      floatingActionButton: FloatingActionButton(
        backgroundColor: mikasaBlue,
        child: const Icon(Icons.add, color: mikasaYellow),
        onPressed: () {
          _showAddTeamDialog(context);
        },
      ),
    );
  }

  void _showAddTeamDialog(BuildContext context) {
    final controller = TextEditingController();
    const mikasaBlue = Color(0xFF0033A0);
    const mikasaYellow = Color(0xFFF5F12D);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Ajouter une équipe",
            style: TextStyle(color: mikasaBlue),
          ),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Nom de l'équipe"),
          ),
          actions: [
            TextButton(
              child: const Text("Annuler", style: TextStyle(color: mikasaBlue)),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: mikasaBlue),
              child: const Text(
                "Ajouter",
                style: TextStyle(color: mikasaYellow),
              ),
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;

                await FirebaseFirestore.instance.collection("teams").add({
                  "name": name,
                  "createdAt": DateTime.now(),
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
