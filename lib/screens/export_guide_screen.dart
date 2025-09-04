import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../services/deliverable_service.dart';
import '../services/analytics_service.dart';
import '../services/journey/journey_service.dart';

class ExportGuideScreen extends StatefulWidget {
  final String projectId;
  const ExportGuideScreen({super.key, required this.projectId});

  @override
  State<ExportGuideScreen> createState() => _ExportGuideScreenState();
}

class _ExportGuideScreenState extends State<ExportGuideScreen> {
  String? _url;
  bool _loading = true;
  String? _error;
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.log('journey_step_view', {
      'step_id': JourneyService.instance.state.value?.currentStepId ?? 'guide.export',
    });
    _load();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
  }

  Future<void> _load() async {
    try {
      final url = await DeliverableService.instance.exportGuide(widget.projectId);
      if (mounted) {
        setState(() {
          _url = url;
          if (_url != null) {
            _controller.loadRequest(Uri.parse(_url!));
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Export Guide')),
        body: Center(child: Text(_error!)),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Guide'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share guide',
            onPressed: () => SharePlus.instance.share(ShareParams(text: _url!)),
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
