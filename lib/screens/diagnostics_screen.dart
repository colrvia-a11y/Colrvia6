import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import '../services/diagnostics_service.dart';
import '../services/feature_flags.dart';
import '../services/analytics_service.dart';
import '../services/sync_queue_service.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  String _version = '';
  Map<String, bool> _flags = {};
  List<String> _events = [];
  List<Map<String, dynamic>> _pending = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await PackageInfo.fromPlatform();
    final pending = await SyncQueueService.instance.listPending();
    setState(() {
      _version = '${info.version} (${info.buildNumber})';
      _flags = FeatureFlags.instance.flagStates;
      _events = DiagnosticsService.instance.breadcrumbs;
      _pending = pending;
    });
    AnalyticsService.instance.logEvent('diagnostics_opened');
  }

  Future<void> _share() async {
    final report = await DiagnosticsService.instance.buildReport();
    await SharePlus.instance.share(ShareParams(text: report, subject: 'Diagnostics'));
    AnalyticsService.instance.logEvent('diagnostics_shared');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('App version'),
            subtitle: Text(_version),
          ),
          ListTile(
            title: const Text('Flags'),
            subtitle:
                Text(_flags.entries.map((e) => '${e.key}:${e.value}').join(', ')),
          ),
          ListTile(
            title: const Text('Breadcrumbs'),
            subtitle: Text(_events.join('\n')),
          ),
          ListTile(
            title: const Text('Pending sync items'),
            subtitle: Text(_pending.length.toString()),
          ),
          TextButton(onPressed: _share, child: const Text('Send diagnostics')),
        ],
      ),
    );
  }
}
