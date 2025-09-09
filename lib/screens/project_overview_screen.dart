import 'package:flutter/material.dart';
import '../models/project.dart';

/// Basic overview of a project with quick links to core tools.
class ProjectOverviewScreen extends StatelessWidget {
  final ProjectDoc project;
  const ProjectOverviewScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(project.title),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Color Stories'),
              Tab(text: 'Palettes'),
              Tab(text: 'Colors'),
              Tab(text: 'Images'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Color Stories tab: show linked color story id and funnel stage + vibe words
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Color Story', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(project.colorStoryId != null
                      ? 'Linked story: ${project.colorStoryId}'
                      : 'No color story generated yet.'),
                  const SizedBox(height: 12),
                  Text('Funnel stage: ${project.funnelStage.toString().split('.').last}'),
                  const SizedBox(height: 12),
                  if (project.vibeWords.isNotEmpty) ...[
                    Text('Vibe words:', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: project.vibeWords
                          .map((w) => Chip(label: Text(w)))
                          .toList(),
                    ),
                  ] else
                    const Text('No vibe words set.'),
                ],
              ),
            ),

            // Palettes tab: show active palette and palette count
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Palettes', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Total palettes: ${project.paletteIds.length}'),
                  const SizedBox(height: 12),
                  Text('Active palette: ${project.activePaletteId ?? 'None'}'),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: project.paletteIds.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, i) => ListTile(
                        leading: const Icon(Icons.palette),
                        title: Text('Palette ${i + 1}'),
                        subtitle: Text(project.paletteIds[i]),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Colors tab: placeholder list based on palette ids (no color model here)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Colors', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('This view will show colors from the project palettes.'),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: project.paletteIds.length,
                      itemBuilder: (context, i) => ListTile(
                        leading: CircleAvatar(child: Text('${i + 1}')),
                        title: Text('Colors for ${project.paletteIds[i]}'),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Images tab: show project metadata for images (no images model available)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Images', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Room type: ${project.roomType ?? 'Not specified'}'),
                  const SizedBox(height: 8),
                  Text('Style tag: ${project.styleTag ?? 'Not specified'}'),
                  const SizedBox(height: 12),
                  const Text('Imported images will appear here.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
