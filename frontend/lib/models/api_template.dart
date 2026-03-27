class ApiTemplate {
  final String name;
  final List<String> tags;
  final String baseUrl;
  final Map<String, dynamic> globalAuthMethods;
  final int endpointsCount;
  final List<ApiEndpoint> endpoints;

  ApiTemplate({
    required this.name,
    required this.tags,
    required this.baseUrl,
    required this.globalAuthMethods,
    required this.endpointsCount,
    required this.endpoints,
  });

  factory ApiTemplate.fromJson(Map<String, dynamic> json) {
    final endpointList = json['endpoints'] as List? ?? const [];

    return ApiTemplate(
      name: json['name'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      baseUrl: json['base_url'] ?? '',
      globalAuthMethods:
          (json['global_auth_methods'] as Map?)?.cast<String, dynamic>() ??
              const {},
      endpointsCount: json['endpoints_count'] ?? 0,
      endpoints: endpointList
          .whereType<Map>()
          .map((e) => ApiEndpoint.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

class ApiEndpoint {
  final String method;
  final String path;
  final String summary;
  final List<String> authRequired;
  final EndpointParameters parameters;
  final dynamic requestBodySample;
  final dynamic responseBodySample;

  ApiEndpoint({
    required this.method,
    required this.path,
    required this.summary,
    required this.authRequired,
    required this.parameters,
    required this.requestBodySample,
    required this.responseBodySample,
  });

  factory ApiEndpoint.fromJson(Map<String, dynamic> json) {
    return ApiEndpoint(
      method: json['method'] ?? '',
      path: json['path'] ?? '',
      summary: json['summary'] ?? '',
      authRequired: List<String>.from(json['auth_required'] ?? const []),
      parameters: EndpointParameters.fromJson(
          (json['parameters'] as Map?)?.cast<String, dynamic>() ?? const {}),
      requestBodySample: json['request_body_sample'],
      responseBodySample: json['response_body_sample'],
    );
  }
}

class EndpointParameters {
  final List<ApiParameter> headers;
  final List<ApiParameter> pathVariables;
  final List<ApiParameter> queryParameters;

  const EndpointParameters({
    required this.headers,
    required this.pathVariables,
    required this.queryParameters,
  });

  factory EndpointParameters.fromJson(Map<String, dynamic> json) {
    List<ApiParameter> parseParams(dynamic raw) {
      final list = raw as List? ?? const [];
      return list
          .whereType<Map>()
          .map((item) => ApiParameter.fromJson(item.cast<String, dynamic>()))
          .toList();
    }

    return EndpointParameters(
      headers: parseParams(json['headers']),
      pathVariables: parseParams(json['path_variables']),
      queryParameters: parseParams(json['query_parameters']),
    );
  }
}

class ApiParameter {
  final String name;
  final String type;
  final bool required;

  const ApiParameter({
    required this.name,
    required this.type,
    required this.required,
  });

  factory ApiParameter.fromJson(Map<String, dynamic> json) {
    return ApiParameter(
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'unknown',
      required: json['required'] == true,
    );
  }
}
