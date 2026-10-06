import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Run with: flutter run --dart-define=GEMINI_API_KEY=xxxx
/// ponytail: key ships in the client for MVP. Move the call behind a
/// Cloud Function before any public release.
const _key = String.fromEnvironment('GEMINI_API_KEY');

class NotABill implements Exception {}

class Extraction {
  /// field -> (value, confidence)
  final Map<String, dynamic> raw;
  Extraction(this.raw);

  dynamic val(String k) => (raw[k] as Map?)?['value'];
  double conf(String k) => ((raw[k] as Map?)?['confidence'] as num?)?.toDouble() ?? 0;
  List<Map<String, dynamic>> get items =>
      [for (final i in (raw['items'] as List? ?? [])) Map<String, dynamic>.from(i)];
}

const _prompt = '''
You are an expert consumer protection, retail, and warranty analyst for India and global consumer products.
You read purchase bills / invoices (India: GST invoices, thermal store bills, marketplace invoices from Amazon, Flipkart, Reliance Digital, Croma, Vijay Sales, etc.; English or Hindi).
Return ONLY JSON of this shape. Use null when not printed/known. confidence is 0..1.
{"is_bill": true,
 "seller":{"value":str,"confidence":n},
 "invoice_no":{"value":str,"confidence":n},
 "purchase_date":{"value":"YYYY-MM-DD","confidence":n},
 "total_amount":{"value":number,"currency":"INR","confidence":n},
 "tax":{"value":number,"confidence":n},
 "payment_mode":{"value":str,"confidence":n},
 "items":[{"product_name":str,"brand":str,"model":str,"serial_no":str,"price":number,
           "printed_warranty":str or null,
           "standard_warranty_terms":[{"label":str,"months":number,"source":"brand" or "estimated"}],
           "warranty_summary":str or null,
           "support_contact":str or null,
           "confidence":n}]}

CRITICAL RULES FOR "standard_warranty_terms" (Determine real-world official manufacturer coverage in India):
1. Power Banks & Charging Accessories:
   - Duracell Power Banks: Standard 24 months (2 years) manufacturer warranty.
   - Anker, Mi/Xiaomi, Realme, Ambrane, boAt, Portronics: 6 or 12 months depending on model.
2. PC Components & Storage:
   - External SSD/HDD (SanDisk, WD, Seagate): 36 months (3 years) to 60 months (5 years).
   - Monitors (Dell, LG, Samsung, BenQ): 36 months (3 years).
   - RAM (Corsair, Kingston): 120 months (10 years / Lifetime).
3. Major Home Appliances (Multi-part breakdown):
   - Air Conditioners (Daikin, Voltas, LG, Lloyd, Blue Star): [{"label":"Comprehensive","months":12,"source":"brand"},{"label":"PCB","months":60,"source":"brand"},{"label":"Compressor","months":120,"source":"brand"}]
   - Refrigerators (Samsung, LG, Whirlpool): [{"label":"Comprehensive","months":12,"source":"brand"},{"label":"Digital Inverter Compressor","months":240,"source":"brand"}] (or 120 months for standard).
   - Washing Machines (LG, Bosch, IFB, Samsung): [{"label":"Comprehensive","months":24,"source":"brand"},{"label":"Motor","months":120,"source":"brand"}]
   - Water Purifiers (Kent, Aquaguard, Pureit): [{"label":"Comprehensive","months":12,"source":"brand"},{"label":"RO Membrane","months":12,"source":"brand"}]
   - Microwave Ovens (IFB, Samsung, LG): [{"label":"Comprehensive","months":12,"source":"brand"},{"label":"Magnetron","months":36,"source":"brand"}]
4. Televisions (Sony, Samsung, LG, TCL, Xiaomi):
   - [{"label":"Comprehensive","months":12,"source":"brand"},{"label":"Display Panel","months":24,"source":"brand"}]
5. Audio & Wearables (Apple, Sony, boAt, Noise, Fire-Boltt, JBL):
   - Standard 12 months.
6. If the specific brand and model offers an extended or non-standard duration (e.g. Duracell power bank = 24 months), use that exact duration with "source":"brand".
Include every product line item. If the image is not a bill, return {"is_bill": false}.
''';

/// Production proxy endpoint (e.g. Firebase Cloud Function).
/// If specified via --dart-define=BACKEND_EXTRACT_URL=..., bills are extracted securely via backend.
const _backendUrl = String.fromEnvironment('BACKEND_EXTRACT_URL');

abstract class BillExtractor {
  Future<Extraction> extract(File file, {String? apiKey});
}

class DefaultBillExtractor implements BillExtractor {
  const DefaultBillExtractor();

  static String? _cachedWorkingModel;
  static String _cachedApiVer = 'v1beta';

  Future<List<String>> _discoverModels(String key) async {
    for (final ver in ['v1beta', 'v1']) {
      try {
        final client = http.Client();
        final res = await client
            .get(
              Uri.parse('https://generativelanguage.googleapis.com/$ver/models?key=$key'),
              headers: {'x-goog-api-key': key, 'Connection': 'close'},
            )
            .timeout(const Duration(seconds: 8));
        client.close();
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final models = data['models'] as List? ?? [];
          final supported = <String>[];
          for (final m in models) {
            final methods = m['supportedGenerationMethods'] as List? ?? [];
            if (methods.contains('generateContent')) {
              final name = (m['name'] as String? ?? '').replaceFirst('models/', '');
              if (name.isNotEmpty) supported.add(name);
            }
          }
          if (supported.isNotEmpty) {
            // Prioritize flash models and newest versions (e.g. 3.x, 2.5, 2.0)
            supported.sort((a, b) {
              final aFlash = a.toLowerCase().contains('flash') ? 1 : 0;
              final bFlash = b.toLowerCase().contains('flash') ? 1 : 0;
              if (aFlash != bFlash) return bFlash.compareTo(aFlash);
              return b.compareTo(a);
            });
            _cachedApiVer = ver;
            return supported;
          }
        }
      } catch (_) {}
    }
    return const [];
  }

  String _parseErrorDetail(http.Response res) {
    try {
      final j = jsonDecode(res.body);
      if (j is Map && j['error'] is Map) {
        final msg = j['error']['message']?.toString();
        if (msg != null && msg.trim().isNotEmpty) return msg.trim();
      }
    } catch (_) {}
    return '';
  }

  Future<http.Response> _postExtraction(String key, File file, String model, {String apiVer = 'v1beta'}) async {
    final uri = Uri.parse('https://generativelanguage.googleapis.com/$apiVer/models/$model:generateContent?key=$key');
    final bytes = await file.readAsBytes();
    final mime = file.path.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'image/jpeg';
    final payload = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': _prompt},
            {
              'inlineData': {
                'mimeType': mime,
                'data': base64Encode(bytes),
              }
            }
          ]
        }
      ],
      'generationConfig': {'responseMimeType': 'application/json', 'temperature': 0},
    });

    for (int attempt = 0; attempt < 2; attempt++) {
      final client = http.Client();
      try {
        return await client
            .post(
              uri,
              headers: {
                'x-goog-api-key': key,
                'content-type': 'application/json',
                'Connection': 'close',
              },
              body: payload,
            )
            .timeout(const Duration(seconds: 60));
      } on SocketException catch (_) {
        if (attempt == 1) rethrow;
        await Future.delayed(const Duration(milliseconds: 600));
      } on http.ClientException catch (_) {
        if (attempt == 1) rethrow;
        await Future.delayed(const Duration(milliseconds: 600));
      } finally {
        client.close();
      }
    }
    throw const SocketException('Connection failed after retry.');
  }

  @override
  Future<Extraction> extract(File file, {String? apiKey}) async {
    // 1. If backend proxy is configured, use secure Cloud Function backend
    if (_backendUrl.isNotEmpty) {
      final req = http.MultipartRequest('POST', Uri.parse(_backendUrl))
        ..files.add(await http.MultipartFile.fromPath('file', file.path));
      final streamed = await req.send().timeout(const Duration(seconds: 45));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode != 200) throw HttpException('Extraction failed (${res.statusCode})');
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      if (j['is_bill'] == false) throw NotABill();
      return Extraction(j);
    }

    final effectiveKey = (apiKey != null && apiKey.trim().isNotEmpty) ? apiKey.trim() : _key;
    if (effectiveKey.isEmpty) {
      throw StateError('Missing Gemini API Key. Open Settings > Gemini AI Configuration to enter your key.');
    }

    // Build model list: cached first, followed by standard fallback candidates
    final candidateModels = <String>{
      ?_cachedWorkingModel,
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-1.5-flash',
      'gemini-2.5-flash-lite',
      'gemini-2.0-flash-lite',
      'gemini-1.5-flash-8b',
      'gemini-1.5-pro',
    }.toList();

    try {
      http.Response? res;

      // Try candidate models with current API version and v1/v1beta fallbacks
      for (final m in candidateModels) {
        for (final ver in [_cachedApiVer, _cachedApiVer == 'v1beta' ? 'v1' : 'v1beta']) {
          res = await _postExtraction(effectiveKey, file, m, apiVer: ver);
          if (res.statusCode == 200) {
            _cachedWorkingModel = m;
            _cachedApiVer = ver;
            break;
          }
          if (res.statusCode != 404) break;
        }
        if (res?.statusCode == 200) break;
      }

      // If all hardcoded candidates failed with 404, dynamically query what models are enabled on this key
      if (res == null || res.statusCode == 404) {
        final discovered = await _discoverModels(effectiveKey);
        for (final m in discovered) {
          if (candidateModels.contains(m)) continue;
          res = await _postExtraction(effectiveKey, file, m, apiVer: _cachedApiVer);
          if (res.statusCode == 200) {
            _cachedWorkingModel = m;
            break;
          }
        }
      }

      res ??= await _postExtraction(effectiveKey, file, candidateModels.first, apiVer: _cachedApiVer);

      final detail = _parseErrorDetail(res);
      if (res.statusCode == 400 || res.statusCode == 403) {
        throw StateError(detail.isNotEmpty
            ? detail
            : 'Invalid Gemini API Key or permission denied. Please verify your key in Settings.');
      } else if (res.statusCode == 404) {
        throw StateError(detail.isNotEmpty
            ? detail
            : 'Gemini model unavailable (404). Please ensure the Generative Language API is enabled for your key.');
      } else if (res.statusCode == 429) {
        throw StateError('Gemini API rate limit or quota exceeded. Please try again shortly.');
      } else if (res.statusCode != 200) {
        throw HttpException(detail.isNotEmpty ? detail : 'Gemini error (${res.statusCode})');
      }

      final text = jsonDecode(res.body)['candidates'][0]['content']['parts'][0]['text'];
      final j = jsonDecode(text) as Map<String, dynamic>;
      if (j['is_bill'] == false) throw NotABill();
      return Extraction(j);
    } on SocketException {
      throw const SocketException('No internet connection. Please check your network and try again.');
    } on http.ClientException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('connection abort') || msg.contains('socket') || msg.contains('closed')) {
        throw const SocketException('Network connection was interrupted. Please check your network and try again.');
      }
      throw SocketException('Network request failed: ${e.message}');
    } catch (e) {
      if (e is NotABill || e is StateError || e is HttpException) rethrow;
      final msg = e.toString().toLowerCase();
      if (msg.contains('socketexception') ||
          msg.contains('failed host lookup') ||
          msg.contains('connection abort')) {
        throw const SocketException('Network connection interrupted. Please check your network and try again.');
      }
      rethrow;
    }
  }
}

const BillExtractor _defaultExtractor = DefaultBillExtractor();

Future<Extraction> extractBill(File image, {BillExtractor extractor = _defaultExtractor, String? apiKey}) =>
    extractor.extract(image, apiKey: apiKey);

/// Fast, lightweight ping to test if a Gemini API key is valid and has quota.
Future<({bool ok, String message})> testApiKey(String apiKey) async {
  final key = apiKey.trim();
  if (key.isEmpty) return (ok: false, message: 'Please enter an API key.');
  try {
    final client = http.Client();
    final res = await client
        .get(
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$key&pageSize=1'),
          headers: {'x-goog-api-key': key, 'Connection': 'close'},
        )
        .timeout(const Duration(seconds: 10));
    client.close();

    if (res.statusCode == 200) {
      return (ok: true, message: 'API Key is valid and working!');
    } else if (res.statusCode == 400 || res.statusCode == 403) {
      return (ok: false, message: 'Invalid API key or unauthorized (HTTP ${res.statusCode}).');
    } else if (res.statusCode == 429) {
      return (ok: false, message: 'Quota exceeded or rate limited (HTTP 429).');
    } else {
      return (ok: false, message: 'Gemini service responded with error (${res.statusCode}).');
    }
  } on SocketException {
    return (ok: false, message: 'No internet connection. Please check your network.');
  } on http.ClientException catch (e) {
    return (ok: false, message: 'Connection error: ${e.message}');
  } catch (e) {
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('Failed host lookup')) {
      return (ok: false, message: 'No internet connection. Please check your network.');
    }
    return (ok: false, message: 'Network connection failed: $e');
  }
}

/// Dynamic AI Warranty Research: Searches the product's official manufacturer & retailer
/// warranty terms via Gemini AI and returns structured terms, justification, and support info.
Future<({List<Map<String, dynamic>> terms, String summary, String? support})> queryProductWarrantyPolicy({
  required String productName,
  required String brand,
  required String model,
  required String seller,
  String? apiKey,
}) async {
  final effectiveKey = (apiKey != null && apiKey.trim().isNotEmpty) ? apiKey.trim() : _key;
  if (effectiveKey.isEmpty) {
    throw StateError('Please configure your Gemini API Key in Settings to search warranty policies.');
  }

  final promptText = '''
You are an expert warranty researcher and consumer rights specialist for India and international consumer goods.
Search and determine the official manufacturer warranty policy and terms for this exact product:
- Product: $productName
- Brand: $brand
- Model: $model
- Retailer / Seller: $seller

Determine:
1. The exact official standard manufacturer warranty period (in months) in India.
2. If there are component-specific warranties (e.g. Battery vs Body, Panel vs TV, Motor vs Washing machine, Compressor vs AC), provide a list of terms.
3. Official customer care contact or helpline (toll-free number or email).
4. A 1-2 sentence concise summary explaining the coverage source (e.g. "Duracell India provides 2 Years (24 Months) replacement warranty for power banks via authorized distributors like Reliance Digital.").

Return ONLY a JSON object in this exact shape:
{
  "terms": [
    {"label": "Product", "months": 24, "source": "brand"}
  ],
  "summary": "Duracell power banks carry a 2-year (24 months) manufacturer warranty in India.",
  "support": "1800-120-7897 / info@uclindia.com"
}
''';

  final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$effectiveKey');
  final payload = jsonEncode({
    'contents': [
      {
        'parts': [{'text': promptText}]
      }
    ],
    'generationConfig': {'responseMimeType': 'application/json', 'temperature': 0.1},
  });

  final client = http.Client();
  try {
    final res = await client.post(
      uri,
      headers: {'x-goog-api-key': effectiveKey, 'content-type': 'application/json', 'Connection': 'close'},
      body: payload,
    ).timeout(const Duration(seconds: 25));

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final rawText = body['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '{}';
      final parsed = jsonDecode(rawText) as Map<String, dynamic>;
      final rawTerms = (parsed['terms'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return (
        terms: rawTerms,
        summary: parsed['summary']?.toString() ?? '',
        support: parsed['support']?.toString(),
      );
    } else {
      throw HttpException('Gemini search failed (${res.statusCode})');
    }
  } finally {
    client.close();
  }
}

