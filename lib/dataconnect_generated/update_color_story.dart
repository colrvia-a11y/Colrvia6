part of 'example.dart';

class UpdateColorStoryVariablesBuilder {
  String id;
  Optional<String> _description = Optional.optional(nativeFromJson, nativeToJson);

  final FirebaseDataConnect _dataConnect;  UpdateColorStoryVariablesBuilder description(String? t) {
   _description.value = t;
   return this;
  }

  UpdateColorStoryVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<UpdateColorStoryData> dataDeserializer = (dynamic json)  => UpdateColorStoryData.fromJson(jsonDecode(json));
  Serializer<UpdateColorStoryVariables> varsSerializer = (UpdateColorStoryVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<UpdateColorStoryData, UpdateColorStoryVariables>> execute() {
    return ref().execute();
  }

  MutationRef<UpdateColorStoryData, UpdateColorStoryVariables> ref() {
    UpdateColorStoryVariables vars= UpdateColorStoryVariables(id: id,description: _description,);
    return _dataConnect.mutation("UpdateColorStory", dataDeserializer, varsSerializer, vars);
  }
}

class UpdateColorStoryColorStoryUpdate {
  String id;
  UpdateColorStoryColorStoryUpdate.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  UpdateColorStoryColorStoryUpdate({
    required this.id,
  });
}

class UpdateColorStoryData {
  UpdateColorStoryColorStoryUpdate? colorStory_update;
  UpdateColorStoryData.fromJson(dynamic json):
  
  colorStory_update = json['colorStory_update'] == null ? null : UpdateColorStoryColorStoryUpdate.fromJson(json['colorStory_update']);

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (colorStory_update != null) {
      json['colorStory_update'] = colorStory_update!.toJson();
    }
    return json;
  }

  UpdateColorStoryData({
    this.colorStory_update,
  });
}

class UpdateColorStoryVariables {
  String id;
  late Optional<String>description;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  UpdateColorStoryVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']) {
  
  
  
    description = Optional.optional(nativeFromJson, nativeToJson);
    description.value = json['description'] == null ? null : nativeFromJson<String>(json['description']);
  
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    if(description.state == OptionalState.set) {
      json['description'] = description.toJson();
    }
    return json;
  }

  UpdateColorStoryVariables({
    required this.id,
    required this.description,
  });
}

