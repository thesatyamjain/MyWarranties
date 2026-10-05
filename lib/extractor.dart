import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Run with: flutter run --dart-define=GEMINI_API_KEY=xxxx
/// ponytail: key ships in the client for MVP. Move the call behind a
/// Cloud Function before any public release.
const _key = String.fromEnvironment('GEMINI_API_KEY');
const _model = 'gemini-2.5-flash';

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
You read purchase bills / invoices (India: GST invoices, thermal store bills, marketplace invoices; English or Hindi).
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
           "confidence":n}]}

For "standard_warranty_terms":
- If standard brand/manufacturer warranty policy in India is known for this product/category/model, provide accurate breakdown in months.
- E.g. TV -> [{"label":"Product","months":12,"source":"brand"},{"label":"Panel","months":24,"source":"brand"}]
- E.g. AC -> [{"label":"Product","months":12,"source":"brand"},{"label":"Compressor","months":120,"source":"brand"}]
- E.g. Smartphone -> [{"label":"Product","months":12,"source":"brand"}]
- E.g. Washing machine -> [{"label":"Product","months":24,"source":"brand"},{"label":"Motor","months":120,"source":"brand"}]
Include every product line item. If the image is not a bill, return {"is_bill": false}.
''';

Future<Extraction> extractBill(File image) async {
  if (_key.isEmpty) {
    throw StateError('Missing GEMINI_API_KEY (use --dart-define=GEMINI_API_KEY=...)');
  }
  final res = await http
      .post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent'),
        headers: {'x-goog-api-key': _key, 'content-type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': _prompt},
                {
                  'inline_data': {
                    'mime_type': image.path.toLowerCase().endsWith('.pdf')
                        ? 'application/pdf'
                        : 'image/jpeg',
                    'data': base64Encode(await image.readAsBytes())
                  }
                }
              ]
            }
          ],
          'generationConfig': {'responseMimeType': 'application/json', 'temperature': 0},
        }),
      )
      .timeout(const Duration(seconds: 45));
  if (res.statusCode != 200) throw HttpException('Extraction failed (${res.statusCode})');
  final text = jsonDecode(res.body)['candidates'][0]['content']['parts'][0]['text'];
  final j = jsonDecode(text) as Map<String, dynamic>;
  if (j['is_bill'] == false) throw NotABill();
  return Extraction(j);
}
