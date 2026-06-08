import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/api_config_service.dart';

/// Debug widget to display current API configuration
/// Useful during development to verify ngrok setup
class ApiConfigDebugWidget extends StatelessWidget {
  final bool show;

  const ApiConfigDebugWidget({
    super.key,
    this.show = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!show) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ApiConfig.useNgrok ? Colors.green.shade900 : Colors.blue.shade900,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ApiConfig.useNgrok ? Colors.green : Colors.blue,
          width: 2,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Icon(
                  ApiConfig.useNgrok ? Icons.cloud : Icons.computer,
                  color: ApiConfig.useNgrok ? Colors.green : Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ApiConfig.useNgrok ? '🚀 NGROK ATIVO' : '🖥️  LOCALHOST',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // API URL
            Text(
              'URL Base:',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.grey.shade300,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              ApiConfig.baseUrl,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 12),
            
            // Ngrok status
            if (ApiConfig.useNgrok)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ngrok URL:',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey.shade300,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    ApiConfig.ngrokUrl.isNotEmpty 
                      ? ApiConfig.ngrokUrl 
                      : '⚠️  URL não configurada',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.yellow.shade200,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _showConfigStatus(context);
                  },
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Status'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _showNgrokSetup(context);
                  },
                  icon: const Icon(Icons.help_outline, size: 16),
                  label: const Text('Setup'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showConfigStatus(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Configuration Status'),
        content: SingleChildScrollView(
          child: SelectableText(
            ApiConfigService.getConfigStatus(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  void _showNgrokSetup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ngrok Setup Instructions'),
        content: SingleChildScrollView(
          child: SelectableText(
            ApiConfigService.getNgrokSetupInstructions(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}
