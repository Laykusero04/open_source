import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'pdf_list_screen.dart';

class FolderListScreen extends StatefulWidget {
  final String deviceUuid;

  const FolderListScreen({Key? key, required this.deviceUuid})
      : super(key: key);

  @override
  _FolderListScreenState createState() => _FolderListScreenState();
}

class _FolderListScreenState extends State<FolderListScreen> {
  late Stream<QuerySnapshot> _foldersStream;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _foldersStream = _firestore.collection('folders').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PDF Folders'),
        backgroundColor: Colors.deepOrange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _foldersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No folders available'));
          }

          List<QueryDocumentSnapshot> folders = snapshot.data!.docs;

          return ListView.builder(
            itemCount: folders.length,
            itemBuilder: (context, index) {
              DocumentSnapshot folder = folders[index];
              return FutureBuilder<String>(
                future: _getUserFullName(folder['createdBy']),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListTile(title: Text('Loading...'));
                  }
                  String createdByFullName = snapshot.data ?? 'Unknown';
                  return _buildFolderItem(folder, createdByFullName);
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<String> _getUserFullName(String userId) async {
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

  Widget _buildFolderItem(DocumentSnapshot folder, String createdByFullName) {
    String name = folder['name'] ?? 'Unnamed Folder';
    Timestamp timestamp = folder['timestamp'] ?? Timestamp.now();
    DateTime creationDate = timestamp.toDate();

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.deepOrange,
          child: Icon(Icons.folder, color: Colors.white),
        ),
        title: Text(
          name,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Created by $createdByFullName \n${DateFormat('MMM d, yyyy').format(creationDate)}',
          style: TextStyle(fontSize: 12),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _navigateToPdfList(context, folder.id, name),
      ),
    );
  }

  void _navigateToPdfList(
      BuildContext context, String folderId, String folderName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PdfListScreen(folderId: folderId, folderName: folderName),
      ),
    );
  }
}
