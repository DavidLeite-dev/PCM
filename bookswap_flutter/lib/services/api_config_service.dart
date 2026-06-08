import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

/// Service to manage API configuration and provide debugging information
class ApiConfigService {
  /// Get current API configuration status
  static String getConfigStatus() {
    final buffer = StringBuffer();

    buffer.writeln('╔════════════════════════════════════════════════════╗');
    buffer.writeln('║          API CONFIGURATION STATUS                  ║');
    buffer.writeln('╚════════════════════════════════════════════════════╝');
    buffer.writeln('');

    // Mode
    buffer.writeln('📡 Modo: ${ApiConfig.useNgrok ? "NGROK" : "LOCALHOST"}');
    buffer.writeln('');

    // Base URL
    buffer.writeln('🌐 URL Base: ${ApiConfig.baseUrl}');
    buffer.writeln('');

    // Localhost config
    buffer.writeln('🖥️  Localhost: ${ApiConfig.localhostUrl}');
    buffer.writeln('');

    // NGROK config
    if (ApiConfig.useNgrok) {
      if (ApiConfig.ngrokUrl.isNotEmpty) {
        buffer.writeln('🚀 Ngrok URL: ${ApiConfig.ngrokUrl}');
      } else {
        buffer.writeln('⚠️  Ngrok habilitado, mas URL vazia!');
      }
    } else {
      buffer.writeln('ℹ️  Ngrok desabilitado (useNgrok = false)');
    }
    buffer.writeln('');

    // Endpoints
    buffer.writeln('📍 Endpoints:');
    buffer.writeln('  - Auth: ${ApiConfig.baseUrl}${ApiConfig.authEndpoint}');
    buffer.writeln('  - Books: ${ApiConfig.baseUrl}${ApiConfig.booksEndpoint}');
    buffer.writeln(
      '  - Transactions: ${ApiConfig.baseUrl}${ApiConfig.transactionsEndpoint}',
    );
    buffer.writeln('');

    // Timeout
    buffer.writeln('⏱️  Timeout: ${ApiConfig.requestTimeout.inSeconds}s');
    buffer.writeln('');

    buffer.writeln('╚════════════════════════════════════════════════════╝');

    return buffer.toString();
  }

  /// Initialize and log configuration (call this in main.dart)
  static void initializeAndLog() {
    final status = getConfigStatus();
    debugPrint(status);
  }

  /// Get setup instructions for ngrok
  static String getNgrokSetupInstructions() {
    return '''
╔════════════════════════════════════════════════════════════════════════════╗
║                    NGROK SETUP INSTRUCTIONS                               ║
╚════════════════════════════════════════════════════════════════════════════╝

1️⃣  CRIAR CONTA (GRÁTIS)
   👉 https://dashboard.ngrok.com/signup

2️⃣  OBTER AUTHTOKEN
   👉 https://dashboard.ngrok.com/get-started/your-authtoken
   Copie o token gerado

3️⃣  CONFIGURAR LOCALMENTE
   PowerShell:
   C:\\Users\\35193\\Downloads\\ngrok.exe config add-authtoken SEU_TOKEN

4️⃣  INICIAR TÚNEL
   PowerShell:
   C:\\Users\\35193\\Downloads\\ngrok.exe http 5003

5️⃣  COPIAR URL PÚBLICA
   Saída do ngrok:
   Forwarding                    https://xxxxx-xx-xxx-xx.eu.ngrok.io -> http://localhost:5003

6️⃣  ATUALIZAR APLICAÇÃO
   No arquivo lib/config/api_config.dart:
   
   static const String ngrokUrl = 'https://xxxxx-xx-xxx-xx.eu.ngrok.io';
   static const bool useNgrok = true;

7️⃣  EXECUTAR APP
   flutter run
   
   ✅ A app agora comunicará com a API via ngrok!

═══════════════════════════════════════════════════════════════════════════════

⚠️  IMPORTANTE:
   - A URL do ngrok muda a cada sessão (use a mais recente)
   - Certifique-se de que a API está rodando em http://localhost:5003
   - Use HTTPS (ngrok fornece certificado válido automaticamente)
''';
  }
}
