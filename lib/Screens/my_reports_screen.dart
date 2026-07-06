import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key});

  Future<void> _openStorageFile(String storagePath) async {
    final ref = FirebaseStorage.instance.ref(storagePath);
    final url = await ref.getDownloadURL();
    final uri = Uri.parse(url);

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      throw Exception('Could not open PDF URL.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not authenticated')),
      );
    }

    final reportsQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('inspectionReports')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reports'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: reportsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading reports: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No saved reports.'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = docs[index].data();

              final clientName = (data['clientName'] as String?)?.trim();
              final claimNumber = (data['claimNumber'] as String?)?.trim();

              final techPath = data['techPath'] as String?;
              final photoPath = data['photoPath'] as String?;

              final createdAt = data['createdAt'];
              String createdText = '';
              if (createdAt is Timestamp) {
                createdText = createdAt.toDate().toLocal().toString();
              }

              return ListTile(
                title: Text(
                  (clientName != null && clientName.isNotEmpty)
                      ? clientName
                      : 'Client: N/A',
                ),
                subtitle: Text(
                  'Claim #: ${(claimNumber != null && claimNumber.isNotEmpty) ? claimNumber : 'N/A'}'
                  '${createdText.isNotEmpty ? '\nCreated: $createdText' : ''}',
                ),
                isThreeLine: createdText.isNotEmpty,
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      tooltip: 'Open Tech PDF',
                      icon: const Icon(Icons.description),
                      onPressed: techPath == null
                          ? null
                          : () async {
                              try {
                                await _openStorageFile(techPath);
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error opening Tech PDF: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                    ),
                    IconButton(
                      tooltip: 'Open Photo PDF',
                      icon: const Icon(Icons.photo_library),
                      onPressed: photoPath == null
                          ? null
                          : () async {
                              try {
                                await _openStorageFile(photoPath);
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error opening Photo PDF: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}