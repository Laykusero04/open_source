import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageFoldersScreen extends StatefulWidget {
  final String currentUserId;

  const ManageFoldersScreen({Key? key, required this.currentUserId})
      : super(key: key);

  @override
  State<ManageFoldersScreen> createState() => _ManageFoldersScreenState();
}

class _ManageFoldersScreenState extends State<ManageFoldersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _folderNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Folders', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepOrange,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  _firestore.collection('folders').orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                var folders = snapshot.data!.docs;
                if (_searchQuery.isNotEmpty) {
                  folders = folders
                      .where((doc) => doc['name']
                          .toString()
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()))
                      .toList();
                }

                if (folders.isEmpty) {
                  return Center(
                      child: Text(_searchQuery.isEmpty
                          ? 'No folders found. Create one!'
                          : 'No folders match your search.'));
                }

                return ListView.builder(
                  itemCount: folders.length,
                  itemBuilder: (context, index) {
                    DocumentSnapshot doc = folders[index];
                    return _buildFolderListItem(doc);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditFolderDialog(),
        icon: Icon(Icons.create_new_folder, color: Colors.white),
        label: Text('New Folder', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepOrange,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search folders...',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[200],
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildFolderListItem(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(Icons.folder, color: Colors.deepOrange, size: 36),
        title: Text(
          data['name'] ?? 'Unnamed Folder',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Created on: ${_formatTimestamp(data['timestamp'])}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: Colors.green),
              onPressed: () => _showAddEditFolderDialog(doc: doc),
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _showDeleteConfirmationDialog(doc.id),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddEditFolderDialog({DocumentSnapshot? doc}) async {
    if (doc != null) {
      _folderNameController.text = doc['name'];
    } else {
      _folderNameController.clear();
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(doc == null ? 'Add New Folder' : 'Edit Folder'),
        content: TextField(
          controller: _folderNameController,
          decoration: InputDecoration(
            labelText: 'Folder Name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.folder),
          ),
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            child: Text(doc == null ? 'Add' : 'Update'),
            onPressed: () {
              if (doc == null) {
                _addFolder(_folderNameController.text);
              } else {
                _updateFolder(doc.id, _folderNameController.text);
              }
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
      _showSnackBar('Folder name cannot be empty');
      return;
    }

    try {
      await _firestore.collection('folders').add({
        'name': folderName,
        'createdBy': widget.currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _showSnackBar('Folder added successfully');
    } catch (e) {
      print('Error adding folder: $e');
      _showSnackBar('Error adding folder: $e');
    }
  }

  Future<void> _updateFolder(String docId, String newName) async {
    if (newName.trim().isEmpty) {
      _showSnackBar('Folder name cannot be empty');
      return;
    }

    try {
      await _firestore.collection('folders').doc(docId).update({
        'name': newName,
        'updatedBy': widget.currentUserId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _showSnackBar('Folder updated successfully');
    } catch (e) {
      print('Error updating folder: $e');
      _showSnackBar('Error updating folder: $e');
    }
  }

  Future<void> _showDeleteConfirmationDialog(String docId) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Folder'),
        content: Text('Are you sure you want to delete this folder?'),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            child: Text('Delete'),
            onPressed: () {
              _deleteFolder(docId);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFolder(String docId) async {
    try {
      await _firestore.collection('folders').doc(docId).delete();
      _showSnackBar('Folder deleted successfully');
    } catch (e) {
      print('Error deleting folder: $e');
      _showSnackBar('Error deleting folder: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    return DateTime.fromMillisecondsSinceEpoch(timestamp.millisecondsSinceEpoch)
        .toString()
        .split(' ')[0];
  }

  @override
  void dispose() {
    _folderNameController.dispose();
    super.dispose();
  }
}
