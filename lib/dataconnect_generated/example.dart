library dataconnect_generated;

import 'package:firebase_data_connect/firebase_data_connect.dart';
import 'dart:convert';

part 'create_color_palette.dart';

part 'get_public_color_palettes.dart';

part 'update_color_story.dart';

part 'list_my_color_stories.dart';

class ExampleConnector {
  CreateColorPaletteVariablesBuilder createColorPalette() {
    return CreateColorPaletteVariablesBuilder(
      dataConnect,
    );
  }

  GetPublicColorPalettesVariablesBuilder getPublicColorPalettes() {
    return GetPublicColorPalettesVariablesBuilder(
      dataConnect,
    );
  }

  UpdateColorStoryVariablesBuilder updateColorStory({
    required String id,
  }) {
    return UpdateColorStoryVariablesBuilder(
      dataConnect,
      id: id,
    );
  }

  ListMyColorStoriesVariablesBuilder listMyColorStories() {
    return ListMyColorStoriesVariablesBuilder(
      dataConnect,
    );
  }

  static ConnectorConfig connectorConfig = ConnectorConfig(
    'us-central1',
    'example',
    'colrvia5',
  );

  ExampleConnector({required this.dataConnect});
  static ExampleConnector get instance {
    return ExampleConnector(
        dataConnect: FirebaseDataConnect.instanceFor(
            connectorConfig: connectorConfig,
            sdkType: CallerSDKType.generated));
  }

  FirebaseDataConnect dataConnect;
}
