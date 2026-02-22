/// Dart model for a Request saved in a Collection.
class RequestModel {
  final String id;
  final String name;
  final String method;
  final String url;
  final Map<String, String> headers;
  final Map<String, String> params;
  final dynamic body;
  final String bodyType; // none | json | form-data | raw
  final AuthConfig auth;
  final String? collectionId;
  final DateTime? createdAt;

  const RequestModel({
    required this.id,
    required this.name,
    required this.method,
    required this.url,
    this.headers = const {},
    this.params = const {},
    this.body,
    this.bodyType = 'none',
    this.auth = const AuthConfig(),
    this.collectionId,
    this.createdAt,
  });

  factory RequestModel.fromJson(Map<String, dynamic> json) => RequestModel(
        id: json['_id'] ?? json['id'] ?? '',
        name: json['name'] ?? '',
        method: json['method'] ?? 'GET',
        url: json['url'] ?? '',
        headers: _toStringMap(json['headers']),
        params: _toStringMap(json['params']),
        body: json['body'],
        bodyType: json['bodyType'] ?? 'none',
        auth: AuthConfig.fromJson(json['auth'] ?? {}),
        collectionId: json['collectionId'],
        createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'method': method,
        'url': url,
        'headers': headers,
        'params': params,
        'body': body,
        'bodyType': bodyType,
        'auth': auth.toJson(),
        if (collectionId != null) 'collectionId': collectionId,
      };

  RequestModel copyWith({
    String? name, String? method, String? url,
    Map<String, String>? headers, Map<String, String>? params,
    dynamic body, String? bodyType, AuthConfig? auth, String? collectionId,
  }) =>
      RequestModel(
        id: id,
        name: name ?? this.name,
        method: method ?? this.method,
        url: url ?? this.url,
        headers: headers ?? this.headers,
        params: params ?? this.params,
        body: body ?? this.body,
        bodyType: bodyType ?? this.bodyType,
        auth: auth ?? this.auth,
        collectionId: collectionId ?? this.collectionId,
        createdAt: createdAt,
      );

  static Map<String, String> _toStringMap(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map) {
      return Map<String, String>.fromEntries(
        raw.entries.map((e) => MapEntry(e.key.toString(), e.value.toString())),
      );
    }
    return {};
  }
}

class AuthConfig {
  final String type; // none | bearer | basic
  final String token;
  final String username;
  final String password;

  const AuthConfig({
    this.type = 'none',
    this.token = '',
    this.username = '',
    this.password = '',
  });

  factory AuthConfig.fromJson(Map<String, dynamic> json) => AuthConfig(
        type: json['type'] ?? 'none',
        token: json['token'] ?? '',
        username: json['username'] ?? '',
        password: json['password'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'token': token,
        'username': username,
        'password': password,
      };

  AuthConfig copyWith({String? type, String? token, String? username, String? password}) =>
      AuthConfig(
        type: type ?? this.type,
        token: token ?? this.token,
        username: username ?? this.username,
        password: password ?? this.password,
      );
}
