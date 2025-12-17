import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PlayerDetailPage extends StatefulWidget {
  final String teamId;
  final String teamName;
  final String playerId;
  final String firstName;
  final String lastName;
  final String? photoUrl;
  final String? height;
  final String? weight;

  const PlayerDetailPage({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.playerId,
    required this.firstName,
    required this.lastName,
    this.photoUrl,
    this.height,
    this.weight,
  });

  @override
  State<PlayerDetailPage> createState() => _PlayerDetailPageState();
}

class _PlayerDetailPageState extends State<PlayerDetailPage> {
  late String firstName;
  late String lastName;
  String? height;
  String? weight;
  String? photoUrl;

  static const mikasaBlue = Color(0xFF0033A0);
  static const mikasaYellow = Color(0xFFF5F12D);

  @override
  void initState() {
    super.initState();
    firstName = widget.firstName;
    lastName = widget.lastName;
    height = widget.height;
    weight = widget.weight;
    photoUrl = widget.photoUrl;
  }

  // PICK IMAGE + UPLOAD
  Future<String?> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (picked == null) return null;

    File file = File(picked.path);

    final storageRef = FirebaseStorage.instance.ref().child(
      "teams/${widget.teamId}/players/${widget.playerId}.jpg",
    );

    final upload = await storageRef.putFile(file);
    return await upload.ref.getDownloadURL();
  }

  // EDIT PLAYER DIALOG
  void _editPlayerDialog() {
    final firstCtrl = TextEditingController(text: firstName);
    final lastCtrl = TextEditingController(text: lastName);
    final heightCtrl = TextEditingController(text: height ?? "");
    final weightCtrl = TextEditingController(text: weight ?? "");

    String? tempPhoto = photoUrl;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSB) {
            return AlertDialog(
              title: const Text(
                "Modifier le joueur",
                style: TextStyle(color: mikasaBlue),
              ),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final newPic = await _pickAndUploadImage();
                        if (newPic != null) {
                          setSB(() => tempPhoto = newPic);
                        }
                      },
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: mikasaBlue.withOpacity(0.2),
                        backgroundImage:
                            tempPhoto != null && tempPhoto!.isNotEmpty
                            ? NetworkImage(tempPhoto!)
                            : null,
                        child: tempPhoto == null
                            ? const Icon(
                                Icons.camera_alt,
                                color: mikasaBlue,
                                size: 32,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: firstCtrl,
                      decoration: const InputDecoration(labelText: "Prénom"),
                    ),
                    TextField(
                      controller: lastCtrl,
                      decoration: const InputDecoration(labelText: "Nom"),
                    ),
                    TextField(
                      controller: heightCtrl,
                      decoration: const InputDecoration(
                        labelText: "Taille (cm)",
                      ),
                    ),
                    TextField(
                      controller: weightCtrl,
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
                    "Enregistrer",
                    style: TextStyle(color: mikasaYellow),
                  ),
                  onPressed: () async {
                    String f = firstCtrl.text.trim();
                    String l = lastCtrl.text.trim();
                    String h = heightCtrl.text.trim();
                    String w = weightCtrl.text.trim();

                    // Format prénom et nom
                    if (f.isNotEmpty) {
                      f = f[0].toUpperCase() + f.substring(1).toLowerCase();
                    }
                    l = l.toUpperCase();

                    // Infos optionnelles
                    final formattedHeight = h.isNotEmpty ? h : null;
                    final formattedWeight = w.isNotEmpty ? w : null;

                    // Update Firestore
                    await FirebaseFirestore.instance
                        .collection("teams")
                        .doc(widget.teamId)
                        .collection("players")
                        .doc(widget.playerId)
                        .update({
                          "firstName": f,
                          "lastName": l,
                          "height": formattedHeight,
                          "weight": formattedWeight,
                          "photoUrl": tempPhoto ?? "",
                        });

                    // Update UI immediately
                    setState(() {
                      firstName = f;
                      lastName = l;
                      height = formattedHeight;
                      weight = formattedWeight;
                      photoUrl = tempPhoto;
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
                // TOP BAR
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: mikasaBlue),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          "${lastName.toUpperCase()} $firstName",
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: mikasaBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: mikasaBlue),
                        onPressed: _editPlayerDialog,
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        _buildPlayerCard(),
                        const SizedBox(height: 20),

                        Text(
                          "Équipe : ${widget.teamName}",
                          style: const TextStyle(
                            fontSize: 16,
                            color: mikasaBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 30),

                        _buildGlobalStats(),

                        const SizedBox(height: 30),
                        _buildMatchStats(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // PLAYER CARD
  Widget _buildPlayerCard() {
    String heightText = height != null ? "$height cm" : "?? cm";
    String weightText = weight != null ? "$weight kg" : "?? kg";
    String combined = "$heightText • $weightText";

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: mikasaBlue, width: 1.4),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 45,
            backgroundColor: mikasaBlue.withOpacity(0.2),
            backgroundImage: photoUrl != null && photoUrl!.isNotEmpty
                ? NetworkImage(photoUrl!)
                : null,
            child: photoUrl == null || photoUrl!.isEmpty
                ? Text(
                    firstName.isNotEmpty ? firstName[0].toUpperCase() : "?",
                    style: const TextStyle(
                      color: mikasaBlue,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),

          const SizedBox(height: 8),

          Text(
            firstName,
            style: const TextStyle(
              color: mikasaBlue,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),

          Text(
            lastName,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),

          const SizedBox(height: 6),
          Text(
            combined,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  // GLOBAL STATS
  Widget _buildGlobalStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mikasaBlue, width: 1.4),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "STATISTIQUES GLOBALES",
            style: TextStyle(
              color: mikasaBlue,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 10),
          Text("Points marqués : 0"),
          Text("Fautes : 0"),
          Text("Matchs joués : 0"),
          Text("Ratio points / fautes : 0.00"),
        ],
      ),
    );
  }

  Widget _buildMatchStats() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 40),
      child: Text(
        "MATCHS PASSÉS (à implémenter)",
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: mikasaBlue,
        ),
      ),
    );
  }
}
