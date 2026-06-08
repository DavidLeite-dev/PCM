import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_setting_service.dart';
import '../services/api_client.dart';

class SystemConfigurationScreen extends StatefulWidget {
  const SystemConfigurationScreen({super.key});

  @override
  State<SystemConfigurationScreen> createState() =>
      _SystemConfigurationScreenState();
}

class _SystemConfigurationScreenState extends State<SystemConfigurationScreen> {
  late AppSettingService _appSettingService;
  bool _allowDuplicateBooks = false;
  bool _showSingleBookCondition = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _appSettingService = AppSettingService(
      apiClient: context.read<ApiClient>(),
    );
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final allowDuplicates = await _appSettingService.getAllowDuplicateBooks();
      final showSingleCondition = await _appSettingService
          .getShowSingleBookCondition();

      if (mounted) {
        setState(() {
          _allowDuplicateBooks = allowDuplicates;
          _showSingleBookCondition = showSingleCondition;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar configurações: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateAllowDuplicateBooks(bool value) async {
    try {
      await _appSettingService.updateSetting(
        'AllowDuplicateBooks',
        value.toString(),
      );
      if (mounted) {
        setState(() {
          _allowDuplicateBooks = value;
          _error = null;
        });
        _showSuccessMessage('Configuração atualizada com sucesso');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao atualizar: $e';
        });
        _showErrorMessage('Erro: $e');
      }
    }
  }

  Future<void> _updateShowSingleBookCondition(bool value) async {
    try {
      await _appSettingService.updateSetting(
        'ShowSingleBookCondition',
        value.toString(),
      );
      if (mounted) {
        setState(() {
          _showSingleBookCondition = value;
          _error = null;
        });
        _showSuccessMessage('Configuração atualizada com sucesso');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao atualizar: $e';
        });
        _showErrorMessage('Erro: $e');
      }
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuração do Sistema'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadSettings,
                    child: const Text('Tentar Novamente'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configurações de Livros',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Permitir Livros Duplicados'),
                          subtitle: const Text(
                            'Permite que múltiplos utilizadores tenham o mesmo livro',
                          ),
                          value: _allowDuplicateBooks,
                          onChanged: _updateAllowDuplicateBooks,
                        ),
                        const Divider(height: 32),
                        SwitchListTile(
                          title: const Text('Mostrar Condição Única'),
                          subtitle: const Text(
                            'Exibe a condição de um único livro em vez de listar todas',
                          ),
                          value: _showSingleBookCondition,
                          onChanged: _updateShowSingleBookCondition,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informações',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '• Permitir Livros Duplicados: Quando ativado, vários utilizadores podem registar o mesmo livro no sistema.',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '• Mostrar Condição Única: Quando ativado, apenas a condição de melhor estado é exibida para cada livro.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
