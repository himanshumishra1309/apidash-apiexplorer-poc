import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
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
  String _searchQuery = '';
  ApiTemplate? _selectedTemplate;

  @override
  void initState() {
    super.initState();
    _fetchTemplates();
  }

  Future<void> _fetchTemplates() async {
    try {
      final file = File('/home/himanshu-mishra/apidash-apiexplorer-poc/pipeline/output/templates.json');
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> data = json.decode(jsonString);
        setState(() {
          _templates = data.map((e) => ApiTemplate.fromJson(e)).toList();
          _isLoading = false;
          if (_templates.isNotEmpty) {
            _selectedTemplate = _templates.first;
          }
        });
      } else {
        debugPrint('File not found at \${file.path}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error fetching templates: \$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final filteredTemplates = _templates.where((t) {
      final query = _searchQuery.toLowerCase();
      return t.name.toLowerCase().contains(query) ||
             t.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('API Explorer'),
        centerTitle: false,
        elevation: 2,
      ),
      body: Row(
        children: [
          // Sidebar
          SizedBox(
            width: 320,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search APIs or tags...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredTemplates.length,
                    itemBuilder: (context, index) {
                      final template = filteredTemplates[index];
                      final isSelected = _selectedTemplate == template;
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                        title: Text(
                          template.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "\${template.endpointsCount} endpoints • \${template.tags.join(', ')}",
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
          const VerticalDivider(width: 1, thickness: 1),
          // Main Content Area
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
