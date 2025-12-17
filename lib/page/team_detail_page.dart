import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class TeamDetailPage extends StatelessWidget {
  final String teamId;
  final String teamName;

  const TeamDetailPage({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  @override
  Widget build(BuildContext context) {
    const mikasaBlue = Color(0xFF0033A0);
    const mikasaYellow = Color(0xFFF5F12D);

    return Scaffold(
      body: Stack(
        children: [
          // Fond d'écran
          Positioned.fill(
            child: Image.asset("assets/volley_bg.jpg", fit: BoxFit.cover),
          ),

          // Léger voile pour lisibilité
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.15)),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
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
                          teamName.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: mikasaBlue,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Liste des joueurs
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("teams")
                        .doc(teamId)
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
                          final firstName = (player["firstName"] ?? "")
                              .toString();
                          final lastName = (player["lastName"] ?? "")
                              .toString();
                          final height = player["height"]; // en cm
                          final weight = player["weight"]; // en kg
                          final photoUrl = (player["photoUrl"] ?? "")
                              .toString()
                              .trim();

                          final fullName =
                              "${lastName.toUpperCase()} $firstName";

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
                                        (firstName.isNotEmpty
                                                ? firstName[0]
                                                : "?")
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: mikasaBlue,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      )
                                    : null,
                              ),
                              title: Text(
                                fullName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: mikasaBlue,
                                ),
                              ),
                              subtitle: Text(
                                details,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                              onTap: () {
                                // Plus tard : éditer le joueur
                              },
                            ),
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

      // Bouton + pour ajouter un joueur
      floatingActionButton: FloatingActionButton(
        backgroundColor: mikasaBlue,
        child: const Icon(Icons.add, color: mikasaYellow),
        onPressed: () {
          _showAddPlayerDialog(context, teamId);
        },
      ),
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

                    // Prénom
                    TextField(
                      controller: firstNameController,
                      decoration: const InputDecoration(labelText: "Prénom *"),
                    ),

                    // Nom
                    TextField(
                      controller: lastNameController,
                      decoration: const InputDecoration(labelText: "Nom *"),
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
                    String height = heightController.text.trim();
                    String weight = weightController.text.trim();

                    if (first.isEmpty || last.isEmpty) return;

                    // Formatage du prénom
                    first =
                        first[0].toUpperCase() +
                        first.substring(1).toLowerCase();

                    // Formatage du nom
                    last = last.toUpperCase();

                    await FirebaseFirestore.instance
                        .collection("teams")
                        .doc(teamId)
                        .collection("players")
                        .add({
                          "firstName": first,
                          "lastName": last,
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
}
