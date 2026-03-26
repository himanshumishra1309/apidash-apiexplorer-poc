import 'package:flutter/material.dart';
import '../models/api_template.dart';

class ApiDetailsView extends StatelessWidget {
  final ApiTemplate template;

  const ApiDetailsView({super.key, required this.template});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            template.title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          SelectableText(
            'Base URL: \${template.baseUrl}',
            style: const TextStyle(fontFamily: 'monospace', color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: template.tags
                .map((tag) => Chip(
                      label: Text(tag),
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Endpoints (\${template.endpointsCount})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: template.endpoints.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final ep = template.endpoints[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      _MethodBadge(method: ep.method),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(
                              ep.path,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                            ),
                            if (ep.summary.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(ep.summary, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.play_arrow_outlined),
                        tooltip: 'Load in API Dash',
                        onPressed: () {
                          // Handle adding to active workspace
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Load \${ep.method} \${ep.path} in API Dash...')),
                          );
                        },
                      )
                    ],
                  ),
                );
              },
            ),
          )
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
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
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
