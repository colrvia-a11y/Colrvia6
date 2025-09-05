import 'package:flutter/material.dart';
import '../models/project.dart';
import 'roller_screen.dart' deferred as roller;
import 'color_plan_screen.dart' deferred as plan;
import 'visualizer_screen.dart' deferred as viz;
import '../services/analytics_service.dart';
import 'package:color_canvas/widgets/app_icon_button.dart' as app;

/// Basic overview of a project with quick links to core tools.
class ProjectOverviewScreen extends StatelessWidget {
  final ProjectDoc project;
  const ProjectOverviewScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    // Get palette IDs from project
  // Use the project's stored palette ids. If a ColorStory object is needed
  // later, it should be fetched separately; ProjectDoc only stores a colorStoryId.
  final List<String> paletteIds = project.paletteIds;
  final bool hasPalette = paletteIds.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(project.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: hasPalette
                    ? () {
                        Navigator.pushNamed(context, '/colorPlan', arguments: {
                          'projectId': project.id,
                          'paletteColorIds': paletteIds
                        });
                        AnalyticsService.instance.ctaPlanClicked('project_overview');
                      }
                    : null,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Make a Color Plan'),
              )),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(
                onPressed: () async {
                  await viz.loadLibrary();
                  if (!context.mounted) return;
                  Navigator.of(context).pushNamed('/visualizer', arguments: {
                    'projectId': project.id,
                    'paletteColorIds': paletteIds
                  });
                  AnalyticsService.instance.ctaVisualizeClicked('project_overview');
                },
                icon: const Icon(Icons.image),
                label: const Text('Visualize'),
              )),
              const SizedBox(width: 8),
              app.AppOutlineIconButton(
                icon: Icons.compare,
                color: Theme.of(context).colorScheme.onSurface,
                onPressed: hasPalette
                    ? () async {
                        await viz.loadLibrary();
                        if (!context.mounted) return;
                        Navigator.of(context).pushNamed('/compareColors', arguments: {
                          'projectId': project.id,
                          'paletteColorIds': paletteIds
                        });
                        AnalyticsService.instance.ctaCompareClicked('project_overview');
                      }
                    : null,
              ),
            ]),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Palette'),
            subtitle: const Text('Edit in Roller'),
            onTap: () async {
              await roller.loadLibrary();
              if (!context.mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => roller.RollerScreen(projectId: project.id)),
              );
            },
          ),
          ListTile(
            title: const Text('Color Plan'),
            onTap: () async {
              await plan.loadLibrary();
              if (!context.mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => plan.ColorPlanScreen(projectId: project.id)),
              );
            },
          ),
          ListTile(
            title: const Text('Visualizer'),
            onTap: () async {
              await viz.loadLibrary();
              if (!context.mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => viz.VisualizerScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
