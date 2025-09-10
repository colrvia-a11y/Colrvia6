part of 'example.dart';

class CreateColorPaletteVariablesBuilder {
  
  final FirebaseDataConnect _dataConnect;
  CreateColorPaletteVariablesBuilder(this._dataConnect, );
  Deserializer<CreateColorPaletteData> dataDeserializer = (dynamic json)  => CreateColorPaletteData.fromJson(jsonDecode(json));
  
  Future<OperationResult<CreateColorPaletteData, void>> execute() {
    return ref().execute();
  }

  MutationRef<CreateColorPaletteData, void> ref() {
    
    return _dataConnect.mutation("CreateColorPalette", dataDeserializer, emptySerializer, null);
  }
}

class CreateColorPaletteColorPaletteInsert {
  String id;
  CreateColorPaletteColorPaletteInsert.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  CreateColorPaletteColorPaletteInsert({
    required this.id,
  });
}

class CreateColorPaletteData {
  CreateColorPaletteColorPaletteInsert colorPalette_insert;
  CreateColorPaletteData.fromJson(dynamic json):
  
  colorPalette_insert = CreateColorPaletteColorPaletteInsert.fromJson(json['colorPalette_insert']);

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['colorPalette_insert'] = colorPalette_insert.toJson();
    return json;
  }

  CreateColorPaletteData({
    required this.colorPalette_insert,
  });
}

