import 'package:flutter/material.dart';

/// Interview entry screen that lets users choose between
/// a voice or text based interview experience.
///
/// This screen matches the Colrvia peach–cream gradient style and
/// uses Material 3 components for its calls to action.
class InterviewHomeScreen extends StatelessWidget {
  const InterviewHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background gradient with optional grain texture.
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF2B897), Color(0xFFFFF8F2)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  Text(
                    "Let’s design your perfect palette.",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Answer a few questions — Via turns your style, lighting, and space into a color story you’ll love.",
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    icon: const Icon(Icons.mic),
                    label: const Text("Start with Via (Voice)"),
                    onPressed: () {
                      Navigator.pushNamed(context, '/interview/voice-setup');
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: const Color(0xFFF2B897),
                      foregroundColor: Colors.black,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/interview/text');
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: const Text("Type your answers"),
                  ),
                  const SizedBox(height: 24),
                  ExpansionTile(
                    title: const Text("How it works"),
                    children: [
                      const ListTile(title: Text("1. Chat for a few minutes.")),
                      const ListTile(
                          title: Text(
                              "2. We gather room, light, and style details.")),
                      const ListTile(
                          title: Text(
                              "3. Get your personalized palette plan.")),
                      ListTile(
                        title: const Text(
                          "Privacy & mic permissions",
 style: TextStyle(color: Colors.blue),
                        ),
                        onTap: () {
                          // TODO: Implement privacy link
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      "~6–8 min • You can pause anytime • Switch modes later",
                      style: Theme.of(context).textTheme.labelMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
