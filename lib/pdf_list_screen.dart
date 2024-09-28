import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'pdf_screen.dart';

class PdfListScreen extends StatefulWidget {
  final String deviceUuid;

  const PdfListScreen({Key? key, required this.deviceUuid}) : super(key: key);

  @override
  _PdfListScreenState createState() => _PdfListScreenState();
}

class _PdfListScreenState extends State<PdfListScreen> {
  late Stream<QuerySnapshot> _pdfsStream;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initPdfsStream();
  }

  Future<void> _initPdfsStream() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _pdfsStream = _getPdfsStream();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load PDFs: ${e.toString()}';
      });
    }
  }

  Stream<QuerySnapshot> _getPdfsStream() {
    return FirebaseFirestore.instance
        .collection('pdf_takers')
        .where('deviceId', isEqualTo: widget.deviceUuid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PDF Library'),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _initPdfsStream,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: _initPdfsStream,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _pdfsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No PDFs available'));
        }

        return ListView.separated(
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (context, index) => Divider(),
          itemBuilder: (context, index) {
            DocumentSnapshot doc = snapshot.data!.docs[index];
            return PdfListItem(pdfId: doc['pdfId']);
          },
        );
      },
    );
  }
}

class PdfListItem extends StatelessWidget {
  final String pdfId;

  const PdfListItem({Key? key, required this.pdfId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance.collection('pdfs').doc(pdfId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeletonItem();
        }
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return ListTile(title: Text('Error loading PDF'));
        }

        Map<String, dynamic> pdfData =
            snapshot.data!.data() as Map<String, dynamic>;
        if (pdfData.isEmpty) {
          return ListTile(title: Text('PDF data is empty'));
        }
        return _buildPdfItem(context, pdfData);
      },
    );
  }

  Widget _buildSkeletonItem() {
    return ListTile(
      title: Container(height: 24, color: Colors.grey[300]),
      subtitle: Container(height: 16, color: Colors.grey[200]),
    );
  }

  Widget _buildPdfItem(BuildContext context, Map<String, dynamic> pdfData) {
    try {
      // Extracting data with null checks and default values
      String title = pdfData['title'] as String? ?? 'Untitled';
      String description =
          pdfData['description'] as String? ?? 'No description';
      String createdBy = pdfData['createdBy'] as String? ?? 'Unknown';
      String folderName = pdfData['folderName'] as String? ?? 'Uncategorized';

      DateTime timestamp;
      if (pdfData['timestamp'] is Timestamp) {
        timestamp = (pdfData['timestamp'] as Timestamp).toDate();
      } else if (pdfData['timestamp'] is DateTime) {
        timestamp = pdfData['timestamp'] as DateTime;
      } else {
        timestamp = DateTime.now();
        print('Warning: Invalid timestamp format in pdfData');
      }

      return ListTile(
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person, size: 12),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    createdBy,
                    style: TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.folder, size: 12),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    folderName,
                    style: TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              DateFormat('MMM d, yyyy HH:mm').format(timestamp),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _openPdf(context, pdfData['url'] as String?, title),
      );
    } catch (e, stackTrace) {
      print('Error in _buildPdfItem: $e');
      print('Stack trace: $stackTrace');
      return ListTile(
        title: Text('Error loading PDF item'),
        subtitle: Text('Please try again later'),
        trailing: Icon(Icons.error_outline, color: Colors.red),
      );
    }
  }

  Future<void> _openPdf(BuildContext context, String? url, String title) async {
    if (url != null && url.isNotEmpty) {
      try {
        final uri = Uri.parse(url);
        if (!uri.isAbsolute) {
          throw FormatException('Invalid URL format');
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfScreen(pdfUrl: url, title: title),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening PDF: ${e.toString()}')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF URL is not available')),
      );
    }
  }
}
