import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'manage_pdfs.dart';

class ManageFolders extends StatefulWidget {
  final String currentUserId;

  const ManageFolders({Key? key, required this.currentUserId})
      : super(key: key);

  @override
  _ManageFoldersState createState() => _ManageFoldersState();
}

class _ManageFoldersState extends State<ManageFolders> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _folderNameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Folders', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepOrange,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('folders')
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
              return _buildFolderListItem(doc);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddFolderDialog,
        icon: Icon(Icons.create_new_folder, color: Colors.white),
        label: Text('Create Folder', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepOrange,
      ),
    );
  }

  Widget _buildFolderListItem(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return FutureBuilder<String>(
      future: _getUserFullName(data['createdBy']),
      builder: (context, snapshot) {
        String createdByFullName = snapshot.data ?? 'Unknown';
        return Card(
          elevation: 2,
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: ListTile(
            title: Text(data['name'] ?? 'Unnamed Folder',
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text('Created by: $createdByFullName'),
                SizedBox(height: 4),
                Text('Created: ${_formatTimestamp(data['timestamp'])}'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEditFolderDialog(doc),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeleteFolderDialog(doc.id),
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ManagePdfs(
                    folderId: doc.id,
                    folderName: data['name'] ?? 'Unnamed Folder',
                    currentUserId: widget.currentUserId,
                  ),
                ),
              );
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
              backgroundColor: Colors.deepOrange,
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

  void _showEditFolderDialog(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    _folderNameController.text = data['name'] ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Folder'),
          content: TextField(
            controller: _folderNameController,
            decoration: InputDecoration(
              labelText: 'Folder Name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                _folderNameController.clear();
              },
            ),
            ElevatedButton(
              child: Text('Save'),
              onPressed: () async {
                await _firestore.collection('folders').doc(doc.id).update({
                  'name': _folderNameController.text,
                });
                Navigator.of(context).pop();
                _folderNameController.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Folder updated successfully')),
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

  void _showDeleteFolderDialog(String folderId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Folder'),
          content: Text('Are you sure you want to delete this folder?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text('Delete'),
              onPressed: () async {
                await _firestore.collection('folders').doc(folderId).delete();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Folder deleted successfully')),
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

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    return DateFormat('MMM d, yyyy').format(timestamp.toDate());
  }

  @override
  void dispose() {
    _folderNameController.dispose();
    super.dispose();
  }
}
