import 'dart:async';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'pdf_screen.dart';

class PdfListScreen extends StatelessWidget {
  const PdfListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PDF Library',
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
        ),
        backgroundColor: Colors.deepOrange,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepOrange, Colors.orange.shade300],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: _getPdfTakersStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  'No PDFs available',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              );
            }
            return ListView.builder(
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var doc = snapshot.data!.docs[index];
                return _buildPdfCard(context, doc);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildPdfCard(BuildContext context, DocumentSnapshot doc) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('pdfs')
          .doc(doc['pdfId'] as String?)
          .get(),
      builder: (context, pdfSnapshot) {
        if (pdfSnapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: ListTile(title: Text('Loading...')),
          );
        }

        if (pdfSnapshot.hasError) {
          print('Error loading PDF: ${pdfSnapshot.error}');
          return Card(
            child: ListTile(title: Text('Error: ${pdfSnapshot.error}')),
          );
        }

        if (!pdfSnapshot.hasData || pdfSnapshot.data == null) {
          return const Card(
            child: ListTile(title: Text('No data available')),
          );
        }

        var pdfData = pdfSnapshot.data!.data() as Map<String, dynamic>?;
        if (pdfData == null) {
          return const Card(
            child: ListTile(title: Text('PDF data is null')),
          );
        }

        String pdfTitle = pdfData['title'] as String? ?? 'Untitled PDF';
        String createdBy = pdfData['createdBy'] as String? ?? 'Unknown';
        String description =
            pdfData['description'] as String? ?? 'No description';
        String formattedDate = 'Unknown date';

        if (pdfData['timestamp'] != null) {
          Timestamp timestamp = pdfData['timestamp'] as Timestamp;
          DateTime dateTime = timestamp.toDate();
          formattedDate = DateFormat('MMM d, yyyy - h:mm a').format(dateTime);
        }

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _openPdf(context, pdfData),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          pdfTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Icon(Icons.picture_as_pdf, color: Colors.deepOrange),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Created by: $createdBy'),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formattedDate,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openPdf(BuildContext context, Map<String, dynamic>? pdfData) async {
    var pdfPath = pdfData?['url'];
    if (pdfPath != null && pdfPath.isNotEmpty) {
      try {
        String downloadUrl = pdfPath.startsWith('gs://')
            ? await _getPdfDownloadUrl(pdfPath)
            : pdfPath;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfScreen(pdfUrl: downloadUrl),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF URL is not available'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Stream<QuerySnapshot> _getPdfTakersStream() {
    String? deviceId = FirebaseAuth.instance.currentUser?.uid;
    return FirebaseFirestore.instance
        .collection('pdf_takers')
        .where('deviceId', isEqualTo: deviceId)
        .snapshots();
  }

  Future<String> _getPdfDownloadUrl(String storagePath) async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      final ref = FirebaseStorage.instance.ref(storagePath);
      return await ref.getDownloadURL().timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Connection timed out'),
          );
    } catch (e) {
      print('Error in _getPdfDownloadUrl: $e');
      rethrow;
    }
  }
}
