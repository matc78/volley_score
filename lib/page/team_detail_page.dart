import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:volley_score/page/player_detail_page.dart';
import 'package:volley_score/page/match_detail_page.dart';

class TeamDetailPage extends StatefulWidget {
  final String teamId;
  final String teamName;

  const TeamDetailPage({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  @override
  State<TeamDetailPage> createState() => _TeamDetailPageState();
}

class _TeamDetailPageState extends State<TeamDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const mikasaBlue = Color(0xFF0033A0);
    const mikasaYellow = Color(0xFFF5F12D);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset("assets/volley_bg.jpg", fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.15)),
          ),
          SafeArea(
            child: Column(
              children: [
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
                      Expanded(
                        child: Text(
                          widget.teamName.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: mikasaBlue,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: mikasaBlue),
                        onPressed: () => _editTeamName(context),
                      ),
                    ],
                  ),
                ),
                Container(
                  color: mikasaBlue.withOpacity(0.12),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: mikasaBlue,
                    unselectedLabelColor: Colors.black,
                    indicatorColor: mikasaBlue,
                    tabs: const [
                      Tab(text: "Joueurs"),
                      Tab(text: "Matchs"),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPlayersTab(context, mikasaBlue, mikasaYellow),
                      _buildMatchesTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              backgroundColor: mikasaBlue,
              child: const Icon(Icons.add, color: mikasaYellow),
              onPressed: () => _showAddPlayerDialog(context, widget.teamId),
            )
          : null,
    );
  }

  Widget _buildPlayersTab(
    BuildContext context,
    Color mikasaBlue,
    Color mikasaYellow,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("teams")
          .doc(widget.teamId)
          .collection("players")
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

        final players = snapshot.data!.docs;

        if (players.isEmpty) {
          return const Center(
            child: Text(
              "Aucun joueur pour cette équipe",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: players.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final player = players[index];
            final firstName = (player["firstName"] ?? "").toString();
            final lastName = (player["lastName"] ?? "").toString();
            final number = (player["number"] ?? "").toString().trim();
            final height = player["height"];
            final weight = player["weight"];
            final photoUrl = (player["photoUrl"] ?? "").toString().trim();

            final fullName = "${lastName.toUpperCase()} $firstName";

            String details = "";
            if (height != null && height.toString().isNotEmpty) {
              details += "$height cm";
            }
            if (weight != null && weight.toString().isNotEmpty) {
              if (details.isNotEmpty) details += " • ";
              details += "$weight kg";
            }
            if (details.isEmpty) {
              details = "Infos physiques non renseignées";
            }

            return Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: mikasaBlue, width: 1.3),
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
                leading: CircleAvatar(
                  radius: 26,
                  backgroundColor: mikasaBlue.withOpacity(0.1),
                  backgroundImage: photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl.isEmpty
                      ? Text(
                          number.isNotEmpty
                              ? number
                              : (firstName.isNotEmpty ? firstName[0] : "?")
                                    .toUpperCase(),
                          style: TextStyle(
                            color: number.isNotEmpty ? Colors.red : mikasaBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
                title: Text(
                  number.isNotEmpty ? "N°$number  $fullName" : fullName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: mikasaBlue,
                  ),
                ),
                subtitle: Text(
                  details,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
                trailing: number.isNotEmpty
                    ? CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.red,
                        child: Text(
                          number,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlayerDetailPage(
                        teamId: widget.teamId,
                        teamName: widget.teamName,
                        playerId: player.id,
                        firstName: firstName,
                        lastName: lastName,
                        height: height?.toString(),
                        weight: weight?.toString(),
                        photoUrl: photoUrl,
                        number: number.isNotEmpty ? number : null,
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
  }

  Widget _buildMatchesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("teams")
          .doc(widget.teamId)
          .collection("matchs")
          .orderBy("createdAt", descending: true)
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

        final matchs = snapshot.data!.docs;
        if (matchs.isEmpty) {
          return const Center(
            child: Text(
              "Aucun match joué",
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: matchs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final m = matchs[index];
            final oppName = (m["opponentName"] ?? "Adversaire")
                .toString()
                .toUpperCase();
            final created = m["createdAt"];
            DateTime? date;
            if (created is Timestamp) {
              date = created.toDate();
            } else if (created is DateTime) {
              date = created;
            }
            final dateStr = date != null
                ? "${date.day.toString().padLeft(2, '0')}/"
                      "${date.month.toString().padLeft(2, '0')}/"
                      "${date.year}"
                : "";
            final setsUs = (m["setsUs"] ?? 0) as int;
            final setsOpp = (m["setsOpp"] ?? 0) as int;
            final isWin = setsUs > setsOpp;
            final marker = isWin ? "V" : "D";
            final markerColor = isWin ? Colors.green : Colors.red;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF0033A0), width: 1.3),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                title: Text(
                  "VS $oppName",
                  style: const TextStyle(
                    color: Color(0xFF0033A0),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dateStr.isNotEmpty)
                      Text(
                        dateStr,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
                trailing: CircleAvatar(
                  radius: 18,
                  backgroundColor: markerColor,
                  child: Text(
                    marker,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MatchDetailPage(
                        teamId: widget.teamId,
                        teamName: widget.teamName,
                        opponentName: oppName,
                        matchId: m.id,
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
  }

  Future<String?> _pickAndUploadImage(String teamId) async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile == null) return null;

    File file = File(pickedFile.path);

    final storageRef = FirebaseStorage.instance.ref().child(
      "teams/$teamId/players/${DateTime.now().millisecondsSinceEpoch}.jpg",
    );

    final uploadTask = await storageRef.putFile(file);
    final downloadUrl = await uploadTask.ref.getDownloadURL();

    return downloadUrl;
  }

  // Dialog pour ajouter un joueur
  void _showAddPlayerDialog(BuildContext context, String teamId) {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final numberController = TextEditingController();
    final heightController = TextEditingController();
    final weightController = TextEditingController();

    String? imageUrl;

    const mikasaBlue = Color(0xFF0033A0);
    const mikasaYellow = Color(0xFFF5F12D);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                "Ajouter un joueur",
                style: TextStyle(color: mikasaBlue),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final url = await _pickAndUploadImage(teamId);
                        if (url != null) {
                          setState(() => imageUrl = url);
                        }
                      },
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: mikasaBlue.withOpacity(0.2),
                        backgroundImage: imageUrl != null
                            ? NetworkImage(imageUrl!)
                            : null,
                        child: imageUrl == null
                            ? const Icon(
                                Icons.camera_alt,
                                color: mikasaBlue,
                                size: 32,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Numero (optionnel)
                    TextField(
                      controller: numberController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Numéro"),
                    ),

                    // Prénom
                    TextField(
                      controller: firstNameController,
                      decoration: const InputDecoration(labelText: "Prénom"),
                    ),

                    // Nom
                    TextField(
                      controller: lastNameController,
                      decoration: const InputDecoration(labelText: "Nom"),
                    ),

                    // Taille
                    TextField(
                      controller: heightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Taille (cm)",
                      ),
                    ),

                    // Poids
                    TextField(
                      controller: weightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Poids (kg)",
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text(
                    "Annuler",
                    style: TextStyle(color: mikasaBlue),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: mikasaBlue),
                  child: const Text(
                    "Ajouter",
                    style: TextStyle(color: mikasaYellow),
                  ),
                  onPressed: () async {
                    String first = firstNameController.text.trim();
                    String last = lastNameController.text.trim();
                    String number = numberController.text.trim();
                    String height = heightController.text.trim();
                    String weight = weightController.text.trim();

                    // Au moins une info requise (numéro, prénom ou nom)
                    if (first.isEmpty && last.isEmpty && number.isEmpty) {
                      return;
                    }

                    // Formatage du prénom
                    if (first.isNotEmpty) {
                      first =
                          first[0].toUpperCase() +
                          first.substring(1).toLowerCase();
                    }

                    // Formatage du nom
                    if (last.isNotEmpty) {
                      last = last.toUpperCase();
                    }

                    await FirebaseFirestore.instance
                        .collection("teams")
                        .doc(teamId)
                        .collection("players")
                        .add({
                          "firstName": first,
                          "lastName": last,
                          "number": number.isNotEmpty ? number : null,
                          "photoUrl": imageUrl ?? "",
                          "height": height.isNotEmpty ? height : null,
                          "weight": weight.isNotEmpty ? weight : null,
                          "createdAt": DateTime.now(),
                        });

                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editTeamName(BuildContext context) {
    final nameController = TextEditingController(text: widget.teamName);
    const mikasaBlue = Color(0xFF0033A0);
    const mikasaYellow = Color(0xFFF5F12D);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Modifier le nom de l'équipe",
            style: TextStyle(color: mikasaBlue),
          ),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: "Nom de l'équipe"),
          ),
          actions: [
            TextButton(
              child: const Text("Annuler", style: TextStyle(color: mikasaBlue)),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: mikasaBlue),
              child: const Text(
                "Enregistrer",
                style: TextStyle(color: mikasaYellow),
              ),
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isEmpty) return;

                // Mise à jour Firestore
                await FirebaseFirestore.instance
                    .collection("teams")
                    .doc(widget.teamId)
                    .update({"name": newName});

                // Rafraîchissement direct
                Navigator.pop(context);

                // On recrée la page avec le nouveau nom
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeamDetailPage(
                      teamId: widget.teamId,
                      teamName: newName,
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
