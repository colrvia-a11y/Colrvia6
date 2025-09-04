import 'package:flutter/material.dart';

import '../services/user_prefs_service.dart';
import '../services/analytics_service.dart';

/// Simple 3-page onboarding carousel shown on first run.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                children: const [
                  _OnboardPage(
                    title: 'Welcome to ColrVia',
                    text:
                        'Discover paint palettes and visualize them in your space.',
                  ),
                  _OnboardPage(
                    title: 'Create First',
                    text: 'Start by designing palettes then plan and visualize.',
                  ),
                  _OnboardPage(
                    title: 'Your Privacy',
                    text:
                        'We only access your camera or photos with your permission.',
                  ),
                ],
              ),
            ),
            if (_index == 2)
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _complete,
                  child: const Text('Get Started'),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (i) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _index == i
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _complete() async {
    await UserPrefsService.markFirstRunCompleted();
    await AnalyticsService.instance.onboardingCompleted();
    if (mounted) Navigator.pop(context);
  }
}

class _OnboardPage extends StatelessWidget {
  final String title;
  final String text;
  const _OnboardPage({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
