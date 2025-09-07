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
        body: const TabBarView(
          children: [
            Center(child: Text('Color Stories tab')), // TODO: Replace with actual content
            Center(child: Text('Palettes tab')),     // TODO: Replace with actual content
            Center(child: Text('Colors tab')),       // TODO: Replace with actual content
            Center(child: Text('Images tab')),       // TODO: Replace with actual content
          ],
        ),
      ),
    );
  }
}
