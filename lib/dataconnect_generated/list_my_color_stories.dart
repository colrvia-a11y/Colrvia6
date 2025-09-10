part of 'example.dart';

class ListMyColorStoriesVariablesBuilder {
  
  final FirebaseDataConnect _dataConnect;
  ListMyColorStoriesVariablesBuilder(this._dataConnect, );
  Deserializer<ListMyColorStoriesData> dataDeserializer = (dynamic json)  => ListMyColorStoriesData.fromJson(jsonDecode(json));
  
  Future<QueryResult<ListMyColorStoriesData, void>> execute() {
    return ref().execute();
  }

  QueryRef<ListMyColorStoriesData, void> ref() {
    
    return _dataConnect.query("ListMyColorStories", dataDeserializer, emptySerializer, null);
  }
}

class ListMyColorStoriesColorStories {
  String id;
  String title;
  String? description;
  ListMyColorStoriesColorStories.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']),
  title = nativeFromJson<String>(json['title']),
  description = json['description'] == null ? null : nativeFromJson<String>(json['description']);

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['title'] = nativeToJson<String>(title);
    if (description != null) {
      json['description'] = nativeToJson<String?>(description);
    }
    return json;
  }

  ListMyColorStoriesColorStories({
    required this.id,
    required this.title,
    this.description,
  });
}

class ListMyColorStoriesData {
  List<ListMyColorStoriesColorStories> colorStories;
  ListMyColorStoriesData.fromJson(dynamic json):
  
  colorStories = (json['colorStories'] as List<dynamic>)
        .map((e) => ListMyColorStoriesColorStories.fromJson(e))
        .toList();

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['colorStories'] = colorStories.map((e) => e.toJson()).toList();
    return json;
  }

  ListMyColorStoriesData({
    required this.colorStories,
  });
}

