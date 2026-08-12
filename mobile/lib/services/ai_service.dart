import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum AiProvider { openAiResponses, openAiCompatible, gemini, anthropic }

extension AiProviderLabel on AiProvider {
  String get label => switch (this) {
        AiProvider.openAiResponses => 'OpenAI Responses API',
        AiProvider.openAiCompatible => 'OpenAI 相容 API（自訂）',
        AiProvider.gemini => 'Google Gemini',
        AiProvider.anthropic => 'Anthropic Claude',
      };

  String get defaultEndpoint => switch (this) {
        AiProvider.openAiResponses => 'https://api.openai.com/v1',
        AiProvider.openAiCompatible => 'https://api.openai.com/v1',
        AiProvider.gemini => 'https://generativelanguage.googleapis.com/v1beta',
        AiProvider.anthropic => 'https://api.anthropic.com/v1',
      };

  String get defaultModel => switch (this) {
        AiProvider.openAiResponses => 'gpt-4.1-mini',
        AiProvider.openAiCompatible => '',
        AiProvider.gemini => 'gemini-2.5-flash',
        AiProvider.anthropic => 'claude-sonnet-4-20250514',
      };
}

class AiSettings {
  const AiSettings(
      {required this.provider, required this.endpoint, required this.model});

  final AiProvider provider;
  final String endpoint;
  final String model;

  AiSettings copyWith(
          {AiProvider? provider, String? endpoint, String? model}) =>
      AiSettings(
        provider: provider ?? this.provider,
        endpoint: endpoint ?? this.endpoint,
        model: model ?? this.model,
      );
}

class AiSettingsStore {
  static const _providerKey = 'ai_provider';
  static const _endpointKey = 'ai_endpoint';
  static const _modelKey = 'ai_model';
  static const _apiKeyName = 'ai_provider_api_key';
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<AiSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final provider = AiProvider.values.firstWhere(
      (value) => value.name == prefs.getString(_providerKey),
      orElse: () => AiProvider.openAiResponses,
    );
    return AiSettings(
      provider: provider,
      endpoint: prefs.getString(_endpointKey) ?? provider.defaultEndpoint,
      model: prefs.getString(_modelKey) ?? provider.defaultModel,
    );
  }

  Future<void> save(AiSettings settings, {String? apiKey}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, settings.provider.name);
    await prefs.setString(_endpointKey,
        settings.endpoint.trim().replaceFirst(RegExp(r'/+$'), ''));
    await prefs.setString(_modelKey, settings.model.trim());
    if (apiKey != null && apiKey.trim().isNotEmpty)
      await _secureStorage.write(key: _apiKeyName, value: apiKey.trim());
  }

  Future<bool> hasApiKey() async =>
      (await _secureStorage.read(key: _apiKeyName))?.isNotEmpty == true;
  Future<String?> readApiKey() => _secureStorage.read(key: _apiKeyName);
  Future<void> clearApiKey() => _secureStorage.delete(key: _apiKeyName);
}

class AiMealAnalysis {
  const AiMealAnalysis(
      {required this.items, required this.confidence, required this.notes});

  final List<AiFoodItem> items;
  final double confidence;
  final String notes;
  int get totalCalories =>
      items.fold(0, (total, item) => total + item.calories);
  double get totalProtein =>
      items.fold(0, (total, item) => total + item.protein);
  String get suggestedName => items.map((item) => item.name).join('、');
}

class AiFoodItem {
  const AiFoodItem(
      {required this.name, required this.calories, required this.protein});
  final String name;
  final int calories;
  final double protein;
}

class AiWeightPlan {
  const AiWeightPlan(
      {required this.goalWeight,
      required this.weeklyLossKg,
      required this.dailyCalories,
      required this.proteinGrams,
      required this.activeCalories,
      required this.summary});
  final double goalWeight;
  final double weeklyLossKg;
  final int dailyCalories;
  final double proteinGrams;
  final int activeCalories;
  final String summary;
}

class AiDailyAdvice {
  const AiDailyAdvice({required this.headline, required this.advice});
  final String headline;
  final String advice;
}

class AiService {
  AiService({AiSettingsStore? settingsStore, http.Client? client})
      : _settingsStore = settingsStore ?? AiSettingsStore(),
        _client = client ?? http.Client();

  final AiSettingsStore _settingsStore;
  final http.Client _client;

  Future<AiMealAnalysis> analyzeImage(
      {required Uint8List imageBytes, required String mimeType}) async {
    final settings = await _settingsStore.load();
    final apiKey = await _settingsStore.readApiKey();
    if (apiKey == null || apiKey.isEmpty)
      throw const AiServiceException('請先在「目標」頁面的 AI 分析設定輸入 API 金鑰。');
    if (settings.model.trim().isEmpty)
      throw const AiServiceException('請先設定要使用的 AI 模型名稱。');
    if (imageBytes.lengthInBytes > 8 * 1024 * 1024)
      throw const AiServiceException('圖片過大，請選擇 8 MB 以下的圖片。');
    final base64Image = base64Encode(imageBytes);
    final response = switch (settings.provider) {
      AiProvider.openAiResponses =>
        await _openAiResponses(settings, apiKey, base64Image, mimeType),
      AiProvider.openAiCompatible =>
        await _openAiCompatible(settings, apiKey, base64Image, mimeType),
      AiProvider.gemini =>
        await _gemini(settings, apiKey, base64Image, mimeType),
      AiProvider.anthropic =>
        await _anthropic(settings, apiKey, base64Image, mimeType),
    };
    return _parseAnalysis(response);
  }

  Future<AiWeightPlan> createWeightPlan(
      {required double currentWeight,
      required double heightCm,
      required int age,
      required String sex,
      required double bmi,
      double? desiredWeight}) async {
    final settings = await _settingsStore.load();
    final apiKey = await _settingsStore.readApiKey();
    if (apiKey == null || apiKey.isEmpty)
      throw const AiServiceException('請先在「目標」頁面的 AI 分析設定輸入 API 金鑰。');
    if (settings.model.trim().isEmpty)
      throw const AiServiceException('請先設定要使用的 AI 模型名稱。');
    final goalInstruction = desiredWeight == null
        ? '請依安全、漸進的原則建議一個合理目標體重。'
        : '使用者指定的目標體重是 ${desiredWeight.toStringAsFixed(1)} kg，請以此為目標。';
    final prompt =
        '''你是一般健康管理的減重教練，不提供醫療診斷。使用者資料：體重 ${currentWeight.toStringAsFixed(1)} kg、身高 ${heightCm.toStringAsFixed(0)} cm、年齡 $age、生理性別 $sex、BMI ${bmi.toStringAsFixed(1)}。$goalInstruction
請規劃每日熱量、蛋白質與運動目標。`active_calories` 是每日「運動額外消耗」的 kcal 目標，不是全天總消耗；一般減重計畫請設定在 300 至 500 kcal，且在 summary 清楚說明這是額外運動消耗。只輸出 JSON：
{"goal_weight_kg":數字,"weekly_loss_kg":0.1至0.75的數字,"daily_calories":整數,"protein_g":數字,"active_calories":整數,"summary":"繁體中文的簡短說明與提醒"}
不可建議極端節食；若資料不足或可能需要專業協助，請在 summary 說明。''';
    final raw = await _requestText(settings, apiKey, prompt);
    try {
      final data = jsonDecode(raw
          .trim()
          .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '')) as Map<String, dynamic>;
      return AiWeightPlan(
        goalWeight:
            ((data['goal_weight_kg'] as num? ?? currentWeight).toDouble())
                .clamp(35, currentWeight)
                .toDouble(),
        weeklyLossKg: ((data['weekly_loss_kg'] as num? ?? 0.3).toDouble())
            .clamp(0.1, 0.75)
            .toDouble(),
        dailyCalories: (data['daily_calories'] as num? ?? 1800)
            .round()
            .clamp(1200, 4000)
            .toInt(),
        proteinGrams: ((data['protein_g'] as num? ?? 90).toDouble())
            .clamp(40, 250)
            .toDouble(),
        activeCalories: (data['active_calories'] as num? ?? 350)
            .round()
            .clamp(300, 600)
            .toInt(),
        summary: data['summary']?.toString() ?? '請依身體反應與實際執行情況調整。',
      );
    } catch (_) {
      throw const AiServiceException('AI 回覆格式無法辨識，請再試一次或更換模型。');
    }
  }

  Future<AiDailyAdvice> createDailyAdvice({
    required String meals,
    required int caloriesConsumed,
    required int calorieTarget,
    required double proteinConsumed,
    required double proteinTarget,
    required int steps,
    required int exerciseMinutes,
    required int activeCalories,
    required int activeCaloriesTarget,
    required double goalWeight,
  }) async {
    final settings = await _settingsStore.load();
    final apiKey = await _settingsStore.readApiKey();
    if (apiKey == null || apiKey.isEmpty)
      throw const AiServiceException('請先在設定的 AI 服務輸入 API 金鑰。');
    final prompt = '''你是一般健康管理的飲食教練。依以下今日資料給一則務實、簡短、不帶醫療診斷的繁體中文建議。
餐點：$meals
熱量：$caloriesConsumed / $calorieTarget kcal；蛋白質：${proteinConsumed.toStringAsFixed(0)} / ${proteinTarget.toStringAsFixed(0)} g。
步數：$steps；運動時間：$exerciseMinutes 分鐘；運動額外消耗：$activeCalories / $activeCaloriesTarget kcal。
目前減重目標體重：${goalWeight.toStringAsFixed(1)} kg。
只輸出 JSON：{"headline":"12字內標題","advice":"1至2句具體建議"}。不要危險節食或醫療建議。''';
    final raw = await _requestText(settings, apiKey, prompt);
    try {
      final data = jsonDecode(raw
          .trim()
          .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '')) as Map<String, dynamic>;
      final headline = data['headline']?.toString().trim() ?? '';
      final advice = data['advice']?.toString().trim() ?? '';
      if (headline.isEmpty || advice.isEmpty) throw const FormatException();
      return AiDailyAdvice(headline: headline, advice: advice);
    } catch (_) {
      throw const AiServiceException('AI 回覆格式無法辨識，請再試一次或更換模型。');
    }
  }

  static const _prompt = '''分析這張餐點照片，估算可食用部分的熱量與蛋白質。請只輸出 JSON：
{"items":[{"name":"食物名稱","calories":整數,"protein_g":數字}],"confidence":0到1之間的數字,"notes":"簡短且說明估算不確定性"}
不可辨識的食物請省略；不要輸出 Markdown 或額外文字。''';

  Future<String> _openAiResponses(
      AiSettings s, String key, String image, String mime) async {
    final result = await _post('${s.endpoint}/responses', {
      'Authorization': 'Bearer $key'
    }, {
      'model': s.model,
      'store': false,
      'input': [
        {
          'role': 'user',
          'content': [
            {'type': 'input_text', 'text': _prompt},
            {'type': 'input_image', 'image_url': 'data:$mime;base64,$image'},
          ]
        }
      ],
      'text': {
        'format': {'type': 'json_object'}
      },
    });
    final data = jsonDecode(result) as Map<String, dynamic>;
    final output = data['output'] as List<dynamic>? ?? [];
    for (final item in output) {
      final content =
          (item as Map<String, dynamic>)['content'] as List<dynamic>? ?? [];
      for (final part in content) {
        final text = (part as Map<String, dynamic>)['text'];
        if (text is String && text.isNotEmpty) return text;
      }
    }
    if (data['output_text'] is String) return data['output_text'] as String;
    throw const AiServiceException('AI 沒有回傳可讀取的分析結果。');
  }

  Future<String> _openAiCompatible(
      AiSettings s, String key, String image, String mime) async {
    final result = await _post('${s.endpoint}/chat/completions', {
      'Authorization': 'Bearer $key'
    }, {
      'model': s.model,
      'messages': [
        {'role': 'system', 'content': '你是營養分析助理。請嚴格遵循使用者要求的 JSON 格式。'},
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': _prompt},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:$mime;base64,$image'}
            },
          ]
        },
      ],
      'response_format': {'type': 'json_object'},
    });
    final data = jsonDecode(result) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>? ?? [];
    final content = choices.isEmpty
        ? null
        : ((choices.first as Map<String, dynamic>)['message']
            as Map<String, dynamic>?)?['content'];
    if (content is String) return content;
    throw const AiServiceException('AI 沒有回傳可讀取的分析結果。');
  }

  Future<String> _gemini(
      AiSettings s, String key, String image, String mime) async {
    final result =
        await _post('${s.endpoint}/models/${s.model}:generateContent', {
      'x-goog-api-key': key
    }, {
      'contents': [
        {
          'parts': [
            {'text': _prompt},
            {
              'inlineData': {'mimeType': mime, 'data': image}
            },
          ]
        }
      ],
      'generationConfig': {'responseMimeType': 'application/json'},
    });
    final data = jsonDecode(result) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>? ?? [];
    final parts = candidates.isEmpty
        ? null
        : (((candidates.first as Map<String, dynamic>)['content']
            as Map<String, dynamic>?)?['parts'] as List<dynamic>?);
    final text = parts?.isEmpty == false
        ? (parts!.first as Map<String, dynamic>)['text']
        : null;
    if (text is String) return text;
    throw const AiServiceException('Gemini 沒有回傳可讀取的分析結果。');
  }

  Future<String> _anthropic(
      AiSettings s, String key, String image, String mime) async {
    final result = await _post('${s.endpoint}/messages', {
      'x-api-key': key,
      'anthropic-version': '2023-06-01'
    }, {
      'model': s.model,
      'max_tokens': 1024,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {'type': 'base64', 'media_type': mime, 'data': image}
            },
            {'type': 'text', 'text': _prompt},
          ]
        }
      ],
    });
    final data = jsonDecode(result) as Map<String, dynamic>;
    final content = data['content'] as List<dynamic>? ?? [];
    final text = content.isEmpty
        ? null
        : (content.first as Map<String, dynamic>)['text'];
    if (text is String) return text;
    throw const AiServiceException('Claude 沒有回傳可讀取的分析結果。');
  }

  Future<String> _requestText(AiSettings s, String key, String prompt) async {
    switch (s.provider) {
      case AiProvider.openAiResponses:
        final raw = await _post('${s.endpoint}/responses', {
          'Authorization': 'Bearer $key'
        }, {
          'model': s.model,
          'store': false,
          'input': prompt,
          'text': {
            'format': {'type': 'json_object'}
          }
        });
        return _responseText(raw);
      case AiProvider.openAiCompatible:
        final raw = await _post('${s.endpoint}/chat/completions', {
          'Authorization': 'Bearer $key'
        }, {
          'model': s.model,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'response_format': {'type': 'json_object'}
        });
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>? ?? [];
        final content = choices.isEmpty
            ? null
            : ((choices.first as Map<String, dynamic>)['message']
                as Map<String, dynamic>?)?['content'];
        if (content is String) return content;
        throw const AiServiceException('AI 沒有回傳可讀取的計畫。');
      case AiProvider.gemini:
        final raw =
            await _post('${s.endpoint}/models/${s.model}:generateContent', {
          'x-goog-api-key': key
        }, {
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {'responseMimeType': 'application/json'}
        });
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final candidates = data['candidates'] as List<dynamic>? ?? [];
        final parts = candidates.isEmpty
            ? null
            : (((candidates.first as Map<String, dynamic>)['content']
                as Map<String, dynamic>?)?['parts'] as List<dynamic>?);
        final text = parts?.isEmpty == false
            ? (parts!.first as Map<String, dynamic>)['text']
            : null;
        if (text is String) return text;
        throw const AiServiceException('Gemini 沒有回傳可讀取的計畫。');
      case AiProvider.anthropic:
        final raw = await _post('${s.endpoint}/messages', {
          'x-api-key': key,
          'anthropic-version': '2023-06-01'
        }, {
          'model': s.model,
          'max_tokens': 1024,
          'messages': [
            {'role': 'user', 'content': prompt}
          ]
        });
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final content = data['content'] as List<dynamic>? ?? [];
        final text = content.isEmpty
            ? null
            : (content.first as Map<String, dynamic>)['text'];
        if (text is String) return text;
        throw const AiServiceException('Claude 沒有回傳可讀取的計畫。');
    }
    throw const AiServiceException('AI 沒有回傳可讀取的計畫。');
  }

  String _responseText(String raw) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['output_text'] is String) return data['output_text'] as String;
    final output = data['output'] as List<dynamic>? ?? [];
    for (final item in output) {
      final content =
          (item as Map<String, dynamic>)['content'] as List<dynamic>? ?? [];
      for (final part in content) {
        final text = (part as Map<String, dynamic>)['text'];
        if (text is String && text.isNotEmpty) return text;
      }
    }
    throw const AiServiceException('AI 沒有回傳可讀取的計畫。');
  }

  Future<String> _post(String url, Map<String, String> headers,
      Map<String, dynamic> body) async {
    final response = await _client
        .post(Uri.parse(url),
            headers: {'Content-Type': 'application/json', ...headers},
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 60));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'HTTP ${response.statusCode}';
      try {
        message = (jsonDecode(response.body) as Map<String, dynamic>)['error']
                    ?['message']
                ?.toString() ??
            message;
      } catch (_) {}
      throw AiServiceException('AI 服務回應失敗：$message');
    }
    return response.body;
  }

  AiMealAnalysis _parseAnalysis(String raw) {
    final cleaned = raw
        .trim()
        .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '');
    try {
      final data = jsonDecode(cleaned) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((item) {
            final value = item as Map<String, dynamic>;
            return AiFoodItem(
                name: value['name']?.toString() ?? '未命名食物',
                calories: (value['calories'] as num? ?? 0)
                    .round()
                    .clamp(0, 5000)
                    .toInt(),
                protein: (value['protein_g'] as num? ?? 0)
                    .toDouble()
                    .clamp(0, 500)
                    .toDouble());
          })
          .where((item) => item.calories > 0 || item.protein > 0)
          .toList();
      if (items.isEmpty) throw const FormatException();
      return AiMealAnalysis(
          items: items,
          confidence: ((data['confidence'] as num? ?? 0.5).toDouble())
              .clamp(0, 1)
              .toDouble(),
          notes: data['notes']?.toString() ?? '這是影像估算，請依實際份量調整。');
    } catch (_) {
      throw const AiServiceException('AI 回覆格式無法辨識，請改用支援圖片與 JSON 輸出的模型。');
    }
  }
}

class AiServiceException implements Exception {
  const AiServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}
