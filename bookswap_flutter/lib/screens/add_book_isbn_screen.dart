import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/book_provider.dart';
import '../providers/auth_provider.dart';
import '../models/book.dart';

class AddBookISBNScreen extends StatefulWidget {
  const AddBookISBNScreen({super.key});

  @override
  State<AddBookISBNScreen> createState() => _AddBookISBNScreenState();
}

class _AddBookISBNScreenState extends State<AddBookISBNScreen> {
  final _isbnController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  Book? _foundBook;
  String _selectedCondition = BookConditions.novo;
  int _quantity = 1;
  bool _searching = false;
  String? _searchError;

  @override
  void dispose() {
    _isbnController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _lookupISBN() async {
    final isbn = _isbnController.text.trim();
    if (isbn.isEmpty) {
      setState(() => _searchError = 'Por favor, introduza um ISBN');
      return;
    }

    setState(() {
      _searching = true;
      _searchError = null;
    });

    final bookProvider = context.read<BookProvider>();
    final book = await bookProvider.lookupISBN(isbn);

    if (!mounted) return;

    if (book != null) {
      setState(() {
        _foundBook = book;
        _searching = false;
        _selectedCondition = BookConditions.novo;
        _quantity = 1;
      });
    } else {
      setState(() {
        _searching = false;
        _searchError =
            bookProvider.error ?? 'Livro não encontrado. Verifique o ISBN.';
      });
    }
  }

  Future<void> _registerBook() async {
    if (_foundBook == null) return;

    final authProvider = context.read<AuthProvider>();
    final userEmail = authProvider.currentUser?.email ?? 'unknown@email.com';

    final bookProvider = context.read<BookProvider>();
    final success = await bookProvider.registerBook(
      isbn: _foundBook!.isbn,
      userEmail: userEmail,
      condition: _selectedCondition,
      quantity: _quantity,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Livro registado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      // Clear form
      _isbnController.clear();
      _quantityController.text = '1';
      setState(() {
        _foundBook = null;
        _selectedCondition = BookConditions.novo;
        _quantity = 1;
        _searchError = null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(bookProvider.error ?? 'Erro ao registar livro'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar Livro por ISBN'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ISBN Input
            TextField(
              controller: _isbnController,
              decoration: InputDecoration(
                labelText: 'ISBN (10 ou 13 dígitos)',
                hintText: 'ex: 978-0-13-468599-1',
                prefixIcon: const Icon(Icons.barcode_reader),
                errorText: _searchError,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) {
                // Clear error when user types
                if (_searchError != null) {
                  setState(() => _searchError = null);
                }
              },
            ),
            const SizedBox(height: 16),

            // Search Button
            ElevatedButton.icon(
              onPressed: _searching ? null : _lookupISBN,
              icon: _searching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(_searching ? 'Procurando...' : 'Procurar Livro'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 24),

            // Book Details (if found)
            if (_foundBook != null) ...[
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cover Image
                      if (_foundBook!.coverImageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _foundBook!.coverImageUrl,
                            height: 150,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  height: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.image_not_supported),
                                ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        _foundBook!.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Authors
                      if (_foundBook!.authors.isNotEmpty)
                        Text(
                          'Autores: ${_foundBook!.authors}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      const SizedBox(height: 8),

                      // Genre
                      if (_foundBook!.genre.isNotEmpty)
                        Text(
                          'Género: ${_foundBook!.genre}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      const SizedBox(height: 8),

                      // Tags
                      if (_foundBook!.tags.isNotEmpty)
                        Text(
                          'Etiquetas: ${_foundBook!.tags}',
                          style: const TextStyle(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 8),

                      // Publisher
                      if (_foundBook!.publisher.isNotEmpty)
                        Text(
                          'Editora: ${_foundBook!.publisher}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      const SizedBox(height: 8),

                      // Publication Year
                      if (_foundBook!.publicationYear != null)
                        Text(
                          'Ano: ${_foundBook!.publicationYear}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      const SizedBox(height: 8),

                      // ISBN
                      Text(
                        'ISBN: ${_foundBook!.isbn}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Condition Selection
              Text(
                'Estado do Livro',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Column(
                children: BookConditions.all.map((condition) {
                  return RadioListTile<String>(
                    title: Text(BookConditions.getLabel(condition)),
                    value: condition,
                    // ignore: deprecated_member_use
                    groupValue: _selectedCondition,
                    // ignore: deprecated_member_use
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedCondition = value);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Quantity
              Text(
                'Quantidade',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    onPressed: _quantity > 1
                        ? () {
                            setState(() {
                              _quantity--;
                              _quantityController.text = _quantity.toString();
                            });
                          }
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Expanded(
                    child: TextField(
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      controller: _quantityController,
                      onChanged: (value) {
                        final parsed = int.tryParse(value);
                        if (parsed != null && parsed > 0) {
                          setState(() => _quantity = parsed);
                        }
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _quantity++;
                        _quantityController.text = _quantity.toString();
                      });
                    },
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Register Button
              ElevatedButton(
                onPressed: context.watch<BookProvider>().isLoading
                    ? null
                    : _registerBook,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                ),
                child: context.watch<BookProvider>().isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Registar Livro',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 16),

              // Change Book Button
              OutlinedButton(
                onPressed: () {
                  setState(() => _foundBook = null);
                },
                child: const Text('Mudar Livro'),
              ),
            ] else if (!_searching && _searchError == null)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.barcode_reader,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Introduza um ISBN para procurar um livro',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
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
