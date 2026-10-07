import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'extractor.dart';
import 'store.dart';
import 'theme.dart';

/// Guided, non-tech friendly modal sheet to help average users obtain and configure
/// a free personal Google Gemini API key in 3 clear steps.
Future<bool?> showApiKeySetupSheet(BuildContext context, Store store) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ApiKeySetupSheet(store: store),
  );
}

class _ApiKeySetupSheet extends StatefulWidget {
  final Store store;
  const _ApiKeySetupSheet({required this.store});

  @override
  State<_ApiKeySetupSheet> createState() => _ApiKeySetupSheetState();
}

class _ApiKeySetupSheetState extends State<_ApiKeySetupSheet> with WidgetsBindingObserver {
  late final TextEditingController _controller;
  bool _testing = false;
  String? _statusMessage;
  bool? _statusOk;
  String? _detectedClipboardKey;
  bool _obscureText = true;

  static const String _aiStudioUrl = 'https://aistudio.google.com/app/apikey';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = TextEditingController(text: widget.store.userApiKey);
    _checkClipboard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.startsWith('AIza') && text.length >= 25 && text != _controller.text.trim()) {
        if (mounted) {
          setState(() {
            _detectedClipboardKey = text;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _openGoogleAiStudio() async {
    final uri = Uri.parse(_aiStudioUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(uri);
      } catch (_) {}
    }
  }

  Future<void> _verifyAndSave() async {
    final key = _controller.text.trim();
    if (key.isEmpty) {
      setState(() {
        _statusMessage = 'Please paste or enter your API key first.';
        _statusOk = false;
      });
      return;
    }

    setState(() {
      _testing = true;
      _statusMessage = null;
      _statusOk = null;
    });

    final res = await testApiKey(key);
    if (!mounted) return;

    if (res.ok) {
      await widget.store.setApiKey(key);
      setState(() {
        _testing = false;
        _statusMessage = 'Key verified successfully! All bills will now be read automatically.';
        _statusOk = true;
      });
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() {
        _testing = false;
        _statusMessage = res.message;
        _statusOk = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final hasCurrentKey = widget.store.userApiKey.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: Pal.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, bottomInset + 20),
      child: SingleChildScrollView(
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

            // Header
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Pal.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(CupertinoIcons.sparkles, color: Pal.blue, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Get Free AI Bill Scanner',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: Pal.ink,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Google provides a 100% free key for every Gmail account.',
                        style: TextStyle(fontSize: 12, color: Pal.muted),
                      ),
                    ],
                  ),
                ),
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
            const SizedBox(height: 18),

            // 3-Step Guided Flow Card
            LiquidGlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EASY 3-STEP SETUP',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Pal.muted,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Step 1
                  _StepRow(
                    stepNumber: '1',
                    title: 'Open Google AI Studio',
                    subtitle: 'Sign in with your personal Google / Gmail account.',
                    action: AppleBounce(
                      scaleFactor: 0.95,
                      onTap: _openGoogleAiStudio,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Pal.blue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Open Website',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(CupertinoIcons.arrow_up_right, color: Colors.white, size: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1, color: Color(0x12000000)),
                  ),

                  // Step 2
                  const _StepRow(
                    stepNumber: '2',
                    title: 'Tap "Create API key"',
                    subtitle: 'Click the blue "Create API key" button on Google\'s page and copy it.',
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1, color: Color(0x12000000)),
                  ),

                  // Step 3
                  const _StepRow(
                    stepNumber: '3',
                    title: 'Paste and Save Below',
                    subtitle: 'Paste your copied key into the box below and tap Verify.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Clipboard Detection Highlight Banner
            if (_detectedClipboardKey != null) ...[
              AppleBounce(
                scaleFactor: 0.98,
                onTap: () {
                  _controller.text = _detectedClipboardKey!;
                  setState(() => _detectedClipboardKey = null);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: Pal.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Pal.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.doc_on_clipboard_fill, color: Pal.green, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Copied API key detected!',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: Pal.green,
                              ),
                            ),
                            Text(
                              'Tap here to insert it automatically',
                              style: TextStyle(fontSize: 11, color: Pal.muted),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Pal.green,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Insert',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Input Field Container
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      obscureText: _obscureText,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        hintText: 'Paste key (starts with AIza...)',
                        hintStyle: const TextStyle(color: Pal.muted, fontSize: 14),
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureText ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                            size: 18,
                            color: Pal.muted,
                          ),
                          onPressed: () => setState(() => _obscureText = !_obscureText),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Paste from clipboard',
                    icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 20, color: Pal.blue),
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      final text = data?.text?.trim() ?? '';
                      if (text.isNotEmpty) {
                        _controller.text = text;
                        setState(() => _detectedClipboardKey = null);
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),

            // Live Verification Status Message
            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _statusOk == true
                      ? Pal.green.withValues(alpha: 0.12)
                      : Pal.brick.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _statusOk == true
                        ? Pal.green.withValues(alpha: 0.3)
                        : Pal.brick.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _statusOk == true
                          ? CupertinoIcons.checkmark_circle_fill
                          : CupertinoIcons.exclamationmark_triangle_fill,
                      color: _statusOk == true ? Pal.green : Pal.brick,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _statusOk == true ? Pal.green : Pal.brick,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Save and Verify Action Button
            AppleBounce(
              scaleFactor: 0.97,
              onTap: _testing ? null : _verifyAndSave,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Pal.blue,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Pal.blue.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: _testing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.checkmark_seal_fill, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Verify & Save Key',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),

            if (hasCurrentKey) ...[
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () async {
                    await widget.store.setApiKey('');
                    _controller.clear();
                    if (context.mounted) Navigator.pop(context, false);
                  },
                  child: const Text(
                    'Remove custom key and use default',
                    style: TextStyle(color: Pal.brick, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String stepNumber;
  final String title;
  final String subtitle;
  final Widget? action;

  const _StepRow({
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Pal.blue.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              stepNumber,
              style: const TextStyle(
                color: Pal.blue,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Pal.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Pal.muted, height: 1.3),
              ),
              if (action != null) ...[
                const SizedBox(height: 8),
                action!,
              ],
            ],
          ),
        ),
      ],
    );
  }
}
