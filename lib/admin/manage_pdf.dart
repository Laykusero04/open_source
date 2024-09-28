import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'dart:io';
import 'manage_access_pdf.dart';
import 'package:intl/intl.dart';

import 'manage_folders.dart';

class ManagePdf extends StatefulWidget {
  final String currentUserId;

  const ManagePdf({Key? key, required this.currentUserId}) : super(key: key);

  @override
  _ManagePdfState createState() => _ManagePdfState();
}

class _ManagePdfState extends State<ManagePdf> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _deviceIdController = TextEditingController();
  final TextEditingController _folderNameController = TextEditingController();

  String? _selectedFolder;
  String? _currentUserFullName;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserFullName();
  }

  Future<void> _fetchCurrentUserFullName() async {
    DocumentSnapshot userDoc =
        await _firestore.collection('admin').doc(widget.currentUserId).get();
    if (userDoc.exists) {
      setState(() {
        _currentUserFullName = userDoc.get('full_name');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage PDFs', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepOrange,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFolderDropdown(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('pdfs')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
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
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: _uploadPdf,
            icon: Icon(
              Icons.add,
              color: Colors.white,
            ),
            label: Text(
              'Upload PDF',
              style: TextStyle(color: Colors.white),
            ),
            heroTag: 'uploadPdf',
            backgroundColor: Colors.deepOrange,
          ),
          SizedBox(height: 16),
          FloatingActionButton.extended(
            onPressed: _showAddFolderDialog,
            icon: Icon(
              Icons.create_new_folder,
              color: Colors.white,
            ),
            label: Text(
              'Create Folder',
              style: TextStyle(color: Colors.white),
            ),
            heroTag: 'addFolder',
            backgroundColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Future<void> _showAddFolderDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Folder'),
        content: TextField(
          controller: _folderNameController,
          decoration: InputDecoration(
            labelText: 'Folder Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () {
                  _folderNameController.clear();
                  Navigator.of(context).pop();
                },
              ),
              ElevatedButton(
                child: Text('Add'),
                onPressed: () {
                  _addFolder(_folderNameController.text);
                  _folderNameController.clear();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.green,
                ),
              ),
            ],
          ),
          Divider(),
          ElevatedButton(
            child: Text('Manage Folders'),
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ManageFoldersScreen(currentUserId: widget.currentUserId),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.brown,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addFolder(String folderName) async {
    if (folderName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Folder name cannot be empty')),
      );
      return;
    }

    try {
      await _firestore.collection('folders').add({
        'name': folderName,
        'createdBy': widget.currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Folder added successfully')),
      );
    } catch (e) {
      print('Error adding folder: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding folder: $e')),
      );
    }
  }

  Widget _buildFolderDropdown() {
    return Container(
      padding: EdgeInsets.all(16),
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('folders').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Container();

          List<DropdownMenuItem<String>> folderItems = [
            DropdownMenuItem<String>(
              value: null,
              child: Text('All PDFs'),
            ),
            ...snapshot.data!.docs.map((doc) {
              return DropdownMenuItem<String>(
                value: doc.id,
                child: Text(doc['name']),
              );
            }).toList(),
          ];

          return DropdownButtonFormField<String>(
            value: _selectedFolder,
            items: folderItems,
            onChanged: (value) {
              setState(() {
                _selectedFolder = value;
              });
            },
            decoration: InputDecoration(
              labelText: 'Select Folder',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[200],
              prefixIcon: Icon(Icons.folder, color: Colors.deepOrange),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPdfListItem(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    if (_selectedFolder != null && data['folderId'] != _selectedFolder) {
      return Container();
    }

    return Slidable(
      endActionPane: ActionPane(
        motion: ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) => _editPdf(doc),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Edit',
          ),
          SlidableAction(
            onPressed: (context) => _deletePdf(doc),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
          ),
        ],
      ),
      child: Card(
        elevation: 2,
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.all(16),
          title: Text(
            data['title'] ?? 'Untitled',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 4),
              Text(data['description'] ?? 'No description'),
              SizedBox(height: 4),
              Text(
                'Created by: ${data['createdBy'] ?? 'Unknown'}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              SizedBox(height: 4),
              Text(
                'Created: ${_formatTimestamp(data['timestamp'])}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.folder, color: Colors.deepOrange),
                onPressed: () => _showMoveToPdfDialog(doc.id),
              ),
              IconButton(
                icon: Icon(Icons.person_add, color: Colors.deepOrange),
                onPressed: () => _showAddTakerDialog(doc.id),
              ),
            ],
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ManageAccessPdf(
                pdfId: doc.id,
                pdfTitle: data['title'] ?? 'Untitled',
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _editPdf(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    _titleController.text = data['title'] ?? '';
    _descriptionController.text = data['description'] ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit PDF'),
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
                SizedBox(height: 10),
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
                  SnackBar(content: Text('PDF updated successfully')),
                );
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

  void _deletePdf(DocumentSnapshot doc) {
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
                await _firestore.collection('pdfs').doc(doc.id).delete();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('PDF deleted successfully')),
                );
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.red,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<String> _getCreatorName(String? creatorId) async {
    if (creatorId == null) return 'Unknown';

    try {
      DocumentSnapshot creatorDoc =
          await _firestore.collection('admin').doc(creatorId).get();
      if (creatorDoc.exists) {
        return creatorDoc.get('full_name') ?? 'Unknown';
      }
    } catch (e) {
      print('Error fetching creator name: $e');
    }
    return 'Unknown';
  }

  Future<Map<String, dynamic>> _getAdditionalInfo(
      Map<String, dynamic> data) async {
    Map<String, dynamic> additionalInfo = {};

    // Get creator's full name
    if (data['createdBy'] != null && data['createdBy'] != 'Unknown') {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(data['createdBy']).get();
      if (userDoc.exists) {
        additionalInfo['creatorName'] = userDoc.get('full_name');
      }
    }

    // Get folder name
    if (data['folderId'] != null) {
      DocumentSnapshot folderDoc =
          await _firestore.collection('folders').doc(data['folderId']).get();
      if (folderDoc.exists) {
        additionalInfo['folderName'] = folderDoc.get('name');
      }
    }

    return additionalInfo;
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    return DateFormat('MMM d, yyyy').format(timestamp.toDate());
  }

  Future<void> _uploadPdf() async {
    File? selectedFile;
    String fileName = '';

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Upload PDF'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      icon: Icon(Icons.upload_file),
                      label: Text('Select PDF'),
                      onPressed: () async {
                        FilePickerResult? result =
                            await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf'],
                        );

                        if (result != null) {
                          setState(() {
                            selectedFile = File(result.files.single.path!);
                            fileName = result.files.single.name;
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.deepOrange,
                      ),
                    ),
                    SizedBox(height: 10),
                    if (fileName.isNotEmpty)
                      Text(
                        'Selected file: $fileName',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    SizedBox(height: 20),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 10),
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
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: Text('Upload'),
                  onPressed: selectedFile == null
                      ? null
                      : () async {
                          Navigator.of(context).pop();
                          await _uploadFileAndSaveDetails(
                              selectedFile!, fileName);
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
      },
    );
  }

  Future<void> _uploadFileAndSaveDetails(File file, String fileName) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(child: CircularProgressIndicator());
        },
      );

      TaskSnapshot snapshot =
          await _storage.ref('pdfs/$fileName').putFile(file);
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // Fetch the admin's full name
      String adminFullName = await _getAdminFullName(widget.currentUserId);

      await _firestore.collection('pdfs').add({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'url': downloadUrl,
        'fileName': fileName,
        'folderId': _selectedFolder,
        'timestamp': FieldValue.serverTimestamp(),
        'createdBy': adminFullName, // Store the admin's full name
        'createdByUid':
            widget.currentUserId, // Also store the UID for reference
      });

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF uploaded successfully')),
      );

      _titleController.clear();
      _descriptionController.clear();
    } catch (e) {
      Navigator.of(context).pop();

      print('Error uploading PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading PDF: $e')),
      );
    }
  }

  Future<String> _getAdminFullName(String adminUid) async {
    try {
      DocumentSnapshot adminDoc =
          await _firestore.collection('admin').doc(adminUid).get();
      if (adminDoc.exists) {
        return adminDoc.get('full_name') ?? 'Unknown';
      }
    } catch (e) {
      print('Error fetching admin name: $e');
    }
    return 'Unknown';
  }

  Future<void> _showMoveToPdfDialog(String pdfId) async {
    String? selectedFolderId;
    String selectedFolderName = 'Select Folder';

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Move to Folder'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('folders').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return CircularProgressIndicator();

                      List<DropdownMenuItem<String>> folderItems =
                          snapshot.data!.docs.map((doc) {
                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(doc['name']),
                        );
                      }).toList();

                      return DropdownButtonFormField<String>(
                        value: selectedFolderId,
                        items: folderItems,
                        onChanged: (value) {
                          setState(() {
                            selectedFolderId = value;
                            selectedFolderName = snapshot.data!.docs
                                .firstWhere((doc) => doc.id == value)['name'];
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Select Folder',
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: Text('Move'),
                  onPressed: selectedFolderId == null
                      ? null
                      : () async {
                          await _firestore
                              .collection('pdfs')
                              .doc(pdfId)
                              .update({
                            'folderId': selectedFolderId,
                          });
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text('PDF moved to $selectedFolderName')),
                          );
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
      },
    );
  }

  Future<void> _showAddTakerDialog(String pdfId) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Taker'),
        content: TextField(
          controller: _deviceIdController,
          decoration: InputDecoration(
            labelText: 'Device UUID',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            child: Text('Add'),
            onPressed: () {
              _addTaker(pdfId, _deviceIdController.text);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.deepOrange,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addTaker(String pdfId, String deviceId) async {
    try {
      var userQuery = await _firestore
          .collection('users')
          .where('deviceUniqueId', isEqualTo: deviceId)
          .get();

      if (userQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'User not found. Please ensure the user has registered.')),
        );
        return;
      }

      var existingAccess = await _firestore
          .collection('pdf_takers')
          .where('pdfId', isEqualTo: pdfId)
          .where('deviceId', isEqualTo: deviceId)
          .get();

      if (existingAccess.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('This user already has access to this PDF')),
        );
        return;
      }

      await _firestore.collection('pdf_takers').add({
        'pdfId': pdfId,
        'deviceId': deviceId,
        'timestamp': FieldValue.serverTimestamp(),
        'addedBy':
            widget.currentUserId, // Use the admin's UID instead of full name
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Taker added successfully')),
      );
    } catch (e) {
      print('Error adding taker: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding taker: $e')),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _deviceIdController.dispose();
    _folderNameController.dispose();
    super.dispose();
  }
}
