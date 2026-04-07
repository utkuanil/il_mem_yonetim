import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class PdfPreviewPage extends StatefulWidget {
  final String title;
  final String fileName;
  final Uint8List bytes;

  const PdfPreviewPage({
    super.key,
    required this.title,
    required this.fileName,
    required this.bytes,
  });

  @override
  State<PdfPreviewPage> createState() => _PdfPreviewPageState();
}

class _PdfPreviewPageState extends State<PdfPreviewPage> {
  String? _tempPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _writeToTemp();
  }

  Future<void> _writeToTemp() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${widget.fileName}');
    await file.writeAsBytes(widget.bytes, flush: true);
    if (mounted) setState(() => _tempPath = file.path);
  }

  Future<String> _savePdfToDevice() async {
    Directory baseDir;
    if (Platform.isAndroid) {
      baseDir = (await getExternalStorageDirectory()) ??
          await getApplicationDocumentsDirectory();
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }

    final reportsDir = Directory('${baseDir.path}/reports');
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }

    final file = File('${reportsDir.path}/${widget.fileName}');
    await file.writeAsBytes(widget.bytes, flush: true);
    return file.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'İndir',
            icon: _saving
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.download_outlined),
            onPressed: _saving
                ? null
                : () async {
              setState(() => _saving = true);
              try {
                final savedPath = await _savePdfToDevice();
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('PDF kaydedildi: $savedPath'),
                    action: SnackBarAction(
                      label: 'AÇ',
                      onPressed: () => OpenFilex.open(savedPath),
                    ),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              } finally {
                if (mounted) setState(() => _saving = false);
              }
            },
          ),
        ],
      ),
      body: _tempPath == null
          ? const Center(child: CircularProgressIndicator())
          : PDFView(
        filePath: _tempPath!,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
      ),
    );
  }
}
