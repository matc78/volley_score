import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volley_score/page/team_detail_page.dart';

class TeamsPage extends StatefulWidget {
  const TeamsPage({super.key});

  @override
  State<TeamsPage> createState() => _TeamsPageState();
}

class _TeamsPageState extends State<TeamsPage> {
  static const mikasaBlue = Color(0xFF0033A0);
  static const mikasaYellow = Color(0xFFF5F12D);

  List<_RecentTeam> recentTeams = [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList("recentTeams") ?? [];
    setState(() {
      recentTeams =
          (list
              .map((s) {
                final parts = s.split("|");
                if (parts.length >= 2) {
                  return _RecentTeam(
                    id: parts[0],
                    name: parts.sublist(1).join("|"),
                  );
                }
                return null;
              })
              .whereType<_RecentTeam>()
              .toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            ));
    });
  }

  Future<void> _saveRecent(String id, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = [_RecentTeam(id: id, name: name), ...recentTeams]
        .fold<List<_RecentTeam>>([], (acc, t) {
          if (acc.indexWhere((e) => e.id == t.id) == -1) acc.add(t);
          return acc;
        })
        .take(3)
        .toList();
    setState(() {
      recentTeams = updated;
    });
    final encoded = updated.map((t) => "${t.id}|${t.name}").toList();
    await prefs.setStringList("recentTeams", encoded);
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
                _header(context),
                if (recentTeams.isNotEmpty) _recentSection(),
                Expanded(child: _teamsList()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: mikasaBlue,
        child: const Icon(Icons.add, color: mikasaYellow),
        onPressed: () => _showAddTeamDialog(context),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
    );
  }

  Widget _recentSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.50),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Équipes consultées récemment",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentTeams.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final team = recentTeams[index];
                return _teamTile(
                  id: team.id,
                  name: team.name.toUpperCase(),
                  playerCount: null,
                  onTap: () => _openTeam(team.id, team.name),
                  dense: true,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("teams")
          .orderBy("name")
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

        final teams = snapshot.data!.docs.toList()
          ..sort(
            (a, b) => (a["name"] ?? "").toString().toLowerCase().compareTo(
              (b["name"] ?? "").toString().toLowerCase(),
            ),
          );
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
            final name = (team["name"] ?? "").toString();

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

                return _teamTile(
                  id: team.id,
                  name: name.toUpperCase(),
                  playerCount: playerCount,
                  onTap: () => _openTeam(team.id, name),
                  dense: false,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _teamTile({
    required String id,
    required String name,
    required VoidCallback onTap,
    int? playerCount,
    required bool dense,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mikasaBlue, width: 1.4),
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
        dense: dense,
        title: Text(
          name,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: mikasaBlue,
          ),
        ),
        subtitle: playerCount == null
            ? null
            : Text(
                "$playerCount joueur${playerCount > 1 ? 's' : ''}",
                style: const TextStyle(fontSize: 18, color: Colors.black87),
              ),
        trailing: const Icon(Icons.chevron_right, color: Colors.black54),
        onTap: onTap,
      ),
    );
  }

  Future<void> _openTeam(String id, String name) async {
    await _saveRecent(id, name);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TeamDetailPage(teamId: id, teamName: name.toUpperCase()),
      ),
    );
  }

  void _showAddTeamDialog(BuildContext context) {
    final controller = TextEditingController();

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

                if (!mounted) return;
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }
}

class _RecentTeam {
  final String id;
  final String name;
  _RecentTeam({required this.id, required this.name});
}
