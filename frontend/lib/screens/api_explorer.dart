import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/api_template.dart';
import 'api_details.dart';

class ApiExplorerScreen extends StatefulWidget {
  const ApiExplorerScreen({super.key});

  @override
  State<ApiExplorerScreen> createState() => _ApiExplorerScreenState();
}

class _ApiExplorerScreenState extends State<ApiExplorerScreen> {
  List<ApiTemplate> _templates = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  ApiTemplate? _selectedTemplate;

  @override
  void initState() {
    super.initState();
    _fetchTemplates();
  }

  Future<void> _fetchTemplates() async {
    try {
      final file = File(
        '/home/himanshu-mishra/apidash-apiexplorer-poc/pipeline/output/templates.json',
      );

      if (!await file.exists()) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'templates.json not found at ${file.path}';
        });
        return;
      }

      final jsonString = await file.readAsString();
      final decoded = json.decode(jsonString);
      if (decoded is! List) {
        throw const FormatException('templates.json must be a JSON array.');
      }

      final parsedTemplates = decoded
          .whereType<Map>()
          .map((e) => ApiTemplate.fromJson(e.cast<String, dynamic>()))
          .toList();

      setState(() {
        _templates = parsedTemplates;
        _isLoading = false;
        _errorMessage = null;
        _selectedTemplate =
            parsedTemplates.isEmpty ? null : parsedTemplates.first;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('API Explorer')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
      );
    }

    final query = _searchQuery.toLowerCase().trim();
    final filteredTemplates = _templates.where((t) {
      if (query.isEmpty) return true;
      final inName = t.name.toLowerCase().contains(query);
      final inTags = t.tags.any((tag) => tag.toLowerCase().contains(query));
      final inBaseUrl = t.baseUrl.toLowerCase().contains(query);
      return inName || inTags || inBaseUrl;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('API Explorer (${_templates.length})'),
        centerTitle: false,
      ),
      body: Row(
        children: [
          SizedBox(
            width: 360,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search name, tags, base URL...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: filteredTemplates.isEmpty
                      ? const Center(
                          child: Text('No APIs matched your search.'))
                      : ListView.builder(
                          itemCount: filteredTemplates.length,
                          itemBuilder: (context, index) {
                            final template = filteredTemplates[index];
                            final isSelected = _selectedTemplate == template;
                            final tagsLabel = template.tags.isEmpty
                                ? 'No tags'
                                : template.tags.join(', ');

                            return ListTile(
                              selected: isSelected,
                              selectedTileColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.3),
                              title: Text(
                                template.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${template.endpointsCount} endpoints • $tagsLabel',
                                style: const TextStyle(fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: template.globalAuthMethods.isNotEmpty
                                  ? const Icon(Icons.verified_user_outlined,
                                      size: 18)
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedTemplate = template;
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _selectedTemplate == null
                ? const Center(child: Text('Select an API to explore.'))
                : ApiDetailsView(template: _selectedTemplate!),
          ),
        ],
      ),
    );
  }
}
