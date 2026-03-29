import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/api_template.dart';

class EndpointDetailsView extends StatelessWidget {
  final ApiEndpoint endpoint;
  final String baseUrl;

  const EndpointDetailsView({
    super.key,
    required this.endpoint,
    this.baseUrl = '',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 1, child: _buildRequestPane(context)),
                VerticalDivider(width: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                Expanded(flex: 1, child: _buildResponsePane(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MethodBadge(method: endpoint.method),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        '$baseUrl${endpoint.path}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    if (endpoint.authRequired.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Tooltip(
                        message: 'Auth Configs: ${endpoint.authRequired.join(', ')}',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline, size: 14, color: Theme.of(context).colorScheme.error),
                              const SizedBox(width: 6),
                              Text(
                                'Auth Required',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              )
                            ],
                          ),
                        ),
                      )
                    ]
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  endpoint.summary.isNotEmpty ? endpoint.summary : 'No summary available.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Preparing ${endpoint.method} request for API Dash...')),
              );
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
            icon: const Icon(Icons.bolt, size: 20),
            label: const Text('Test Endpoint', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestPane(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Request / Input', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildParameterSection(context, 'Path Variables', endpoint.parameters.pathVariables),
        _buildParameterSection(context, 'Query Parameters', endpoint.parameters.queryParameters),
        _buildParameterSection(context, 'Headers', endpoint.parameters.headers),
        
        if (endpoint.requestBodySample != null) ...[
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Payload (Body)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () {
                  final formatted = const JsonEncoder.withIndent('  ').convert(endpoint.requestBodySample);
                  Clipboard.setData(ClipboardData(text: formatted));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payload copied to clipboard!')));
                },
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('Copy Payload'),
              )
            ],
          ),
          const SizedBox(height: 8),
          _SyntaxHighlightedJson(data: endpoint.requestBodySample),
        ],
      ],
    );
  }

  Widget _buildParameterSection(BuildContext context, String title, List<ApiParameter> params) {
    if (params.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: EdgeInsets.zero,
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        title: Text('$title (${params.length})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        children: params.map((p) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8.0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: RichText(
                    text: TextSpan(
                      text: p.name,
                      style: TextStyle(
                        fontFamily: 'monospace', 
                        fontWeight: FontWeight.w600, 
                        color: Theme.of(context).colorScheme.primary
                      ),
                      children: [
                        if (p.required)
                          const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
                      ]
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(p.type, style: TextStyle(color: Colors.grey.shade600, fontFamily: 'monospace', fontSize: 13)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildResponsePane(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Expected Response / Output', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (endpoint.responseBodySample == null)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
            ),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.check_circle_outline, size: 32, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  '204 No Content / Empty Response', 
                  style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 4),
                Text(
                  'Server processes request and returns no body payload.', 
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)
                ),
              ],
            ),
          )
        else
          _SyntaxHighlightedJson(data: endpoint.responseBodySample),
      ],
    );
  }
}

class _SyntaxHighlightedJson extends StatelessWidget {
  final dynamic data;
  const _SyntaxHighlightedJson({required this.data});

  @override
  Widget build(BuildContext context) {
    final formatted = const JsonEncoder.withIndent('  ').convert(data);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
            ? const Color(0xFF1E1E1E) 
            : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: SelectableText.rich(
        _highlight(formatted, Theme.of(context).brightness),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5),
      ),
    );
  }

  TextSpan _highlight(String code, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    
    // Developer-friendly standard coloring
    final keyColor = isDark ? Colors.lightBlueAccent : Colors.blue[700];
    final stringColor = isDark ? Colors.lightGreen : Colors.green[700];
    final numberColor = isDark ? Colors.orangeAccent : Colors.orange[800];
    final boolColor = isDark ? Colors.purpleAccent : Colors.purple[700];
    final nullColor = isDark ? Colors.redAccent : Colors.red[700];
    final defaultColor = isDark ? Colors.white70 : Colors.black87;

    // Simple robust RegExp to break apart JSON
    final regExp = RegExp(r'(".*?":)|(".*?")|(\b-?\d+\.?\d*([eE][+-]?\d+)?\b)|(\btrue\b|\bfalse\b)|(\bnull\b)');
    
    List<InlineSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in regExp.allMatches(code)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: code.substring(lastMatchEnd, match.start), style: TextStyle(color: defaultColor)));
      }

      final matchText = match.group(0)!;
      if (matchText.endsWith('":')) {
        // Key
        spans.add(TextSpan(text: matchText.substring(0, matchText.length - 1), style: TextStyle(color: keyColor)));
        spans.add(TextSpan(text: ':', style: TextStyle(color: defaultColor)));
      } else if (matchText.startsWith('"')) {
        // String
        spans.add(TextSpan(text: matchText, style: TextStyle(color: stringColor)));
      } else if (matchText == 'true' || matchText == 'false') {
        // Boolean
        spans.add(TextSpan(text: matchText, style: TextStyle(color: boolColor)));
      } else if (matchText == 'null') {
        // Null
        spans.add(TextSpan(text: matchText, style: TextStyle(color: nullColor)));
      } else {
        // Number
        spans.add(TextSpan(text: matchText, style: TextStyle(color: numberColor)));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < code.length) {
      spans.add(TextSpan(text: code.substring(lastMatchEnd), style: TextStyle(color: defaultColor)));
    }

    return TextSpan(children: spans);
  }
}

class _MethodBadge extends StatelessWidget {
  final String method;

  const _MethodBadge({required this.method});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (method.toUpperCase()) {
      case 'GET':
        color = Colors.green;
        break;
      case 'POST':
        color = Colors.orange;
        break;
      case 'PUT':
        color = Colors.blue;
        break;
      case 'DELETE':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      width: 70,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      alignment: Alignment.center,
      child: Text(
        method.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
