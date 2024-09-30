import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pdf_screen.dart';

class PdfListScreen extends StatelessWidget {
  final String folderId;
  final String folderName;

  const PdfListScreen(
      {Key? key, required this.folderId, required this.folderName})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(folderName),
        backgroundColor: Colors.deepOrange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('pdfs')
            .where('folderId', isEqualTo: folderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No PDFs in this folder'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              DocumentSnapshot pdfDoc = snapshot.data!.docs[index];
              return _buildPdfItem(context, pdfDoc);
            },
          );
        },
      ),
    );
  }

  Widget _buildPdfItem(BuildContext context, DocumentSnapshot pdfDoc) {
    String title = pdfDoc['title'] ?? 'Untitled';
    String description = pdfDoc['description'] ?? 'No description';

    return ListTile(
      leading: Icon(Icons.picture_as_pdf, color: Colors.red),
      title: Text(title),
      subtitle: Text(description, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => _openPdf(context, pdfDoc['url'], title),
    );
  }

  void _openPdf(BuildContext context, String? url, String title) {
    if (url != null && url.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfScreen(pdfUrl: url, title: title),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF URL is not available')),
      );
    }
  }
}
