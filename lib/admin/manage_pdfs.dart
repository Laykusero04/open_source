import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

class ManagePdfs extends StatefulWidget {
  final String folderId;
  final String folderName;
  final String currentUserId;

  const ManagePdfs({
    Key? key,
    required this.folderId,
    required this.folderName,
    required this.currentUserId,
  }) : super(key: key);

  @override
  _ManagePdfsState createState() => _ManagePdfsState();
}

class _ManagePdfsState extends State<ManagePdfs> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PDFs in ${widget.folderName}',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepOrange,
        elevation: 0,
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: _firestore
            .collection('pdfs')
            .where('folderId', isEqualTo: widget.folderId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No PDFs in this folder yet.'));
          }
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              DocumentSnapshot doc = snapshot.data!.docs[index];
              return _buildPdfListItem(doc);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploadPdf,
        icon: Icon(Icons.upload_file, color: Colors.white),
        label: Text('Upload PDF', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepOrange,
      ),
    );
  }

  Widget _buildPdfListItem(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return FutureBuilder<String>(
      future: _getUserFullName(data['uploadedBy']),
      builder: (context, snapshot) {
        String uploadedByFullName = snapshot.data ?? 'Unknown';
        return Card(
          elevation: 2,
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: ListTile(
            title: Text(data['title'] ?? 'Untitled PDF',
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text(data['description'] ?? 'No description'),
                SizedBox(height: 4),
                Text('Uploaded by: $uploadedByFullName'),
                SizedBox(height: 4),
                Text('Uploaded: ${_formatTimestamp(data['timestamp'])}'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEditPdfDialog(doc),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () =>
                      _showDeletePdfDialog(doc.id, data['fileName']),
                ),
              ],
            ),
            onTap: () {
              // Implement PDF viewing functionality here
            },
          ),
        );
      },
    );
  }

  Future<String> _getUserFullName(String? userId) async {
    if (userId == null) return 'Unknown';
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('admin').doc(userId).get();
      if (userDoc.exists) {
        return userDoc['full_name'] ?? 'Unknown';
      }
    } catch (e) {
      print('Error fetching user full name: $e');
    }
    return 'Unknown';
  }

  Future<void> _uploadPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      String fileName = result.files.single.name;

      // Pre-fill the title with the file name (without the .pdf extension)
      _titleController.text = fileName.replaceAll('.pdf', '');

      // Show dialog to input title and description
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Upload PDF'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Selected file: $fileName',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () {
                  _titleController.clear();
                  _descriptionController.clear();
                  Navigator.of(context).pop();
                },
              ),
              ElevatedButton(
                child: Text('Upload'),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _uploadFileAndSaveDetails(file, fileName);
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.deepOrange,
                ),
              ),
            ],
          );
        },
      );
    }
  }

  void _refreshPdfList() {
    setState(() {});
  }

  Future<void> _uploadFileAndSaveDetails(File file, String fileName) async {
    try {
      // Upload file to Firebase Storage
      TaskSnapshot snapshot =
          await _storage.ref('pdfs/$fileName').putFile(file);
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // Save PDF details to Firestore
      await _firestore.collection('pdfs').add({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'fileName': fileName,
        'url': downloadUrl,
        'folderId': widget.folderId,
        'uploadedBy': widget.currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF uploaded successfully')),
      );

      _titleController.clear();
      _descriptionController.clear();
      _refreshPdfList();
    } catch (e) {
      print('Error uploading PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading PDF: $e')),
      );
    }
  }

  void _showEditPdfDialog(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    _titleController.text = data['title'] ?? '';
    _descriptionController.text = data['description'] ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit PDF Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                _titleController.clear();
                _descriptionController.clear();
              },
            ),
            ElevatedButton(
              child: Text('Save'),
              onPressed: () async {
                await _firestore.collection('pdfs').doc(doc.id).update({
                  'title': _titleController.text,
                  'description': _descriptionController.text,
                });
                Navigator.of(context).pop();
                _titleController.clear();
                _descriptionController.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('PDF details updated successfully')),
                );
                _refreshPdfList();
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeletePdfDialog(String pdfId, String fileName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete PDF'),
          content: Text('Are you sure you want to delete this PDF?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text('Delete'),
              onPressed: () async {
                await _firestore.collection('pdfs').doc(pdfId).delete();
                await _storage.ref('pdfs/$fileName').delete();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('PDF deleted successfully')),
                );
                _refreshPdfList();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        );
      },
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    return DateFormat('MMM d, yyyy').format(timestamp.toDate());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
