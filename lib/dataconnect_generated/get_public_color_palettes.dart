part of 'example.dart';

class GetPublicColorPalettesVariablesBuilder {
  final FirebaseDataConnect _dataConnect;
  GetPublicColorPalettesVariablesBuilder(
    this._dataConnect,
  );
  Deserializer<GetPublicColorPalettesData> dataDeserializer =
      (dynamic json) => GetPublicColorPalettesData.fromJson(jsonDecode(json));

  Future<QueryResult<GetPublicColorPalettesData, void>> execute() {
    return ref().execute();
  }

  QueryRef<GetPublicColorPalettesData, void> ref() {
    return _dataConnect.query(
        "GetPublicColorPalettes", dataDeserializer, emptySerializer, null);
  }
}

class GetPublicColorPalettesColorPalettes {
  String id;
  String name;
  String? description;
  GetPublicColorPalettesColorPalettes.fromJson(dynamic json)
      : id = nativeFromJson<String>(json['id']),
        name = nativeFromJson<String>(json['name']),
        description = json['description'] == null
            ? null
            : nativeFromJson<String>(json['description']);

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['name'] = nativeToJson<String>(name);
    if (description != null) {
      json['description'] = nativeToJson<String?>(description);
    }
    return json;
  }

  GetPublicColorPalettesColorPalettes({
    required this.id,
    required this.name,
    this.description,
  });
}

class GetPublicColorPalettesData {
  List<GetPublicColorPalettesColorPalettes> colorPalettes;
  GetPublicColorPalettesData.fromJson(dynamic json)
      : colorPalettes = (json['colorPalettes'] as List<dynamic>)
            .map((e) => GetPublicColorPalettesColorPalettes.fromJson(e))
            .toList();

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['colorPalettes'] = colorPalettes.map((e) => e.toJson()).toList();
    return json;
  }

  GetPublicColorPalettesData({
    required this.colorPalettes,
  });
}
