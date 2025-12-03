import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

import 'package:zest/settings/settings_provider.dart';
// import 'dart:typed_data';

// ============================================================================
// Configuration
// ============================================================================

const String kGeminiModel = 'gemini-2.5-flash'; // supports multimodal

// ============================================================================
// Models
// ============================================================================

class GeminiRequest {
  final String prompt;
  final List<File>? images;
  final List<File>? pdfs;
  final String? url;
  final Map<String, dynamic>? schema; // For structured output

  GeminiRequest({
    required this.prompt,
    this.images,
    this.pdfs,
    this.url,
    this.schema,
  });
}

class GeminiResponse {
  final String text;
  final Map<String, dynamic>? structuredData;

  const GeminiResponse({required this.text, this.structuredData});
}

// ============================================================================
// API Manager
// ============================================================================

class GeminiApiManager {
  final String apiKey;
  final String model;

  GeminiApiManager({
    required this.apiKey,
    this.model = kGeminiModel,
  });

  Future<GeminiResponse> generateContent(GeminiRequest request) async {
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';

    // Build parts array
    final parts = <Map<String, dynamic>>[];

    // Handle URL content if provided
    String promptText = request.prompt;
    if (request.url != null) {
      final webResponse = await http.get(Uri.parse(request.url!));

      if (webResponse.statusCode != 200) {
        throw Exception('Failed to fetch URL: ${webResponse.statusCode}');
      }

      promptText = '''
${request.prompt}

URL: ${request.url}

Webpage content:
${webResponse.body}
''';
    }

    // Add text prompt
    parts.add({'text': promptText});

    // Add images
    if (request.images != null) {
      for (var image in request.images!) {
        final bytes = await image.readAsBytes();
        final base64 = base64Encode(bytes);
        final mimeType = _getMimeType(image.path);

        parts.add({
          'inline_data': {
            'mime_type': mimeType,
            'data': base64,
          }
        });
      }
    }

    // Add PDFs
    if (request.pdfs != null) {
      for (var pdf in request.pdfs!) {
        final bytes = await pdf.readAsBytes();
        final base64 = base64Encode(bytes);

        parts.add({
          'inline_data': {
            'mime_type': 'application/pdf',
            'data': base64,
          }
        });
      }
    }

    // Build request body
    final generationConfig = <String, dynamic>{
      'temperature': 0.7,
      'maxOutputTokens': 8192,
    };

    // Add structured output schema if provided
    if (request.schema != null) {
      generationConfig['response_mime_type'] = 'application/json';
      generationConfig['response_schema'] = request.schema;
    }

    final body = <String, dynamic>{
      'contents': [
        {'parts': parts}
      ],
      'generationConfig': generationConfig,
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'];

        Map<String, dynamic>? structuredData;
        if (request.schema != null) {
          structuredData = jsonDecode(text);
        }

        return GeminiResponse(
          text: text,
          structuredData: structuredData,
        );
      } else {
        throw Exception(
            'Gemini API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to call Gemini: $e');
    }
  }

  String _getMimeType(String path) {
    final ext = path.toLowerCase().split('.').last;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

// API Manager Provider
final geminiApiManagerProvider = Provider<GeminiApiManager>((ref) {
  final SettingsState settings = ref.read(settingsProvider);
  return GeminiApiManager(apiKey: settings.current.geminiApiKey);
});

// Request State Provider
final geminiRequestProvider =
    StateNotifierProvider<GeminiRequestNotifier, AsyncValue<GeminiResponse>>(
        (ref) {
  final apiManager = ref.watch(geminiApiManagerProvider);
  return GeminiRequestNotifier(apiManager);
});

class GeminiRequestNotifier extends StateNotifier<AsyncValue<GeminiResponse>> {
  final GeminiApiManager _apiManager;

  GeminiRequestNotifier(this._apiManager)
      : super(const AsyncValue.data(
          GeminiResponse(text: ''),
        ));

  Future<void> sendRequest(GeminiRequest request) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _apiManager.generateContent(request));
  }

  void reset() {
    state = const AsyncValue.data(GeminiResponse(text: ''));
  }
}

// ============================================================================
// Example Schema for Structured Output
// ============================================================================

// Valid units enum - extracted from the complete unit database
// Using abbreviations where available, otherwise full names (non-plural)
// Organized by language and type
final validUnits = [
  // Weight - Metric (universal abbreviations)
  'kg', 'g', 'dag', 'mg', 'µg',

  // Volume - Metric (universal abbreviations)
  'l', 'ml', 'cl', 'dl',

  // Volume - Imperial/US
  'gi.', 'fl.oz.', 'gal.', 'c',

  // Weight - Imperial/US
  'lb', 'gr',

  // Spoons - English abbreviations
  'tsp.', 'tbsp.', 'csp.', 'ssp.',

  // Spoons - German abbreviations
  'TL', 'EL', 'KL',

  // Containers/Portions - English abbreviations
  'pcs.', 'pn.', 'btl.', 'pkg.', 'ds.', 'dr.', 'sl.',

  // Containers/Portions - German abbreviations
  'St.', 'pr.', 'Be', 'Bd', 'Btl', 'Fl', 'Msp.', 'Stg', 'Pkg', 'Sp', 'Tr', 'Sc',
  'Kn', 'tas', 'Pfd.',

  // Units without abbreviations - use full name (non-plural)
  // English
  'handful', 'can', 'stem', 'clove', 'bulb', 'head',

  // German
  'handvoll', 'Dose', 'Stiel', 'Zehe', 'Knolle', 'Kopf', 'Schuss',

  // Japanese - Shakkanhou system (no abbreviations)
  'shaku 勺', 'gō 合', 'shō 升', 'to 斗', 'koku 石',
  'fun 分', 'monme 匁', 'ryō 両', 'kin 斤', 'kan 貫(目)', 'shō 鍾',

  // Special measurement units
  'sp gr', '°Bx', 'IU', 'kcal', 'kJ', 'ppm',
];

final recipeSchema = {
  'type': 'object',
  'properties': {
    'language': {
      'type': 'string',
      'enum': ['en', 'de', 'cz', 'it', 'fr', 'jp'],
      'description':
          'Language code - MUST be one of: en (English), de (German), cz (Czech), it (Italian), fr (French), jp (Japanese)',
    },
    'title': {
      'type': 'string',
      'description': 'Recipe title - REQUIRED',
    },
    'subtitle': {
      'type': 'string',
      'description': 'Recipe subtitle (optional)',
    },
    'owner_comment': {
      'type': 'string',
      'description': 'Comment from recipe owner',
    },
    'tags': {
      'type': 'array',
      'items': {'type': 'string'},
      'description': 'List of tags',
    },
    'categories': {
      'type': 'array',
      'items': {'type': 'string'},
      'description': 'Recipe categories',
    },
    'difficulty': {
      'type': 'integer',
      'description':
          'Difficulty level (0-3): 0=very easy, 1=easy, 2=medium, 3=hard',
      'minimum': 0,
      'maximum': 3,
    },
    'servings': {
      'type': 'integer',
      'description': 'Number of servings (1-99) - REQUIRED',
      'minimum': 1,
      'maximum': 99,
    },
    'prep_time': {
      'type': 'integer',
      'description': 'Preparation time in minutes - REQUIRED',
    },
    'cook_time': {
      'type': 'integer',
      'description': 'Cooking time in minutes - REQUIRED',
    },
    'total_time': {
      'type': 'integer',
      'description': 'Total time in minutes (prep_time + cook_time)',
    },
    'source_name': {
      'type': 'string',
      'description': 'Source name (optional)',
    },
    'source_url': {
      'type': 'string',
      'description': 'Source URL (optional)',
    },
    'ingredient_groups': {
      'type': 'array',
      'description': 'At least one ingredient group required',
      'minItems': 1,
      'items': {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description':
                'Group name (e.g., "For the dough", "For the sauce") - REQUIRED',
          },
          'ingredients': {
            'type': 'array',
            'minItems': 1,
            'items': {
              'type': 'object',
              'properties': {
                'amount_min': {
                  'type': 'number',
                  'description':
                      'Minimum amount - REQUIRED. Use 1 if no amount is specified. Convert fractions to decimals (e.g., 1/2 = 0.5, 1/4 = 0.25, 2 1/2 = 2.5)',
                },
                'amount_max': {
                  'type': 'number',
                  'description':
                      'Maximum amount (optional, for ranges like "2-3 cups"). Convert fractions to decimals',
                },
                'unit': {
                  'type': 'string',
                  'enum': validUnits,
                  'description':
                      'Unit abbreviation or full name - REQUIRED. Prefer abbreviations when available (e.g., "TL" for German teaspoon, "tsp." for English). For units without abbreviations, use full names in the recipe language (e.g., "handful"/"handvoll", "head"/"Kopf"). Use "pcs." (English) or "St." (German) for pieces if no unit is specified',
                },
                'food': {
                  'type': 'string',
                  'description': 'Ingredient name - REQUIRED',
                },
                'details': {
                  'type': 'string',
                  'description':
                      'Additional details (optional, e.g., "finely chopped", "room temperature", "diced")',
                },
              },
              'required': ['amount_min', 'unit', 'food'],
            },
          },
        },
        'required': ['name', 'ingredients'],
      },
    },
    'instruction_groups': {
      'type': 'array',
      'description': 'At least one instruction group required',
      'minItems': 1,
      'items': {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description':
                'Instruction group name - REQUIRED (e.g., "Preparation", "Cooking", "Assembly")',
          },
          'instructions': {
            'type': 'array',
            'description': 'At least one instruction step required',
            'minItems': 1,
            'items': {
              'type': 'object',
              'properties': {
                'text': {
                  'type': 'string',
                  'description': 'Instruction step text - REQUIRED',
                },
              },
              'required': ['text'],
            },
          },
        },
        'required': ['name', 'instructions'],
      },
    },
  },
  'required': [
    'title',
    'servings',
    'prep_time',
    'cook_time',
    'ingredient_groups',
    'instruction_groups',
  ],
};

// ============================================================================
// Usage Example Widget
// ============================================================================

/*
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GeminiExampleScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestState = ref.watch(geminiRequestProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Gemini API Example')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Simple text generation
            ElevatedButton(
              onPressed: () {
                ref.read(geminiRequestProvider.notifier).sendRequest(
                  GeminiRequest(prompt: 'Write a haiku about coding'),
                );
              },
              child: Text('Generate Text'),
            ),
            
            SizedBox(height: 16),
            
            // Image analysis with structured output
            ElevatedButton(
              onPressed: () async {
                // Pick image using file_picker package
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.image,
                );
                
                if (result != null) {
                  ref.read(geminiRequestProvider.notifier).sendRequest(
                    GeminiRequest(
                      prompt: 'Extract recipe information from this image',
                      images: [File(result.files.first.path!)],
                      schema: recipeSchema,
                    ),
                  );
                }
              },
              child: Text('Analyze Image'),
            ),
            
            SizedBox(height: 16),
            
            // PDF analysis
            ElevatedButton(
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf'],
                );
                
                if (result != null) {
                  ref.read(geminiRequestProvider.notifier).sendRequest(
                    GeminiRequest(
                      prompt: 'Extract invoice data from this PDF',
                      pdfs: [File(result.files.first.path!)],
                      schema: invoiceSchema,
                    ),
                  );
                }
              },
              child: Text('Analyze PDF'),
            ),
            
            SizedBox(height: 24),
            
            // Results display
            Expanded(
              child: requestState.when(
                data: (response) {
                  if (response.text.isEmpty) {
                    return Center(child: Text('No results yet'));
                  }
                  
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (response.structuredData != null) ...[
                          Text('Structured Data:', 
                            style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Text(JsonEncoder.withIndent('  ')
                            .convert(response.structuredData)),
                        ] else ...[
                          Text('Response:', 
                            style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Text(response.text),
                        ],
                      ],
                    ),
                  );
                },
                loading: () => Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                  child: Text('Error: $err', 
                    style: TextStyle(color: Colors.red)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
*/
