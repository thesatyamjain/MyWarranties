import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_filex/open_filex.dart';
import 'package:pdfx/pdfx.dart' as px;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'api_key_guide.dart';
import 'batch_queue.dart';
import 'extractor.dart';
import 'models.dart';
import 'resolver.dart';
import 'store.dart';
import 'theme.dart';

/// Screens 3-5: add bill, processing, review and confirm.
Future<void> startAddFlow(BuildContext context, Store store) async {
  final src = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _AddBillSheet(),
  );
  if (src == null || !context.mounted) return;

  if (src == 'manual') {
    final tempDir = await getTemporaryDirectory();
    final placeholder = File('${tempDir.path}/manual_bill_placeholder.jpg');
    if (!await placeholder.exists()) {
      final jpgBytes = base64Decode(
          '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=');
      await placeholder.writeAsBytes(jpgBytes);
    }
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          store: store,
          file: placeholder,
          ex: Extraction({'items': [{}]}),
        ),
      ),
    );
    return;
  }

  final picker = ImagePicker();
  final List<String> paths;
  if (src == 'pdf') {
    final r = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    paths = [for (final f in r) if (f.path != null) f.path!];
  } else if (src == 'gallery') {
    final multi = await picker.pickMultiImage(maxWidth: 1800, imageQuality: 80);
    paths = [for (final x in multi) x.path];
  } else {
    // Multi-page camera scanning: allows capturing multiple pages of a physical bill
    final captured = <String>[];
    while (true) {
      final x = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1800,
        imageQuality: 80,
      );
      if (x != null) {
        captured.add(x.path);
      } else {
        // User tapped cancel on camera
        break;
      }

      // If user captured 1+ pages, ask if there is another page or if they are done
      if (!context.mounted) break;
      final addMore = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(captured.length == 1 ? 'Page 1 Photo Taken' : '${captured.length} Pages Captured'),
          content: Text(
            captured.length == 1
                ? 'Does your bill have another page or a backside (warranty terms, IMEI, or shop stamp)?'
                : 'Captured ${captured.length} pages. Add another page or finish and save?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(captured.length == 1 ? 'Done, Save Bill' : 'Done (${captured.length} pages)'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(CupertinoIcons.camera, size: 16),
              label: const Text('Add Another Page'),
            ),
          ],
        ),
      );

      if (addMore != true) break;
    }

    if (captured.isEmpty) return;

    if (captured.length == 1) {
      paths = [captured.first];
    } else {
      // Multiple pages captured: stitch them together into a unified multi-page PDF document
      final doc = pw.Document();
      for (final imgPath in captured) {
        final imgBytes = await File(imgPath).readAsBytes();
        final pwImg = pw.MemoryImage(imgBytes);
        doc.addPage(
          pw.Page(
            margin: const pw.EdgeInsets.all(12),
            build: (_) => pw.Center(child: pw.Image(pwImg, fit: pw.BoxFit.contain)),
          ),
        );
      }
      final tempDir = await getTemporaryDirectory();
      final pdfFile = File('${tempDir.path}/scanned_bill_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await pdfFile.writeAsBytes(await doc.save());
      paths = [pdfFile.path];
    }
  }

  if (paths.isEmpty) return;

  // PRD F2: If multiple files selected (2 to 20 bills), process through background Batch Review Queue
  if (paths.length > 1) {
    if (!context.mounted) return;
    await BatchQueueController.instance.enqueueFiles(paths, store);
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BatchQueueScreen(store: store),
      ),
    );
    return;
  }

  // Single file: direct instant ProcessingScreen
  final p = paths.first;
  if (!context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ProcessingScreen(store: store, file: File(p)),
    ),
  );
}

class _AddBillSheet extends StatelessWidget {
  const _AddBillSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Pal.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle pill
          Center(
            child: Container(
              width: 36,
              height: 4.5,
              decoration: BoxDecoration(
                color: Pal.line.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header with title and dismiss button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add a Bill',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        height: 1.1,
                        color: Pal.ink,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Auto-reads product name, purchase date & warranty end date.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Pal.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: 'Close',
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Pal.line.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.xmark, size: 13, color: Pal.muted),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. Hero Primary Action: Camera Scanner
          _BentoTile(
            title: 'Take Photo of Bill',
            subtitle: 'Camera scans bill, receipt or warranty card',
            badge: 'Fast & Easy',
            icon: CupertinoIcons.camera_fill,
            iconBg: Pal.blue.withValues(alpha: 0.12),
            iconColor: Pal.blue,
            onTap: () => Navigator.pop(context, 'camera'),
          ),
          const SizedBox(height: 12),

          // 2. Secondary Bento Grid (Gallery & PDF)
          Row(
            children: [
              Expanded(
                child: _BentoSquareTile(
                  title: 'Photo Gallery',
                  subtitle: 'Select from photos',
                  icon: CupertinoIcons.photo_on_rectangle,
                  iconBg: const Color(0xFF5856D6).withValues(alpha: 0.12),
                  iconColor: const Color(0xFF5856D6),
                  onTap: () => Navigator.pop(context, 'gallery'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BentoSquareTile(
                  title: 'PDF / Files',
                  subtitle: 'Amazon, Flipkart invoices',
                  icon: CupertinoIcons.doc_text_fill,
                  iconBg: const Color(0xFF0071A4).withValues(alpha: 0.12),
                  iconColor: const Color(0xFF0071A4),
                  onTap: () => Navigator.pop(context, 'pdf'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Tertiary Action: Direct Manual Entry
          Material(
            color: Pal.card,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => Navigator.pop(context, 'manual'),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Pal.line.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(CupertinoIcons.square_pencil, size: 16, color: Pal.ink),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enter details manually',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Pal.ink,
                            ),
                          ),
                          Text(
                            'Add product without a bill photo',
                            style: TextStyle(
                              fontSize: 12,
                              color: Pal.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      CupertinoIcons.chevron_forward,
                      size: 14,
                      color: Pal.muted.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BentoTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;

  const _BentoTile({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Pal.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              color: Pal.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: iconColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Pal.muted),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_forward,
                size: 15,
                color: Pal.muted.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BentoSquareTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;

  const _BentoSquareTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Pal.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: Pal.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11.5, color: Pal.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProcessingScreen extends StatefulWidget {
  final Store store;
  final File file;
  const ProcessingScreen({super.key, required this.store, required this.file});
  @override
  State<ProcessingScreen> createState() => _ProcessingState();
}

class _ProcessingState extends State<ProcessingScreen> with SingleTickerProviderStateMixin {
  String? error;
  bool notBill = false;
  late AnimationController _scanController;
  int _stepIndex = 0;
  Timer? _stepTimer;
  px.PdfPageImage? _pdfThumbnail;

  static const _telemetrySteps = [
    (
      icon: CupertinoIcons.viewfinder,
      title: 'Scanning optical document layout...',
      subtitle: 'Analyzing clarity and detecting page boundaries'
    ),
    (
      icon: CupertinoIcons.doc_text_search,
      title: 'Extracting invoice & transaction details...',
      subtitle: 'Reading store, date, receipt ID & tax breakdown'
    ),
    (
      icon: CupertinoIcons.cube_box,
      title: 'Detecting products & hardware models...',
      subtitle: 'Identifying line items, models and serial numbers'
    ),
    (
      icon: CupertinoIcons.sparkles,
      title: 'Consulting Gemini AI warranty intelligence...',
      subtitle: 'Matching official manufacturer coverage policies'
    ),
  ];

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _stepTimer = Timer.periodic(const Duration(milliseconds: 2000), (timer) {
      if (mounted && error == null && !notBill) {
        setState(() {
          _stepIndex = (_stepIndex + 1) % _telemetrySteps.length;
        });
      }
    });

    if (isPdf(widget.file.path)) {
      _loadPdfThumbnail();
    }

    _run();
  }

  Future<void> _loadPdfThumbnail() async {
    try {
      final doc = await px.PdfDocument.openFile(widget.file.path);
      final page = await doc.getPage(1);
      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: px.PdfPageImageFormat.jpeg,
      );
      await page.close();
      await doc.close();
      if (mounted && pageImage != null) {
        setState(() {
          _pdfThumbnail = pageImage;
        });
      }
    } catch (e) {
      debugPrint('Error rasterizing PDF preview: $e');
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    _stepTimer?.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() => error = null);
    try {
      final ex = await extractBill(widget.file, apiKey: widget.store.userApiKey);
      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => ReviewScreen(store: widget.store, file: widget.file, ex: ex)));
    } on NotABill {
      if (mounted) setState(() => notBill = true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  void _manualEntry() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          store: widget.store,
          file: widget.file,
          ex: Extraction({'items': [{}]}),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final failed = error != null || notBill;
    final currentStep = _telemetrySteps[_stepIndex];

    return DecoratedBox(
      decoration: glassBackdrop,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(CupertinoIcons.xmark, color: Pal.ink, size: 20),
            tooltip: 'Cancel',
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (!failed)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton(
                  onPressed: _manualEntry,
                  child: const Text('Manual Entry', style: TextStyle(color: Pal.blue, fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              children: [
                const Spacer(),

                // 1. Interactive Optical Document Scanner with Laser Beam
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Ambient diffuse glow
                    Container(
                      width: 250,
                      height: 290,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: failed
                                ? Pal.brick.withValues(alpha: 0.18)
                                : Pal.blue.withValues(alpha: 0.22),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    ),

                    // Document frame
                    LiquidGlassCard(
                      radius: 22,
                      padding: const EdgeInsets.all(8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            // Bill Image / PDF preview
                            SizedBox(
                              width: 240,
                              height: 280,
                              child: isPdf(widget.file.path)
                                  ? (_pdfThumbnail != null
                                      ? Image.memory(
                                          _pdfThumbnail!.bytes,
                                          fit: BoxFit.cover,
                                          width: 240,
                                          height: 280,
                                        )
                                      : Container(
                                          color: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 64,
                                                height: 64,
                                                decoration: BoxDecoration(
                                                  color: Pal.blue.withValues(alpha: 0.12),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Center(
                                                  child: Icon(CupertinoIcons.doc_richtext, size: 34, color: Pal.blue),
                                                ),
                                              ),
                                              const SizedBox(height: 14),
                                              Text(
                                                widget.file.uri.pathSegments.last,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Pal.ink),
                                              ),
                                              const SizedBox(height: 4),
                                              const Text(
                                                'PDF Document',
                                                style: TextStyle(fontSize: 11, color: Pal.muted, fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                          ),
                                        ))
                                  : Image.file(
                                      widget.file,
                                      fit: BoxFit.cover,
                                      width: 240,
                                      height: 280,
                                    ),
                            ),

                            // Viewfinder HUD Corner brackets
                            if (!failed)
                              const Positioned.fill(
                                child: IgnorePointer(
                                  child: Padding(
                                    padding: EdgeInsets.all(8),
                                    child: CustomPaint(
                                      painter: _HudViewfinderPainter(accentColor: Pal.blue),
                                    ),
                                  ),
                                ),
                              ),

                            // Animated Glowing Laser Scan Beam
                            if (!failed)
                              AnimatedBuilder(
                                animation: _scanController,
                                builder: (context, _) {
                                  return Positioned(
                                    top: _scanController.value * 276,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      height: 4,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Pal.blue.withValues(alpha: 0.0),
                                            Pal.blue,
                                            const Color(0xFF64D2FF),
                                            Pal.blue,
                                            Pal.blue.withValues(alpha: 0.0),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Pal.blue.withValues(alpha: 0.8),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // 2. Active AI Telemetry Card or Failure Fallback
                if (!failed) ...[
                  LiquidGlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Pal.blue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(currentStep.icon, size: 18, color: Pal.blue),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: Text(
                                      currentStep.title,
                                      key: ValueKey(currentStep.title),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        letterSpacing: -0.2,
                                        color: Pal.ink,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: Text(
                                      currentStep.subtitle,
                                      key: ValueKey(currentStep.subtitle),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Pal.muted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Progress Step Dot Indicator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_telemetrySteps.length, (idx) {
                            final active = idx == _stepIndex;
                            final passed = idx < _stepIndex;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: active ? 24 : 7,
                              height: 6,
                              decoration: BoxDecoration(
                                color: active
                                    ? Pal.blue
                                    : (passed ? Pal.blue.withValues(alpha: 0.4) : Pal.line),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Failure state with clean recovery options
                  LiquidGlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 36, color: Pal.brick),
                        const SizedBox(height: 12),
                        Text(
                          notBill ? 'Document Not Recognized' : 'Could Not Extract Details',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: Pal.ink),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notBill
                              ? 'This image doesn\'t appear to be a retail invoice or cash receipt.'
                              : (error ?? 'Could not read document contents automatically.'),
                          style: const TextStyle(fontSize: 13, color: Pal.muted, height: 1.4),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        if (error?.toLowerCase().contains('api key') == true ||
                            error?.toLowerCase().contains('gemini') == true ||
                            error?.toLowerCase().contains('quota') == true) ...[
                          FilledButton.icon(
                            onPressed: () async {
                              final updated = await showApiKeySetupSheet(context, widget.store);
                              if (updated == true && mounted) {
                                _run();
                              }
                            },
                            icon: const Icon(CupertinoIcons.sparkles, size: 16),
                            label: const Text('Setup Free AI Key (1 Min)'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Pal.blue,
                              minimumSize: const Size.fromHeight(44),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Pal.r)),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Pal.r)),
                                ),
                                child: const Text('Try Again'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: _manualEntry,
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Pal.r)),
                                ),
                                child: const Text('Enter Manually'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HudViewfinderPainter extends CustomPainter {
  final Color accentColor;
  const _HudViewfinderPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accentColor.withValues(alpha: 0.85)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const arm = 18.0;

    // Top-Left
    canvas.drawLine(const Offset(0, arm), Offset.zero, paint);
    canvas.drawLine(Offset.zero, const Offset(arm, 0), paint);

    // Top-Right
    canvas.drawLine(Offset(size.width - arm, 0), Offset(size.width, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, arm), paint);

    // Bottom-Left
    canvas.drawLine(const Offset(0, arm), Offset(0, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(arm, size.height), paint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width - arm, size.height), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height - arm), Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Row {
  final String id = const Uuid().v4();
  bool track = true;
  final name = TextEditingController();
  final brand = TextEditingController();
  final model = TextEditingController();
  final serial = TextEditingController();
  final price = TextEditingController();
  String category = 'Other';
  List<Term> terms = [];
  bool confirmedEstimate = true;
  double conf = 1;
  bool isSearchingWarranty = false;
  String? aiSummary;
  String? searchError;
  bool get needsConfirm => false;
}

class ReviewScreen extends StatefulWidget {
  final Store store;
  final File file;
  final Extraction ex;
  const ReviewScreen({super.key, required this.store, required this.file, required this.ex});
  @override
  State<ReviewScreen> createState() => _ReviewState();
}

class _ReviewState extends State<ReviewScreen> {
  final seller = TextEditingController(), invoice = TextEditingController(),
      total = TextEditingController();
  DateTime? date;
  late final Map<String, double> conf;
  late final List<_Row> rows;
  bool saving = false;
  px.PdfPageImage? _pdfThumbnail;

  @override
  void initState() {
    super.initState();
    if (isPdf(widget.file.path)) {
      _loadPdfThumbnail();
    }
    final ex = widget.ex;
    conf = {for (final k in ['seller', 'invoice_no', 'purchase_date', 'total_amount']) k: ex.conf(k)};
    final manual = ex.raw.isEmpty || ex.items.length == 1 && ex.items.first.isEmpty;
    if (manual) conf.updateAll((_, _) => 1); // nothing to doubt when the user types it
    seller.text = '${ex.val('seller') ?? ''}';
    invoice.text = '${ex.val('invoice_no') ?? ''}';
    total.text = '${ex.val('total_amount') ?? ''}';
    date = DateTime.tryParse('${ex.val('purchase_date')}');
    rows = [
      for (final i in ex.items)
        _Row()
          ..name.text = '${i['product_name'] ?? ''}'
          ..brand.text = '${i['brand'] ?? ''}'
          ..model.text = '${i['model'] ?? ''}'
          ..serial.text = '${i['serial_no'] ?? ''}'
          ..price.text = '${i['price'] ?? ''}'
          ..conf = manual ? 1 : (i['confidence'] as num?)?.toDouble() ?? 0
          ..category = guessCategory('${i['product_name'] ?? ''}')
          ..aiSummary = (i['warranty_summary'] as String?)?.isNotEmpty == true
              ? i['warranty_summary'] as String
              : null
          ..terms = [
            for (final t in (i['standard_warranty_terms'] as List? ?? []))
              if (t is Map && t['label'] != null && t['months'] != null)
                Term(
                  '${t['label']}',
                  (t['months'] as num).toInt(),
                  t['source'] == 'bill'
                      ? TermSource.bill
                      : (t['source'] == 'brand' ? TermSource.brand : TermSource.aiSearch),
                ),
            if ((i['standard_warranty_terms'] as List? ?? []).isEmpty)
              ...parsePrinted(i['printed_warranty'] as String?),
          ]
    ];
    if (rows.isEmpty) {
      rows.add(_Row());
    }

    // Auto-search via AI for products that don't yet have verified terms from bill/AI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoSearchWarranties();
    });
  }

  void _autoSearchWarranties() {
    for (final r in rows) {
      final isGeneric = r.terms.length <= 1 &&
          (r.terms.isEmpty ||
              r.terms.first.label.toLowerCase() == 'comprehensive' ||
              r.terms.first.label.toLowerCase() == 'product');
      if ((r.terms.isEmpty || r.aiSummary == null || isGeneric) &&
          (r.name.text.trim().isNotEmpty || r.brand.text.trim().isNotEmpty)) {
        _searchRowWarranty(r);
      }
    }
  }

  Future<void> _searchRowWarranty(_Row r) async {
    final name = r.name.text.trim();
    final brand = r.brand.text.trim();
    final model = r.model.text.trim();
    if (name.isEmpty && brand.isEmpty) {
      setState(() {
        r.searchError = 'Enter product name or brand to search official warranty.';
      });
      return;
    }

    setState(() {
      r.isSearchingWarranty = true;
      r.searchError = null;
    });

    try {
      final res = await queryProductWarrantyPolicy(
        productName: name,
        brand: brand,
        model: model,
        seller: seller.text.trim(),
        apiKey: widget.store.userApiKey,
      );
      if (mounted) {
        setState(() {
          if (res.terms.isNotEmpty) {
            r.terms = res.terms.map((t) {
              final label = (t['label'] ?? 'Product').toString();
              final months = (t['months'] as num?)?.toInt() ?? 12;
              final src = t['source'] == 'brand' ? TermSource.brand : TermSource.aiSearch;
              return Term(label, months, src);
            }).toList();
          }
          r.aiSummary = res.summary.isNotEmpty ? res.summary : null;
          r.isSearchingWarranty = false;
          r.searchError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          r.isSearchingWarranty = false;
          final cleanErr = e is HttpException
              ? 'Could not connect to warranty lookup service.'
              : e.toString().replaceAll('Exception: ', '').replaceAll('StateError: ', '').replaceAll('HttpException: ', '');
          r.searchError = cleanErr.contains('404') || cleanErr.contains('Http')
              ? 'Could not connect to warranty lookup service.'
              : cleanErr;
          if (r.terms.isEmpty) {
            final fallback = resolveWarranty(
              name: name,
              brand: brand,
              category: r.category,
            );
            if (fallback.isNotEmpty) {
              r.terms = fallback;
            }
          }
        });
      }
    }
  }

  String? get dateIssue => date == null ? 'Pick the purchase date' : validateDate(date!);
  bool get dupe => widget.store.hasInvoice(invoice.text.trim());
  bool get canSave =>
      !saving &&
      dateIssue == null &&
      seller.text.trim().isNotEmpty &&
      rows.any((r) => r.track) &&
      rows.where((r) => r.track).every((r) =>
          r.name.text.trim().isNotEmpty && r.terms.isNotEmpty && !r.isSearchingWarranty);

  Future<void> _save() async {
    setState(() => saving = true);
    final billId = const Uuid().v4();
    final img = await widget.store.saveImage(widget.file, billId);
    final bill = Bill(billId, img.path, seller.text.trim(), invoice.text.trim(), date!,
        double.tryParse(total.text) ?? 0, 'INR');
    final items = [
      for (final r in rows.where((r) => r.track))
        Item(r.id, billId, r.name.text.trim(), r.brand.text.trim(), r.model.text.trim(),
            r.serial.text.trim(), r.category, double.tryParse(r.price.text) ?? 0,
            date! /* clock starts at the bill's purchase date */, r.terms)
    ];
    await widget.store.add(bill, items);
    if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
  }

  Future<void> _loadPdfThumbnail() async {
    try {
      final doc = await px.PdfDocument.openFile(widget.file.path);
      final page = await doc.getPage(1);
      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: px.PdfPageImageFormat.jpeg,
      );
      await page.close();
      await doc.close();
      if (mounted && pageImage != null) {
        setState(() {
          _pdfThumbnail = pageImage;
        });
      }
    } catch (e) {
      debugPrint('Error rasterizing PDF preview in review: $e');
    }
  }

  void _openInvoicePreview() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: LiquidGlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(CupertinoIcons.doc_text_viewfinder, size: 18, color: Pal.blue),
                      SizedBox(width: 8),
                      Text(
                        'Original Document',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Pal.ink),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Pal.muted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(Pal.r),
                child: SizedBox(
                  height: MediaQuery.of(ctx).size.height * 0.65,
                  width: double.infinity,
                  child: isPdf(widget.file.path)
                      ? (_pdfThumbnail != null
                          ? Stack(
                              children: [
                                Positioned.fill(
                                  child: InteractiveViewer(
                                    minScale: 0.8,
                                    maxScale: 5.0,
                                    child: Image.memory(
                                      _pdfThumbnail!.bytes,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 12,
                                  right: 12,
                                  bottom: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.92),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Pal.line),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                widget.file.uri.pathSegments.last,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Pal.ink),
                                              ),
                                              const Text(
                                                'Pinch to zoom page 1',
                                                style: TextStyle(fontSize: 10, color: Pal.muted),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Pal.blue,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            visualDensity: VisualDensity.compact,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          icon: const Icon(CupertinoIcons.arrow_up_right_square, size: 14),
                                          label: const Text('Open Full PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                          onPressed: () async {
                                            try {
                                              final res = await OpenFilex.open(widget.file.path);
                                              if (res.type != ResultType.done) {
                                                final uri = Uri.file(widget.file.path);
                                                if (await canLaunchUrl(uri)) {
                                                  await launchUrl(uri);
                                                }
                                              }
                                            } catch (e) {
                                              debugPrint('Error opening invoice PDF: $e');
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              color: Pal.paper,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 84,
                                    height: 84,
                                    decoration: BoxDecoration(
                                      color: Pal.blue.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Icon(CupertinoIcons.doc_richtext, size: 44, color: Pal.blue),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    widget.file.uri.pathSegments.last,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: Pal.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'PDF invoice document (${(widget.file.lengthSync() / 1024).toStringAsFixed(1)} KB)',
                                    style: const TextStyle(fontSize: 12, color: Pal.muted),
                                  ),
                                  const SizedBox(height: 28),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Pal.blue,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size.fromHeight(48),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(CupertinoIcons.arrow_up_right_square, size: 18),
                                    label: const Text(
                                      'Open PDF in System Viewer',
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                    onPressed: () async {
                                      try {
                                        final res = await OpenFilex.open(widget.file.path);
                                        if (res.type != ResultType.done) {
                                          final uri = Uri.file(widget.file.path);
                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(uri);
                                          }
                                        }
                                      } catch (e) {
                                        debugPrint('Error opening invoice PDF: $e');
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ))
                      : InteractiveViewer(
                          minScale: 0.8,
                          maxScale: 5.0,
                          child: Image.file(widget.file, fit: BoxFit.contain),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: glassBackdrop,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Review & Confirm'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          actions: [
            IconButton(
              icon: const Icon(CupertinoIcons.doc_text_viewfinder, color: Pal.blue),
              tooltip: 'Inspect original bill',
              onPressed: _openInvoicePreview,
            ),
          ],
        ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
              onPressed: canSave ? _save : null,
              child: Text(saving
                  ? 'Saving to Vault...'
                  : (rows.any((r) => r.track && r.isSearchingWarranty)
                      ? 'AI searching warranty...'
                      : 'Save and start countdown'))),
        ),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
        // 1. Interactive Original Invoice Inspector Card
        _InvoiceDocumentPeek(
          file: widget.file,
          pdfThumbnail: _pdfThumbnail,
          onInspect: _openInvoicePreview,
        ),

        // 2. Interactive Live Countdown Simulator Hero
        _LiveCountdownHero(
          purchaseDate: date,
          rows: rows,
          store: widget.store,
        ),

        Text('Check what we found', style: t.headlineSmall),
        const SizedBox(height: 4),
        Text('Fields marked amber were hard to read. Edit anything before saving.',
            style: t.bodyMedium),
        if (dupe)
          _Banner('A bill with this invoice number is already saved.'),
        const SizedBox(height: 16),
        _Field('Seller', seller, conf['seller']!, onChanged: () => setState(() {})),
        _Field('Invoice number', invoice, conf['invoice_no']!, onChanged: () => setState(() {})),
        _DateField(
            store: widget.store,
            date: date,
            conf: conf['purchase_date']!,
            issue: dateIssue,
            onPick: (d) => setState(() => date = d)),
        _Field('Total amount (INR)', total, conf['total_amount']!, number: true),
        const SizedBox(height: 12),
        Text('Products on this bill', style: t.titleMedium),
        const SizedBox(height: 8),
        for (final r in rows)
          _ItemCard(
            r,
            onChanged: () => setState(() {}),
            onSearchWarranty: _searchRowWarranty,
            onRemove: rows.length > 1 ? () => setState(() => rows.remove(r)) : null,
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                rows.add(_Row());
              });
            },
            icon: const Icon(CupertinoIcons.plus, size: 16),
            label: const Text('Add another product to this bill'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Pal.ink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Pal.r)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              InkWell(
                onTap: () {
                  final query = rows.isNotEmpty && rows.first.brand.text.trim().isNotEmpty
                      ? '${rows.first.brand.text.trim()} warranty terms and conditions'
                      : 'standard manufacturer warranty terms and conditions India';
                  launchUrl(
                    Uri.https('www.google.com', '/search', {'q': query}),
                    mode: LaunchMode.externalApplication,
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Terms & conditions',
                        style: t.bodySmall?.copyWith(
                          color: Pal.blue,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: Pal.blue,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(CupertinoIcons.arrow_up_right, size: 11, color: Pal.blue),
                    ],
                  ),
                ),
              ),
              Text(' may apply to every warranty.', style: t.bodySmall),
            ],
          ),
        ),
      ]),
    ));
  }
}

class _Banner extends StatelessWidget {
  final String text;
  const _Banner(this.text);
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Pal.amberBg, borderRadius: BorderRadius.circular(Pal.r)),
        child: Text(text, style: const TextStyle(color: Pal.amber)),
      );
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController c;
  final double conf;
  final bool number;
  final VoidCallback? onChanged;
  final ValueChanged<String>? onSubmitted;
  const _Field(this.label, this.c, this.conf, {this.number = false, this.onChanged, this.onSubmitted});
  @override
  Widget build(BuildContext context) {
    final low = conf < 0.8;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        onChanged: (_) => onChanged?.call(),
        onSubmitted: onSubmitted,
        keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : null,
        decoration: lowDecoration(label, low),
      ),
    );
  }
}

InputDecoration lowDecoration(String label, bool low) => InputDecoration(
      labelText: label,
      helperText: low ? 'Low confidence, please check' : null,
      helperStyle: const TextStyle(color: Pal.amber),
      enabledBorder: low
          ? OutlineInputBorder(
              borderRadius: BorderRadius.circular(Pal.r),
              borderSide: const BorderSide(color: Pal.amber, width: 1.6))
          : null,
    );

class _DateField extends StatelessWidget {
  final Store store;
  final DateTime? date;
  final double conf;
  final String? issue;
  final ValueChanged<DateTime> onPick;
  const _DateField({required this.store, required this.date, required this.conf, required this.issue, required this.onPick});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(Pal.r),
          onTap: () async {
            final now = DateTime.now();
            final d = await showDatePicker(
                context: context,
                initialDate: date ?? now,
                firstDate: DateTime(now.year - 10),
                lastDate: now);
            if (d != null) onPick(d);
          },
          child: InputDecorator(
            decoration: lowDecoration('Purchase date (DD/MM/YY)', conf < 0.8)
                .copyWith(errorText: issue),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date == null ? 'Select date (DD/MM/YY)' : store.formatDate(date!),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: date != null ? FontWeight.w600 : FontWeight.w400,
                    color: date != null ? Pal.ink : Pal.muted,
                  ),
                ),
                const Icon(CupertinoIcons.calendar, size: 18, color: Pal.muted),
              ],
            ),
          ),
        ),
      );
}

class _ItemCard extends StatefulWidget {
  final _Row r;
  final VoidCallback onChanged;
  final Future<void> Function(_Row) onSearchWarranty;
  final VoidCallback? onRemove;
  const _ItemCard(
    this.r, {
    required this.onChanged,
    required this.onSearchWarranty,
    this.onRemove,
  });
  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  _Row get r => widget.r;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _changed() {
    widget.onChanged();
    setState(() {});
  }

  void _onNameOrBrandChanged() {
    _changed();
    if (r.terms.isEmpty && (r.name.text.trim().length >= 3 || r.brand.text.trim().length >= 3)) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 1400), () {
        if (mounted && r.terms.isEmpty && !r.isSearchingWarranty) {
          widget.onSearchWarranty(r);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LiquidGlassCard(
        radius: 16,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Checkbox(
            value: r.track,
            onChanged: (v) {
              r.track = v ?? true;
              _changed();
            },
          ),
          Expanded(
            child: r.track
                ? Text('Track this product', style: t.titleSmall)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.name.text.trim().isNotEmpty
                            ? r.name.text.trim()
                            : (r.brand.text.trim().isNotEmpty
                                ? '${r.brand.text.trim()} Product'
                                : 'Excluded Product'),
                        style: t.titleSmall?.copyWith(
                          color: Pal.muted,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Pal.muted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (r.brand.text.trim().isNotEmpty) ...[
                            Text(
                              r.brand.text.trim(),
                              style: const TextStyle(fontSize: 12, color: Pal.muted),
                            ),
                            const Text(' · ', style: TextStyle(color: Pal.muted, fontSize: 12)),
                          ],
                          const Text(
                            'Not tracked · Tap checkbox to include',
                            style: TextStyle(
                              fontSize: 12,
                              color: Pal.muted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          if (!r.track)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Excluded',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Pal.muted),
              ),
            ),
          if (widget.onRemove != null)
            IconButton(
              icon: const Icon(CupertinoIcons.trash, size: 16, color: Pal.muted),
              tooltip: 'Remove product from bill',
              onPressed: widget.onRemove,
            ),
        ]),
        if (r.track) ...[
          _Field('Product name', r.name, r.conf,
              onChanged: _onNameOrBrandChanged,
              onSubmitted: (_) {
                _debounce?.cancel();
                widget.onSearchWarranty(r);
              }),
          Row(children: [
            Expanded(
              child: _Field('Brand', r.brand, r.conf,
                  onChanged: _onNameOrBrandChanged,
                  onSubmitted: (_) {
                    _debounce?.cancel();
                    widget.onSearchWarranty(r);
                  }),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Field('Model', r.model, r.conf,
                  onChanged: _changed,
                  onSubmitted: (_) {
                    _debounce?.cancel();
                    widget.onSearchWarranty(r);
                  }),
            ),
          ]),
          _Field('Serial / IMEI (optional)', r.serial, 1),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('Warranty Period', style: t.titleSmall),
              const Spacer(),
              if (r.terms.isNotEmpty && r.aiSummary != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Pal.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 13, color: Pal.green),
                      SizedBox(width: 4),
                      Text(
                        'AI Verified',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Pal.green),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // 1. Loading state
          if (r.isSearchingWarranty)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Pal.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Pal.r),
                border: Border.all(color: Pal.blue.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Pal.blue),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'AI searching official manufacturer warranty for ${r.name.text.trim().isNotEmpty ? r.name.text.trim() : "product"}...',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Pal.blue),
                    ),
                  ),
                ],
              ),
            ),

          // 2. AI Summary Card (when found)
          if (!r.isSearchingWarranty && r.aiSummary != null && r.aiSummary!.trim().isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Pal.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Pal.r),
                border: Border.all(color: Pal.green.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified_outlined, size: 16, color: Pal.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Manufacturer Policy (AI Discovered):',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Pal.green),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          r.aiSummary!,
                          style: const TextStyle(fontSize: 12, color: Pal.ink, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // 3. Search Error / Notice (only show if policy was not already verified or terms empty)
          if (!r.isSearchingWarranty && r.searchError != null && r.searchError!.trim().isNotEmpty && (r.terms.isEmpty || r.aiSummary == null))
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Pal.amberBg,
                borderRadius: BorderRadius.circular(Pal.r),
                border: Border.all(color: Pal.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Pal.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.searchError!,
                      style: const TextStyle(fontSize: 12, color: Pal.ink, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),

          // 4. Empty Terms Prompt
          if (!r.isSearchingWarranty && r.terms.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'No preset warranty applied. Tap "AI Search Warranty" to discover official manufacturer coverage, or select a duration below.',
                style: TextStyle(fontSize: 12, color: Pal.muted, height: 1.3),
              ),
            ),

          // Quick Interactive Duration Presets
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('Quick set:', style: TextStyle(fontSize: 11, color: Pal.muted, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  for (final preset in const [
                    (label: '6 Mos', months: 6),
                    (label: '1 Year', months: 12),
                    (label: '2 Years', months: 24),
                    (label: '3 Years', months: 36),
                    (label: '5 Years', months: 60),
                  ]) ...[
                    AppleBounce(
                      onTap: () {
                        if (r.terms.isEmpty) {
                          r.terms.add(Term('Product', preset.months, TermSource.manual));
                        } else {
                          r.terms.first.months = preset.months;
                        }
                        _changed();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: (r.terms.isNotEmpty && r.terms.first.months == preset.months)
                              ? Pal.blue.withValues(alpha: 0.15)
                              : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (r.terms.isNotEmpty && r.terms.first.months == preset.months)
                                ? Pal.blue.withValues(alpha: 0.4)
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          preset.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: (r.terms.isNotEmpty && r.terms.first.months == preset.months)
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: (r.terms.isNotEmpty && r.terms.first.months == preset.months)
                                ? Pal.blue
                                : Pal.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 5. Existing Terms list
          for (final term in r.terms)
            _TermRow(
              term,
              onChanged: () {
                r.confirmedEstimate = false;
                _changed();
              },
              onRemove: () {
                r.terms.remove(term);
                _changed();
              },
            ),

          const SizedBox(height: 4),

          // 6. Action buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: r.isSearchingWarranty
                    ? null
                    : () {
                        _debounce?.cancel();
                        widget.onSearchWarranty(r);
                      },
                icon: r.isSearchingWarranty
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(CupertinoIcons.sparkles, size: 15, color: Pal.blue),
                label: Text(
                  r.terms.isEmpty ? 'AI Search Warranty' : 'Re-check AI Warranty',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Pal.blue),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Pal.blue.withValues(alpha: 0.1),
                  foregroundColor: Pal.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (label) {
                  r.terms.add(Term(label, 12, TermSource.manual));
                  _changed();
                },
                itemBuilder: (_) => [
                  for (final l in ['Extended warranty', 'AMC', 'Component', 'Product'])
                    PopupMenuItem(value: l, child: Text(l)),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.add, size: 15, color: Pal.muted),
                      const SizedBox(width: 4),
                      const Text('Add manual term', style: TextStyle(color: Pal.muted, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ]),
    ),
  );
  }
}

class _TermRow extends StatelessWidget {
  final Term term;
  final VoidCallback onChanged, onRemove;
  const _TermRow(this.term, {required this.onChanged, required this.onRemove});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(term.label, style: Theme.of(context).textTheme.bodyLarge),
              SourceChip(term.source),
            ]),
          ),
          IconButton(
              tooltip: 'Fewer months',
              onPressed: term.months > 1
                  ? () {
                      term.months--;
                      term.source = term.source == TermSource.bill ? TermSource.manual : term.source;
                      onChanged();
                    }
                  : null,
              icon: const Icon(CupertinoIcons.minus_circled)),
          SizedBox(
              width: 56,
              child: Text('${term.months} mo', textAlign: TextAlign.center)),
          IconButton(
              tooltip: 'More months',
              onPressed: () {
                term.months++;
                term.source = term.source == TermSource.bill ? TermSource.manual : term.source;
                onChanged();
              },
              icon: const Icon(CupertinoIcons.add_circled)),
          IconButton(
              tooltip: 'Remove term',
              onPressed: onRemove,
              icon: const Icon(CupertinoIcons.xmark)),
        ]),
      );
}

class SourceChip extends StatelessWidget {
  final TermSource s;
  const SourceChip(this.s, {super.key});
  @override
  Widget build(BuildContext context) {
    final isAi = s == TermSource.aiSearch;
    final isBill = s == TermSource.bill;
    final isBrand = s == TermSource.brand;

    final Color bg;
    final Color fg;
    final IconData icon;

    if (isBill) {
      bg = Pal.greenBg;
      fg = Pal.green;
      icon = CupertinoIcons.doc_checkmark_fill;
    } else if (isBrand) {
      bg = Pal.greenBg;
      fg = Pal.green;
      icon = CupertinoIcons.checkmark_seal_fill;
    } else if (isAi) {
      bg = Pal.blue.withValues(alpha: 0.12);
      fg = Pal.blue;
      icon = CupertinoIcons.sparkles;
    } else {
      bg = Pal.line.withValues(alpha: 0.5);
      fg = Pal.muted;
      icon = CupertinoIcons.pencil_ellipsis_rectangle;
    }

    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 4),
          Text(
            sourceLabel[s]!,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }
}

class _InvoiceDocumentPeek extends StatelessWidget {
  final File file;
  final px.PdfPageImage? pdfThumbnail;
  final VoidCallback onInspect;

  const _InvoiceDocumentPeek({
    required this.file,
    this.pdfThumbnail,
    required this.onInspect,
  });

  @override
  Widget build(BuildContext context) {
    final pdf = isPdf(file.path);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LiquidGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 44,
              height: 44,
              child: pdf
                  ? (pdfThumbnail != null
                      ? Image.memory(
                          pdfThumbnail!.bytes,
                          fit: BoxFit.cover,
                          width: 44,
                          height: 44,
                        )
                      : Container(
                          color: Pal.blue.withValues(alpha: 0.12),
                          alignment: Alignment.center,
                          child: const Icon(CupertinoIcons.doc_richtext, size: 24, color: Pal.blue),
                        ))
                  : Image.file(file, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(CupertinoIcons.doc_checkmark_fill, size: 13, color: Pal.green),
                    const SizedBox(width: 4),
                    Text(
                      pdf ? 'PDF INVOICE ATTACHED' : 'RECEIPT PHOTO ATTACHED',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: Pal.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  file.uri.pathSegments.last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Pal.ink),
                ),
              ],
            ),
          ),
          AppleBounce(
            onTap: onInspect,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Pal.blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(CupertinoIcons.viewfinder, size: 14, color: Pal.blue),
                  SizedBox(width: 4),
                  Text(
                    'Inspect',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Pal.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}

class _LiveCountdownHero extends StatelessWidget {
  final DateTime? purchaseDate;
  final List<_Row> rows;
  final Store store;

  const _LiveCountdownHero({
    required this.purchaseDate,
    required this.rows,
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    final start = purchaseDate ?? DateTime.now();
    final trackedRows = rows.where((r) => r.track && r.terms.isNotEmpty).toList();

    int maxMonths = 0;
    for (final r in trackedRows) {
      for (final t in r.terms) {
        if (t.months > maxMonths) maxMonths = t.months;
      }
    }

    final hasWarranty = maxMonths > 0;
    final endDate = hasWarranty ? addMonths(start, maxMonths) : start;
    final now = DateTime.now();
    final daysLeft = hasWarranty ? endDate.difference(now).inDays : 0;

    final Color badgeColor;
    final String statusLabel;
    final IconData statusIcon;

    if (!hasWarranty) {
      badgeColor = Pal.muted;
      statusLabel = 'Pending Warranty Terms';
      statusIcon = CupertinoIcons.clock;
    } else if (daysLeft > 30) {
      badgeColor = Pal.green;
      statusLabel = 'Active Coverage';
      statusIcon = CupertinoIcons.checkmark_shield_fill;
    } else if (daysLeft >= 0) {
      badgeColor = Pal.amber;
      statusLabel = 'Expiring Soon';
      statusIcon = CupertinoIcons.exclamationmark_shield_fill;
    } else {
      badgeColor = Pal.brick;
      statusLabel = 'Expired';
      statusIcon = CupertinoIcons.xmark_shield_fill;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(statusIcon, color: badgeColor, size: 17),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LIVE COUNTDOWN SIMULATOR',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: Pal.muted,
                        ),
                      ),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: badgeColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (hasWarranty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Pal.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$maxMonths Mos Coverage',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Pal.blue,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                hasWarranty ? '${daysLeft > 0 ? daysLeft : 0}' : '--',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                  height: 1.0,
                  color: Pal.ink,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                hasWarranty
                    ? (daysLeft == 1 ? 'day remaining' : 'days remaining')
                    : 'days remaining (set warranty terms below)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Pal.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Purchased: ${store.formatDate(start)}',
                style: const TextStyle(fontSize: 11, color: Pal.muted),
              ),
              Text(
                hasWarranty ? 'Valid until: ${store.formatDate(endDate)}' : 'No expiry set',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Pal.ink),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
}
