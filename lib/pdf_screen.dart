import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class PdfScreen extends StatefulWidget {
  final String pdfUrl;

  const PdfScreen({Key? key, required this.pdfUrl}) : super(key: key);

  @override
  State<PdfScreen> createState() => _PdfScreenState();
}

class _PdfScreenState extends State<PdfScreen> {
  int? totalPages;
  int currentPage = 0;
  PDFViewController? controller;
  double _zoom = 1.0;
  bool isLoading = true;
  File? pdfFile;
  bool _isMounted = false;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _downloadAndLoadPdf(widget.pdfUrl);
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  Future<void> _downloadAndLoadPdf(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      final bytes = response.bodyBytes;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/temp_pdf.pdf');
      await file.writeAsBytes(bytes);

      if (_isMounted) {
        setState(() {
          pdfFile = file;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error downloading PDF: $e');
      if (_isMounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _zoomIn() {
    setState(() {
      _zoom = (_zoom * 1.2).clamp(1.0, 3.0);
      controller?.setPage(currentPage);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoom = (_zoom / 1.2).clamp(1.0, 3.0);
      controller?.setPage(currentPage);
    });
  }

  void _nextPage() {
    if (currentPage < (totalPages ?? 0) - 1) {
      controller?.setPage(currentPage + 1);
    }
  }

  void _previousPage() {
    if (currentPage > 0) {
      controller?.setPage(currentPage - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pdfUrl.split('/').last),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              // Implement print functionality
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildPdfView(),
    );
  }

  Widget _buildPdfView() {
    return Column(
      children: [
        Expanded(
          child: PDFView(
            filePath: pdfFile?.path,
            enableSwipe: true,
            swipeHorizontal: true,
            autoSpacing: false,
            pageFling: true,
            pageSnap: true,
            fitPolicy: FitPolicy.BOTH,
            onViewCreated: (PDFViewController pdfViewController) {
              controller = pdfViewController;
            },
            onPageChanged: (int? page, int? total) {
              if (_isMounted) {
                setState(() {
                  currentPage = page ?? 0;
                  totalPages = total;
                });
              }
            },
            onRender: (_pages) {
              if (_isMounted) {
                setState(() {
                  totalPages = _pages;
                });
              }
            },
            onError: (error) {
              print(error.toString());
            },
            onPageError: (page, error) {
              print('$page: ${error.toString()}');
            },
          ),
        ),
        _buildControlBar(),
      ],
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildPageControls(),
          _buildZoomControls(),
        ],
      ),
    );
  }

  Widget _buildPageControls() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _previousPage,
        ),
        Text('${currentPage + 1}/${totalPages ?? 0}'),
        IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: _nextPage,
        ),
      ],
    );
  }

  Widget _buildZoomControls() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.zoom_out),
          onPressed: _zoomOut,
        ),
        Text('${(_zoom * 100).toInt()}%'),
        IconButton(
          icon: const Icon(Icons.zoom_in),
          onPressed: _zoomIn,
        ),
      ],
    );
  }
}
