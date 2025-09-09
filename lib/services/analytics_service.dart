import 'dart:developer' as dev;

import '../models/project.dart';

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  List<Map<String, dynamic>> get recentEvents =>
      const []; // TODO: Implement event storage for diagnostics

  void logEvent(String name, [Map<String, Object?> params = const {}]) {
    try {
      dev.log('analytics:$name',
          name: 'analytics',
          error: null,
          stackTrace: null,
          sequenceNumber: null,
          time: DateTime.now(),
          zone: null);
      // Hook real analytics here later (Firebase, Segment, etc.)
    } catch (_) {
      // swallow
    }
  }

  void logAppOpen() {
    logEvent('app_open');
  }

  void logVisualizerOpenedFromStory(String projectId) {
    logEvent('visualizer_opened_from_story', {'project_id': projectId});
  }

  Future<void> painterPackExported(int pageCount, int colorCount) async {
    logEvent('painter_pack_exported',
        {'page_count': pageCount, 'color_count': colorCount});
  }

  void logStartFromExplore(String storyId, String projectId) {
    logEvent(
        'start_from_explore', {'story_id': storyId, 'project_id': projectId});
  }

  void logExportShared(String projectId) {
    logEvent('export_shared', {'project_id': projectId});
  }

  void compareOpened(int colorCount) {
    logEvent('compare_opened', {'color_count': colorCount});
  }

  void resumeLastClicked(String projectId, String screen) {
    logEvent(
        'resume_last_clicked', {'project_id': projectId, 'screen': screen});
  }

  Future<void> trackColorStoryOpen({
    required String storyId,
    required String slug,
    required String title,
    required List<String> themes,
    required List<String> families,
    required List<String> rooms,
    bool? isFeatured,
    String? source,
  }) async {
    logEvent('color_story_open', {
      'story_id': storyId,
      'slug': slug,
      'title': title,
      'themes': themes,
      'families': families,
      'rooms': rooms,
      'is_featured': isFeatured,
      'source': source,
    });
  }

  Future<void> trackColorStoryUseClick({
    required String storyId,
    required String slug,
    required String title,
    required int paletteColorCount,
    List<String>? colorHexCodes,
  }) async {
    logEvent('color_story_use_click', {
      'story_id': storyId,
      'slug': slug,
      'title': title,
      'palette_color_count': paletteColorCount,
      'color_hex_codes': colorHexCodes,
    });
  }

  Future<void> trackColorStorySaveClick({
    required String storyId,
    required String slug,
    required String title,
    bool? isAlreadySaved,
  }) async {
    logEvent('color_story_save_click', {
      'story_id': storyId,
      'slug': slug,
      'title': title,
      'is_already_saved': isAlreadySaved,
    });
  }

  Future<void> trackColorStoryShareClick({
    required String storyId,
    required String slug,
    required String title,
    String? shareMethod,
  }) async {
    logEvent('color_story_share_click', {
      'story_id': storyId,
      'slug': slug,
      'title': title,
      'share_method': shareMethod,
    });
  }

  Future<void> setCurrentScreen({
    required String screenName,
    required String screenClass,
  }) async {
    logEvent('screen_view', {
      'screen_name': screenName,
      'screen_class': screenClass,
    });
  }

  Future<void> trackExploreFilterChange({
    required List<String> selectedThemes,
    required List<String> selectedFamilies,
    required List<String> selectedRooms,
    required bool featuredOnly,
    required String changeType,
    int? totalResultCount,
  }) async {
    logEvent('explore_filter_change', {
      'selected_themes': selectedThemes,
      'selected_families': selectedFamilies,
      'selected_rooms': selectedRooms,
      'featured_only': featuredOnly,
      'change_type': changeType,
      'total_result_count': totalResultCount,
    });
  }

  Future<void> trackExploreSearch({
    required String searchQuery,
    int? resultCount,
    List<String>? activeFilters,
  }) async {
    logEvent('explore_search', {
      'search_query': searchQuery,
      'result_count': resultCount,
      'active_filters': activeFilters,
    });
  }

  Future<void> setUserProperty(String key, String value) async {
    logEvent('user_property_set', {
      'property_key': key,
      'property_value': value,
    });
  }

  void viaOpened(String contextLabel) {
    logEvent('via_opened', {'context': contextLabel});
  }

  void logScreenView(String screenName) {
    logEvent('screen_view', {'screen_name': screenName});
  }

  void logDashboardOpened() {
    logEvent('dashboard_opened');
  }

  void visualizerOpened() {
    logEvent('visualizer_opened');
  }

  void visualizerStroke({required String role}) {
    logEvent('visualizer_stroke', {'role': role});
  }

  void vizExport() {
    logEvent('viz_export');
  }

  void planGenerated(String projectId, String planId) {
    logEvent('plan_generated', {'project_id': projectId, 'plan_id': planId});
  }

  void planFallbackCreated() {
    logEvent('plan_fallback_created');
  }

  Future<void> voiceSessionStart({
    required String uid,
    required String model,
    required String voice,
    required String path,
  }) async {
    logEvent('voice_session_start', {
      'uid': uid,
      'model': model,
      'voice': voice,
      'path': path,
    });
  }

  Future<void> onboardingCompleted() async {
    logEvent('onboarding_completed');
  }

  void permissionMicrocopyShown(String type) {
    logEvent('permission_microcopy_shown', {'type': type});
  }

  void permissionRequested(String type) {
    logEvent('permission_requested', {'type': type});
  }

  void logProjectStageChanged(String projectId, FunnelStage stage) {
    final stageStr = stage.toString().split('.').last;
    logEvent(
        'project_stage_changed', {'project_id': projectId, 'stage': stageStr});
  }

  void logRollerSaveToProject(String projectId, String savedPaletteId) {
    logEvent('roller_save_to_project',
        {'project_id': projectId, 'saved_palette_id': savedPaletteId});
  }
}
