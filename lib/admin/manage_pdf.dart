import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

import 'manage_access_pdf.dart';

class ManagePdf extends StatefulWidget {
  const ManagePdf({Key? key}) : super(key: key);

  @override
  State<ManagePdf> createState() => _ManagePdfState();
}

class _ManagePdfState extends State<ManagePdf> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  File? _selectedFile;
  String _fileName = '';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage PDFs'),
        backgroundColor: Colors.orange[700],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('pdfs').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final pdfs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: pdfs.length,
            itemBuilder: (context, index) {
              final pdf = pdfs[index].data() as Map<String, dynamic>;
              final pdfId = pdfs[index].id;
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(pdf['title'] ?? 'Untitled PDF'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Description: ${pdf['description'] ?? 'No description'}'),
                      Text('Created by: ${pdf['createdBy'] ?? 'Unknown'}'),
                    ],
                  ),
                  trailing: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('pdf_takers')
                        .where('pdfId', isEqualTo: pdfId)
                        .snapshots(),
                    builder: (context, takerSnapshot) {
                      if (takerSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return CircularProgressIndicator();
                      }
                      int takerCount = takerSnapshot.data?.docs.length ?? 0;
                      return Text('$takerCount Takers');
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ManageAccessPdf(
                          pdfId: pdfId,
                          pdfTitle: pdf['title'] ?? 'Untitled PDF',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPdf,
        icon: Icon(Icons.add),
        label: Text('Add PDF'),
        backgroundColor: Colors.orange[700],
      ),
    );
  }

  Future<void> _addPdf() async {
    _titleController.clear();
    _descriptionController.clear();
    _selectedFile = null;
    _fileName = '';

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text('Add PDF'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  SizedBox(height: 16),
                  ElevatedButton(
                    child:
                        Text(_fileName.isNotEmpty ? _fileName : 'Upload PDF'),
                    onPressed: () async {
                      await _pickPdfFile();
                      setState(
                          () {}); // Update the dialog to show the new file name
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[400],
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),
                  if (_fileName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Selected file: $_fileName',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              ElevatedButton(
                child: Text('Add'),
                onPressed: _uploadPdf,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                ),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _pickPdfFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _fileName = result.files.single.name;

        // If title is empty, use the file name (without extension) as the title
        if (_titleController.text.isEmpty) {
          _titleController.text = _fileName.split('.').first;
        }
      });
    }
  }

  Future<void> _uploadPdf() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a PDF file')),
      );
      return;
    }

    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(child: CircularProgressIndicator());
        },
      );

      // Get current user's full name
      User? currentUser = FirebaseAuth.instance.currentUser;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('admin')
          .doc(currentUser?.uid)
          .get();
      String fullName = userDoc['full_name'] ?? 'Unknown User';

      // Upload file to Firebase Storage
      String fileName =
          DateTime.now().millisecondsSinceEpoch.toString() + '_' + _fileName;
      Reference ref = _storage.ref().child('pdfs/$fileName');

      print('Uploading file to Firebase Storage...');
      await ref.putFile(_selectedFile!);
      print('File uploaded successfully.');

      print('Getting download URL...');
      String downloadURL = await ref.getDownloadURL();
      print('Download URL obtained: $downloadURL');

      // Format the timestamp
      DateTime now = DateTime.now();
      String formattedDate =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour < 12 ? 'AM' : 'PM'} ${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year}';

      // Add PDF details to Firestore
      print('Adding PDF details to Firestore...');
      await _firestore.collection('pdfs').add({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'createdBy': fullName,
        'takers': 0,
        'url': downloadURL,
        'fileName': _fileName,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('PDF details added to Firestore successfully.');

      // Close loading indicator
      Navigator.of(context).pop();

      // Close add PDF dialog
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF uploaded successfully')),
      );
    } catch (e) {
      // Close loading indicator
      Navigator.of(context).pop();

      print('Error during PDF upload: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading PDF: $e')),
      );
    }
  }
}
