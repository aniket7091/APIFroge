/// Dart model for a History entry.
class HistoryModel {
  final String id;
  final String method;
  final String url;
  final int? statusCode;
  final int responseTime;
  final bool isError;
  final String errorMessage;
  final dynamic requestBody;
  final dynamic responseBody;
  final Map<String, dynamic> responseHeaders;
  final DateTime? createdAt;

  const HistoryModel({
    required this.id,
    required this.method,
    required this.url,
    this.statusCode,
    this.responseTime = 0,
    this.isError = false,
    this.errorMessage = '',
    this.requestBody,
    this.responseBody,
    this.responseHeaders = const {},
    this.createdAt,
  });

  factory HistoryModel.fromJson(Map<String, dynamic> json) => HistoryModel(
        id: json['_id'] ?? json['id'] ?? '',
        method: json['method'] ?? 'GET',
        url: json['url'] ?? '',
        statusCode: json['statusCode'],
        responseTime: json['responseTime'] ?? 0,
        isError: json['isError'] ?? false,
        errorMessage: json['errorMessage'] ?? '',
        requestBody: json['requestBody'],
        responseBody: json['responseBody'],
        responseHeaders: Map<String, dynamic>.from(json['responseHeaders'] ?? {}),
        createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      );
}
