// lib/services/journey/default_color_story_v1.dart
import 'journey_models.dart';

final defaultColorStoryJourneyId = 'default_color_story_v1';

final defaultJourneySteps = <JourneyStep>[
  JourneyStep(
    id: 'interview.basic',
    title: 'Tell us about your space',
    type: StepType.questionnaire,
    screenRoute: null, // We navigate to InterviewScreen widget directly
    requires: [],
    next: [TransitionRule(condition: 'true', toStepId: 'roller.build')],
  ),
  JourneyStep(
    id: 'roller.build',
    title: 'Design your palette',
    type: StepType.tool,
    screenRoute: null,
    requires: [],
    next: [TransitionRule(condition: 'art.paletteId != null', toStepId: 'review.contrast')],
  ),
  JourneyStep(
    id: 'review.contrast',
    title: 'Check contrast & balance',
    type: StepType.review,
    screenRoute: null,
    requires: ['paletteId'],
    next: [TransitionRule(condition: 'true', toStepId: 'visualizer.photo')],
  ),
  JourneyStep(
    id: 'visualizer.photo',
    title: 'Choose a photo',
    type: StepType.tool,
    screenRoute: null,
    requires: [],
    next: [TransitionRule(condition: 'art.photoId != null', toStepId: 'visualizer.generate')],
  ),
  JourneyStep(
    id: 'visualizer.generate',
    title: 'See it on your walls',
    type: StepType.generate,
    screenRoute: null,
    requires: ['paletteId','photoId'],
    next: [TransitionRule(condition: 'art.renderIds.length > 0', toStepId: 'plan.create')],
  ),
  JourneyStep(
    id: 'plan.create',
    title: 'Create your room plan',
    type: StepType.generate,
    screenRoute: null,
    requires: ['paletteId'],
    next: [TransitionRule(condition: 'art.planId != null', toStepId: 'guide.export')],
  ),
  JourneyStep(
    id: 'guide.export',
    title: 'Export your Color Story Guide',
    type: StepType.export,
    screenRoute: null,
    requires: ['paletteId'],
    next: [],
  ),
];