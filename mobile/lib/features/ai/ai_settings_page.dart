import 'package:flutter/material.dart';

import '../../services/ai_service.dart';

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  final _store = AiSettingsStore();
  final _endpoint = TextEditingController();
  final _model = TextEditingController();
  final _apiKey = TextEditingController();
  AiProvider _provider = AiProvider.openAiResponses;
  var _isLoading = true;
  var _hasKey = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _store.load();
    final hasKey = await _store.hasApiKey();
    if (!mounted) return;
    setState(() {
      _provider = settings.provider;
      _endpoint.text = settings.endpoint;
      _model.text = settings.model;
      _hasKey = hasKey;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _model.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(
          title: const Text('AI 分析設定',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('選擇 AI 服務',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('金鑰只保存在這台手機的安全儲存區，App 不會把金鑰傳送到你的後端。'),
        const SizedBox(height: 18),
        DropdownButtonFormField<AiProvider>(
          value: _provider,
          decoration: const InputDecoration(
              labelText: '供應商', border: OutlineInputBorder()),
          items: AiProvider.values
              .map((provider) => DropdownMenuItem(
                  value: provider, child: Text(provider.label)))
              .toList(),
          onChanged: (provider) {
            if (provider == null) return;
            setState(() {
              _provider = provider;
              _endpoint.text = provider.defaultEndpoint;
              _model.text = provider.defaultModel;
            });
          },
        ),
        const SizedBox(height: 12),
        TextField(
            controller: _endpoint,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
                labelText: 'API 基底網址',
                hintText: 'https://...',
                border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(
            controller: _model,
            decoration: const InputDecoration(
                labelText: '模型名稱',
                hintText: '請填供應商支援圖片的模型',
                border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(
            controller: _apiKey,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
                labelText: _hasKey ? 'API 金鑰（已設定；留空不變更）' : 'API 金鑰',
                border: const OutlineInputBorder())),
        const SizedBox(height: 16),
        FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('儲存 AI 設定')),
        if (_hasKey) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
              onPressed: _removeKey,
              icon: const Icon(Icons.key_off_outlined),
              label: const Text('從此裝置移除 API 金鑰')),
        ],
        const SizedBox(height: 28),
        Text('使用方式',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text(
            'OpenAI 相容 API 適用於有相容 Chat Completions 與圖片輸入功能的服務。選用的模型必須支援影像與 JSON 輸出；費用、用量限制與資料處理規則依各供應商帳戶設定為準。'),
      ]),
    );
  }

  Future<void> _save() async {
    if (_endpoint.text.trim().isEmpty || _model.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('請填寫 API 網址與模型名稱。')));
      return;
    }
    await _store.save(
        AiSettings(
            provider: _provider, endpoint: _endpoint.text, model: _model.text),
        apiKey: _apiKey.text);
    if (!mounted) return;
    setState(() {
      _hasKey = _hasKey || _apiKey.text.trim().isNotEmpty;
      _apiKey.clear();
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('AI 設定已儲存於此裝置。')));
  }

  Future<void> _removeKey() async {
    await _store.clearApiKey();
    if (!mounted) return;
    setState(() => _hasKey = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已從此裝置移除 API 金鑰。')));
  }
}
