import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import '../config/api_config.dart';
import '../services/config_storage_service.dart';

class ServerConfigScreen extends StatefulWidget {
  final VoidCallback? onConfigured;

  const ServerConfigScreen({super.key, this.onConfigured});

  @override
  State<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends State<ServerConfigScreen>
    with WidgetsBindingObserver {
  late TextEditingController _ngrokUrlController;
  bool _isLocalhost = !ApiConfig.useNgrok;
  bool _isTestingConnection = false;
  String? _connectionStatus;
  Timer? _connectionCheckTimer;
  bool _apiRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ngrokUrlController = TextEditingController(text: ApiConfig.ngrokUrl);
    _checkApiStatus();
    // Verificar status a cada 5 segundos
    _connectionCheckTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkApiStatus(),
    );
  }

  @override
  void dispose() {
    _connectionCheckTimer?.cancel();
    _ngrokUrlController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkApiStatus() async {
    if (!mounted) return;

    try {
      final baseUrl = _isLocalhost ? ApiConfig.localhostUrl : _ngrokUrlController.text;
      
      if (baseUrl.isEmpty) {
        setState(() {
          _apiRunning = false;
          _connectionStatus = null;
        });
        return;
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/swagger/index.html'),
            headers: ApiConfig.getHeaders(),
          )
          .timeout(const Duration(seconds: 3));

      if (mounted) {
        setState(() {
          _apiRunning = response.statusCode == 200;
          _connectionStatus = _apiRunning
              ? '✅ API Ativa'
              : '❌ API Não Respondeu';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _apiRunning = false;
          _connectionStatus = '❌ Sem Conexão';
        });
      }
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = 'Testando...';
    });

    try {
      final baseUrl =
          _isLocalhost ? ApiConfig.localhostUrl : _ngrokUrlController.text;

      if (baseUrl.isEmpty) {
        setState(() {
          _connectionStatus = '❌ URL Vazia';
          _isTestingConnection = false;
        });
        return;
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/swagger/index.html'),
            headers: ApiConfig.getHeaders(),
          )
          .timeout(const Duration(seconds: 5));

      if (mounted) {
        setState(() {
          if (response.statusCode == 200) {
            _connectionStatus = '✅ Conexão Bem-Sucedida!';
            _apiRunning = true;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Conectado à API com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            _connectionStatus = '❌ Erro: ${response.statusCode}';
            _apiRunning = false;
          }
          _isTestingConnection = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionStatus = '❌ Erro: $e';
          _apiRunning = false;
          _isTestingConnection = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro de Conexão: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveConfiguration() async {
    // Save configuration using ConfigStorageService
    final success = await ConfigStorageService.saveServerConfig(
      isLocalhost: _isLocalhost,
      ngrokUrl: _ngrokUrlController.text,
    );

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isLocalhost
                  ? '✅ Configuração Salva: Localhost'
                  : '✅ Configuração Salva: ${_ngrokUrlController.text}',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Call callback if provided
        widget.onConfigured?.call();

        // Navigate back to app (triggers rebuild with new config)
        // This will cause main.dart to show LoginScreen instead
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/',
          (route) => false,
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Erro ao salvar configuração'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuração do Servidor'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              color: _apiRunning ? Colors.green.shade50 : Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status da Conexão',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          _apiRunning ? Icons.check_circle : Icons.error,
                          color: _apiRunning ? Colors.green : Colors.red,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _connectionStatus ?? 'Verificando...',
                            style: TextStyle(
                              fontSize: 16,
                              color:
                                  _apiRunning ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Mode Selection
            Text(
              'Modo de Conexão',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  RadioListTile<bool>(
                    title: const Text('📡 Localhost (Local)'),
                    subtitle: const Text('http://192.168.1.18:5003'),
                    value: true,
                    // ignore: deprecated_member_use
                    groupValue: _isLocalhost,
                    // ignore: deprecated_member_use
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _isLocalhost = value);
                        _checkApiStatus();
                      }
                    },
                  ),
                  const Divider(height: 0),
                  RadioListTile<bool>(
                    title: const Text('🌐 Ngrok (Internet)'),
                    subtitle: const Text('https://xxxxx.ngrok.io'),
                    value: false,
                    // ignore: deprecated_member_use
                    groupValue: _isLocalhost,
                    // ignore: deprecated_member_use
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _isLocalhost = value);
                        _checkApiStatus();
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Ngrok URL Input (if ngrok selected)
            if (!_isLocalhost) ...[
              Text(
                'URL do Ngrok',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _ngrokUrlController,
                decoration: InputDecoration(
                  hintText: 'https://xxxxx-xx-xxx.eu.ngrok.io',
                  prefixIcon: const Icon(Icons.link),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  helperText:
                      'Cole a URL completa do ngrok (com https://)',
                ),
                onChanged: (_) => _checkApiStatus(),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📖 Como Obter a URL do Ngrok:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Execute: ngrok http 5003\n'
                      '2. Copie a URL exibida (https://...)\n'
                      '3. Cole aqui',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isTestingConnection ? null : _testConnection,
                icon: const Icon(Icons.cloud_queue),
                label: _isTestingConnection
                    ? const Text('Testando...')
                    : const Text('Testar Conexão'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _apiRunning ? _saveConfiguration : null,
                icon: const Icon(Icons.save),
                label: const Text('Salvar e Continuar'),
              ),
            ),
            const SizedBox(height: 16),
            if (!_apiRunning)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '⚠️  API Não Detectada',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isLocalhost
                          ? 'Certifique-se de que a API está rodando:\ndotnet run (na pasta BookSwapAPI)'
                          : 'Verifique se ngrok está ativo e a URL está correta',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
