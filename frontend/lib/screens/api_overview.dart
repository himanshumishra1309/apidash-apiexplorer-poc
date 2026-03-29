import 'dart:convert';
import 'package:flutter/material.dart';

import '../models/api_template.dart';

class ApiOverviewScreen extends StatelessWidget {
  final ApiTemplate template;

  const ApiOverviewScreen({super.key, required this.template});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(template.name,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Base URL: ${template.baseUrl}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
          ),
          const SizedBox(height: 16),
          // We can put Swagger or external links here if available.

          const Divider(),
          const SizedBox(height: 16),
          Text('Global Authentication Methods',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: const Text(
              '💡 What is a Global Auth Method?\\n'
              'A global auth method specifies the default authentication approach for the entire API. '
              'Instead of repeating the same credentials (e.g., an API Key in headers or a Bearer token) '
              'for every single endpoint request, these are configured once globally. Individual endpoints '
              'can choose to override or bypass them if they are public or require different auth.',
              style: TextStyle(height: 1.5, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          if (template.globalAuthMethods.isEmpty)
            const Text('No Global Auth Methods defined.',
                style: TextStyle(fontStyle: FontStyle.italic))
          else
            Expanded(
              child: ListView(
                children: template.globalAuthMethods.entries.map((e) {
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.key,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          SelectableText(
                            const JsonEncoder.withIndent('  ').convert(e.value),
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
