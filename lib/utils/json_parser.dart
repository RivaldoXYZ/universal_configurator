import 'dart:convert';

class ConfigParameter {
  String param;
  String desc;
  String type;
  String value;

  ConfigParameter({required this.param, required this.desc, required this.type, required this.value});

  factory ConfigParameter.fromJson(Map<String, dynamic> json) => ConfigParameter(
    param: json['param'],
    desc: json['desc'],
    type: json['type'],
    value: json['value'],
  );

  Map<String, dynamic> toJson() => {
    'param': param,
    'desc': desc,
    'type': type,
    'value': value,
  };
}

List<ConfigParameter> parseConfig(String jsonStr) {
  final parsed = json.decode(jsonStr).cast<Map<String, dynamic>>();
  return parsed.map<ConfigParameter>((json) => ConfigParameter.fromJson(json)).toList();
}
