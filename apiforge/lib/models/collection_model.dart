import 'request_model.dart';

/// Dart model for a Collection of saved requests.
class CollectionModel {
  final String id;
  final String name;
  final String description;
  final String color;
  final List<RequestModel> requests;
  final DateTime? createdAt;

  const CollectionModel({
    required this.id,
    required this.name,
    this.description = '',
    this.color = '#6C63FF',
    this.requests = const [],
    this.createdAt,
  });

  factory CollectionModel.fromJson(Map<String, dynamic> json) => CollectionModel(
        id: json['_id'] ?? json['id'] ?? '',
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        color: json['color'] ?? '#6C63FF',
        requests: (json['requests'] as List<dynamic>? ?? [])
            .map((r) => r is Map<String, dynamic>
                ? RequestModel.fromJson(r)
                : RequestModel(id: r.toString(), name: '', method: 'GET', url: ''))
            .toList(),
        createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'color': color,
      };
}
