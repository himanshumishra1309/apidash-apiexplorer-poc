import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/api_template.dart';

class ApiDetailsView extends StatefulWidget {
  final ApiTemplate template;

  const ApiDetailsView({super.key, required this.template});

  @override
  State<ApiDetailsView> createState() => _ApiDetailsViewState();
}

class _ApiDetailsViewState extends State<ApiDetailsView> {
  String _endpointSearch = '';

  @override
  Widget build(BuildContext context) {
    final template = widget.template;
    final endpointQuery = _endpointSearch.toLowerCase().trim();
    final filteredEndpoints = template.endpoints.where((ep) {
      if (endpointQuery.isEmpty) return true;
      return ep.path.toLowerCase().contains(endpointQuery) ||
          ep.method.toLowerCase().contains(endpointQuery) ||
          ep.summary.toLowerCase().contains(endpointQuery);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(template.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          SelectableText(
            'Base URL: ${template.baseUrl}',
            style: const TextStyle(fontFamily: 'monospace', color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...template.tags.map(
                (tag) => Chip(
                  label: Text(tag),
                  backgroundColor:
                      Theme.of(context).colorScheme.secondaryContainer,
                ),
              ),
              Chip(
                avatar: const Icon(Icons.route, size: 16),
                label: Text('${template.endpointsCount} endpoints'),
              ),
              Chip(
                avatar: const Icon(Icons.lock_outline, size: 16),
                label:
                    Text('${template.globalAuthMethods.length} auth methods'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (template.globalAuthMethods.isNotEmpty) ...[
            Text('Global Auth Methods',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: template.globalAuthMethods.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final entry =
                      template.globalAuthMethods.entries.elementAt(index);
                  return SizedBox(
                    width: 320,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.key,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Expanded(
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  const JsonEncoder.withIndent('  ')
                                      .convert(entry.value),
                                  style: const TextStyle(
                                      fontFamily: 'monospace', fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            decoration: InputDecoration(
              hintText: 'Filter endpoints by method, path, summary...',
              prefixIcon: const Icon(Icons.filter_alt_outlined),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() {
                _endpointSearch = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Endpoints (${filteredEndpoints.length}/${template.endpoints.length})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: filteredEndpoints.length,
              itemBuilder: (context, index) {
                final ep = filteredEndpoints[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ExpansionTile(
                    tilePadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    title: Row(
                      children: [
                        _MethodBadge(method: ep.method),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SelectableText(
                            ep.path,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ),
                    subtitle: ep.summary.isEmpty
                        ? null
                        : Text(ep.summary,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      if (ep.authRequired.isNotEmpty) ...[
                        const _SectionTitle(title: 'Auth Required'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: ep.authRequired
                              .map((a) => Chip(label: Text(a)))
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _ParametersBlock(
                          title: 'Headers', parameters: ep.parameters.headers),
                      _ParametersBlock(
                          title: 'Path Variables',
                          parameters: ep.parameters.pathVariables),
                      _ParametersBlock(
                          title: 'Query Parameters',
                          parameters: ep.parameters.queryParameters),
                      _JsonBlock(
                          title: 'Request Body Sample',
                          value: ep.requestBodySample),
                      _JsonBlock(
                          title: 'Response Body Sample',
                          value: ep.responseBodySample),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _ParametersBlock extends StatelessWidget {
  final String title;
  final List<ApiParameter> parameters;

  const _ParametersBlock({required this.title, required this.parameters});

  @override
  Widget build(BuildContext context) {
    if (parameters.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: title),
          ...parameters.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${p.name} (${p.type})',
                        style: const TextStyle(fontFamily: 'monospace')),
                  ),
                  Chip(
                    label: Text(p.required ? 'required' : 'optional'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JsonBlock extends StatelessWidget {
  final String title;
  final dynamic value;

  const _JsonBlock({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value == null) return const SizedBox.shrink();

    String rendered;
    try {
      rendered = const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      rendered = value.toString();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: title),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.35),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                rendered,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
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
        color = Colors.blue;
        break;
      case 'PUT':
      case 'PATCH':
        color = Colors.orange;
        break;
      case 'DELETE':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      width: 50,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      alignment: Alignment.center,
      child: Text(
        method.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
