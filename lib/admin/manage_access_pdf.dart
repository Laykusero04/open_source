import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class ManageAccessPdf extends StatefulWidget {
  final String pdfId;
  final String pdfTitle;

  const ManageAccessPdf({Key? key, required this.pdfId, required this.pdfTitle})
      : super(key: key);

  @override
  _ManageAccessPdfState createState() => _ManageAccessPdfState();
}

class _ManageAccessPdfState extends State<ManageAccessPdf>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _deviceIdController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_storage.FirebaseStorage _storage =
      firebase_storage.FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? pdfUrl;
  File? pdfFile;
  int _totalPages = 0;
  int _currentPage = 0;
  bool _isLoading = true;
  String? _errorMessage;
  PDFViewController? _pdfViewController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _fetchPdfData();
      if (pdfFile == null || !await pdfFile!.exists()) {
        await _downloadPdfInChunks();
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load PDF: $e';
        });
      }
      print('Error loading PDF: $e');
    }
  }

  Future<void> _fetchPdfData() async {
    try {
      DocumentSnapshot pdfDoc =
          await _firestore.collection('pdfs').doc(widget.pdfId).get();
      if (pdfDoc.exists) {
        Map<String, dynamic> data = pdfDoc.data() as Map<String, dynamic>;
        setState(() {
          pdfUrl = data['url'];
        });
      } else {
        throw Exception('PDF document not found');
      }
    } catch (e) {
      throw Exception('Error fetching PDF data: $e');
    }
  }

  Future<void> _downloadPdfInChunks() async {
    try {
      if (pdfUrl!.startsWith('gs://')) {
        print('Converting gs:// URL to https:// URL');
        firebase_storage.Reference ref = _storage.refFromURL(pdfUrl!);
        pdfUrl = await ref.getDownloadURL();
        print('Converted URL: $pdfUrl');
      }

      print('Attempting to download PDF from URL: $pdfUrl');

      final httpClient = HttpClient()
        ..badCertificateCallback =
            ((X509Certificate cert, String host, int port) => true);
      final request = await httpClient.getUrl(Uri.parse(pdfUrl!));
      final response = await request.close();

      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        pdfFile = File('${dir.path}/${widget.pdfTitle}.pdf');
        final sink = pdfFile!.openWrite();

        // Download in chunks
        await for (var chunk in response) {
          sink.add(chunk);
        }

        await sink.close();
        print('PDF downloaded successfully');
      } else {
        throw Exception('Failed to download PDF: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in _downloadPdfInChunks: $e');
      setState(() {
        _errorMessage = 'Error downloading PDF: $e';
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _deviceIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Access: ${widget.pdfTitle}'),
        backgroundColor: Colors.orange[700],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'User Access'),
            Tab(text: 'PDF Viewer'),
          ],
          indicatorColor: Colors.white,
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildUserAccessTab(),
                    _buildPdfViewerTab(),
                  ],
                ),
    );
  }

  Widget _buildUserAccessTab() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('pdf_takers')
                .where('pdfId', isEqualTo: widget.pdfId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text('No users'));
              }
              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final taker = snapshot.data!.docs[index];
                  return _buildUserListItem(taker.id, taker['deviceId']);
                },
              );
            },
          ),
        ),
        _buildAddTakersButton(),
      ],
    );
  }

  Widget _buildUserListItem(String takerId, String deviceId) {
    return FutureBuilder<DocumentSnapshot?>(
      future: _getUserData(deviceId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[300],
            child: ListTile(
              title: Text('Loading...',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          );
        }

        String fullName = 'Unknown User';
        if (snapshot.hasData && snapshot.data != null) {
          var userData = snapshot.data!.data() as Map<String, dynamic>?;
          if (userData != null) {
            fullName =
                '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                    .trim();
          }
        } else {
          print('No user data found for deviceId: $deviceId');
        }

        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[300],
          child: ListTile(
            title:
                Text(fullName, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(deviceId),
            trailing: IconButton(
              icon: Icon(Icons.delete, color: Colors.orange[700]),
              onPressed: () => _showDeleteConfirmationDialog(takerId),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(String takerId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete this user?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text('Delete'),
              onPressed: () {
                _removeTaker(takerId); // Call the deletion function
                Navigator.of(context).pop(); // Close the dialog
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<DocumentSnapshot?> _getUserData(String deviceId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .where('deviceUniqueId', isEqualTo: deviceId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first; // Return the first matching document
      } else {
        print('No user found for deviceId: $deviceId');
        return null; // Handle case where no user is found
      }
    } catch (e) {
      print('Error fetching user data: $e');
      return null; // Handle errors
    }
  }

  Future<void> _addTaker(String deviceId) async {
    if (deviceId.isNotEmpty) {
      try {
        await _firestore.collection('pdf_takers').add({
          'pdfId': widget.pdfId,
          'deviceId': deviceId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print('Error adding taker: $e');
      }
    }
  }

  Future<void> _removeTaker(String takerId) async {
    try {
      await _firestore.collection('pdf_takers').doc(takerId).delete();
    } catch (e) {
      print('Error removing taker: $e');
    }
  }

  Widget _buildAddTakersButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton(
        child: Text('Add Takers'),
        onPressed: _showAddTakerDialog,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[700],
          minimumSize: Size(double.infinity, 50),
        ),
      ),
    );
  }

  void _showAddTakerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Taker'),
          content: TextField(
            controller: _deviceIdController,
            decoration: InputDecoration(
              labelText: 'Device ID',
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
                _addTaker(_deviceIdController.text);
                Navigator.of(context).pop();
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.orange[700]),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPdfViewerTab() {
    if (pdfFile == null) {
      return Center(child: Text('PDF not available. Error: $_errorMessage'));
    }
    return Column(
      children: [
        Expanded(
          child: PDFView(
            filePath: pdfFile!.path,
            enableSwipe: true,
            swipeHorizontal: true,
            autoSpacing: false,
            pageFling: true,
            pageSnap: true,
            fitPolicy: FitPolicy.BOTH,
            preventLinkNavigation: false,
            onRender: (pages) {
              setState(() {
                _totalPages = pages!;
                _isLoading = false;
              });
            },
            onError: (error) {
              setState(() {
                _errorMessage = error.toString();
              });
              print('Error while rendering PDF: $error');
            },
            onPageError: (page, error) {
              setState(() {
                _errorMessage = 'Error on page ${page}: ${error.toString()}';
              });
              print('Error on page $page: $error');
            },
            onViewCreated: (PDFViewController pdfViewController) {
              _pdfViewController = pdfViewController;
            },
            onPageChanged: (int? page, int? total) {
              setState(() {
                _currentPage = page!;
              });
            },
          ),
        ),
        _buildPdfControls(),
      ],
    );
  }

  Widget _buildPdfControls() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed:
                _currentPage > 0 ? () => _changePage(_currentPage - 1) : null,
            child: Text('Previous'),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.orange[700]),
          ),
          Text('${_currentPage + 1} / $_totalPages'),
          ElevatedButton(
            onPressed: _currentPage < _totalPages - 1
                ? () => _changePage(_currentPage + 1)
                : null,
            child: Text('Next'),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.orange[700]),
          ),
        ],
      ),
    );
  }

  void _changePage(int page) {
    print('Changing to page $page');
    _pdfViewController?.setPage(page).then((_) {
      print('Page changed successfully');
    }).catchError((error) {
      print('Error changing page: $error');
    });
  }
}
