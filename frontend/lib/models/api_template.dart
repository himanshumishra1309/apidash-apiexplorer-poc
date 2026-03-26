class ApiTemplate {
  final String name;
  final String title;
  final List<String> tags;
  final String baseUrl;
  final int endpointsCount;
  final List<ApiEndpoint> endpoints;

  ApiTemplate({
    required this.name,
    required this.title,
    required this.tags,
    required this.baseUrl,
    required this.endpointsCount,
    required this.endpoints,
  });

  factory ApiTemplate.fromJson(Map<String, dynamic> json) {
    return ApiTemplate(
      name: json['name'] ?? '',
      title: json['title'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      baseUrl: json['base_url'] ?? '',
      endpointsCount: json['endpoints_count'] ?? 0,
      endpoints: (json['endpoints'] as List?)
              ?.map((e) => ApiEndpoint.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class ApiEndpoint {
  final String method;
  final String path;
  final String summary;

  ApiEndpoint({
    required this.method,
    required this.path,
    required this.summary,
  });

  factory ApiEndpoint.fromJson(Map<String, dynamic> json) {
    return ApiEndpoint(
      method: json['method'] ?? '',
      path: json['path'] ?? '',
      summary: json['summary'] ?? '',
    );
  }
}
