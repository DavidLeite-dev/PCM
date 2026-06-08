import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';

class AdminBooksScreen extends StatefulWidget {
  const AdminBooksScreen({super.key});

  @override
  State<AdminBooksScreen> createState() => _AdminBooksScreenState();
}

class _AdminBooksScreenState extends State<AdminBooksScreen> {
  late ApiClient _apiClient;
  List<Map<String, dynamic>> _books = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = false;
  String? _error;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _apiClient = context.read<ApiClient>();
    _loadBooks();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.of(_books)
          : _books.where((b) {
              return (b['title'] as String? ?? '').toLowerCase().contains(q) ||
                  (b['authors'] as String? ?? '').toLowerCase().contains(q) ||
                  (b['isbn'] as String? ?? '').toLowerCase().contains(q) ||
                  (b['genre'] as String? ?? '').toLowerCase().contains(q);
            }).toList();
    });
  }

  Future<void> _loadBooks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _apiClient.get('/admin/books');
      final raw = (response is Map && response['books'] is List)
          ? (response['books'] as List).cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];
      setState(() {
        _books = raw;
        _filtered = List.of(raw);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar livros: $e';
        _isLoading = false;
      });
    }
  }

  static const List<String> _predefinedGenres = [
    'Action', 'Adventure', 'Biography', "Children's", 'Comedy', 'Crime',
    'Drama', 'Dystopian Fiction', 'Essay', 'Fantasy', 'Fiction',
    'Graphic Novel', 'Historical Fiction', 'Horror', 'History',
    'Literary Fiction', 'Memoir', 'Mystery', 'Non-fiction', 'Paranormal',
    'Poetry', 'Romance', 'Romance Fiction', 'Science', 'Science Fiction',
    'Self-help', 'Short Stories', 'Steampunk', 'Suspense', 'Thriller',
    'True Crime', 'Western', 'Young Adult',
  ];

  Future<void> _editBook(Map<String, dynamic> book) async {
    List<String> availableAuthors = [];
    List<String> availableGenres = List.of(_predefinedGenres);
    try {
      final authorsRes = await _apiClient.get('/admin/authors');
      if (authorsRes is Map && authorsRes['authors'] is List) {
        availableAuthors = (authorsRes['authors'] as List).cast<String>();
      }
      final genresRes = await _apiClient.get('/admin/genres');
      if (genresRes is Map && genresRes['genres'] is List) {
        availableGenres = (genresRes['genres'] as List).cast<String>();
      }
    } catch (_) {}

    if (!mounted) return;

    final titleCtrl = TextEditingController(text: book['title'] as String? ?? '');
    final publisherCtrl = TextEditingController(text: book['publisher'] as String? ?? '');
    final yearCtrl = TextEditingController(text: (book['publicationYear'] ?? '').toString());
    final coverCtrl = TextEditingController(text: book['coverImageUrl'] as String? ?? '');
    final tagsCtrl = TextEditingController(text: book['tags'] as String? ?? '');
    final newAuthorCtrl = TextEditingController();

    List<String> selectedAuthors = (book['authors'] as String? ?? '')
        .split(',')
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toList();

    String? selectedGenre = (book['genre'] as String? ?? '').isEmpty
        ? null
        : book['genre'] as String?;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.edit, size: 20),
                SizedBox(width: 8),
                Text('Editar Livro'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ISBN: ${book['isbn'] ?? '-'}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(height: 12),

                    // Title
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Título *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Authors chips
                    const Text('Autores',
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: selectedAuthors
                          .map((a) => Chip(
                                label: Text(a, style: const TextStyle(fontSize: 12)),
                                onDeleted: () =>
                                    setDialogState(() => selectedAuthors.remove(a)),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 6),
                    // Select existing author
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Adicionar autor existente',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      // ignore: deprecated_member_use
                      value: null,
                      items: availableAuthors
                          .where((a) => !selectedAuthors.contains(a))
                          .map((a) => DropdownMenuItem(
                              value: a,
                              child: Text(a, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => selectedAuthors.add(v));
                      },
                    ),
                    const SizedBox(height: 6),
                    // Add new author
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: newAuthorCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Novo autor',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add_circle),
                        tooltip: 'Adicionar',
                        onPressed: () {
                          final name = newAuthorCtrl.text.trim();
                          if (name.isNotEmpty && !selectedAuthors.contains(name)) {
                            setDialogState(() {
                              selectedAuthors.add(name);
                              newAuthorCtrl.clear();
                            });
                          }
                        },
                      ),
                    ]),
                    const SizedBox(height: 12),

                    // Genre
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Género',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      // ignore: deprecated_member_use
                      value: availableGenres.contains(selectedGenre)
                          ? selectedGenre
                          : null,
                      items: availableGenres
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) => setDialogState(() => selectedGenre = v),
                    ),
                    const SizedBox(height: 12),

                    // Tags
                    TextField(
                      controller: tagsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tags (separadas por vírgula)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),

                    // Publisher
                    TextField(
                      controller: publisherCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Editora',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Year
                    TextField(
                      controller: yearCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ano de publicação',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),

                    // Cover URL
                    TextField(
                      controller: coverCtrl,
                      decoration: const InputDecoration(
                        labelText: 'URL da capa',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    // Capture values BEFORE disposing controllers
    final title = titleCtrl.text.trim();
    final publisher = publisherCtrl.text.trim();
    final year = yearCtrl.text.trim();
    final cover = coverCtrl.text.trim();
    final tags = tagsCtrl.text.trim();

    titleCtrl.dispose();
    publisherCtrl.dispose();
    yearCtrl.dispose();
    coverCtrl.dispose();
    tagsCtrl.dispose();
    newAuthorCtrl.dispose();

    if (saved != true || !mounted) return;

    try {
      final payload = <String, dynamic>{
        'title': title,
        'authors': selectedAuthors,
        'genre': selectedGenre ?? '',
        'tags': tags,
        'publisher': publisher,
        'coverImageUrl': cover,
      };
      final yearParsed = int.tryParse(year);
      if (yearParsed != null) payload['publicationYear'] = yearParsed;

      await _apiClient.put(
        '/admin/books/${Uri.encodeComponent(book['isbn'] as String? ?? '')}',
        body: payload,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Livro atualizado'), backgroundColor: Colors.green),
      );
      _loadBooks();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteBook(Map<String, dynamic> book) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar livro'),
        content: Text(
          'Tem a certeza que quer eliminar "${book['title']}"?\n\nIsso também removerá todas as listagens de utilizadores associadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _apiClient.delete(
        '/admin/books/${Uri.encodeComponent(book['isbn'] as String? ?? '')}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Livro eliminado'),
          backgroundColor: Colors.green,
        ),
      );
      _loadBooks();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showBookDetails(Map<String, dynamic> book) {
    final coverUrl = book['coverImageUrl'] as String? ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (coverUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      coverUrl,
                      width: 72,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _bookPlaceholder(),
                    ),
                  )
                else
                  _bookPlaceholder(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book['title'] ?? 'Sem título',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book['authors'] ?? '',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      if ((book['genre'] as String? ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            book['genre'],
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _DetailRow(Icons.qr_code, 'ISBN', book['isbn']),
            if ((book['publisher'] as String? ?? '').isNotEmpty)
              _DetailRow(Icons.business, 'Editora', book['publisher']),
            if (book['publicationYear'] != null)
              _DetailRow(Icons.calendar_today, 'Ano', book['publicationYear']),
            if ((book['tags'] as String? ?? '').isNotEmpty)
              _DetailRow(Icons.label, 'Tags', book['tags']),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Editar Livro'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _editBook(book);
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text(
                  'Eliminar Livro',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _deleteBook(book);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookPlaceholder() => Container(
    width: 72,
    height: 100,
    decoration: BoxDecoration(
      color: Colors.grey[200],
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Icon(Icons.book, size: 32, color: Colors.grey),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerir Livros'),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadBooks),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar por título, autor, ISBN...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
          if (!_isLoading && _error == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${_filtered.length} livro${_filtered.length != 1 ? 's' : ''}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 12),
                        Text(_error!),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadBooks,
                          child: const Text('Tentar Novamente'),
                        ),
                      ],
                    ),
                  )
                : _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.library_books_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchController.text.isEmpty
                              ? 'Sem livros'
                              : 'Sem resultados',
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadBooks,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 72, endIndent: 16),
                      itemBuilder: (context, index) {
                        final book = _filtered[index];
                        final coverUrl = book['coverImageUrl'] as String? ?? '';
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: coverUrl.isNotEmpty
                                ? Image.network(
                                    coverUrl,
                                    width: 40,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      width: 40,
                                      height: 56,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.book, size: 20),
                                    ),
                                  )
                                : Container(
                                    width: 40,
                                    height: 56,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.book, size: 20),
                                  ),
                          ),
                          title: Text(
                            book['title'] ?? 'Sem título',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book['authors'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                              if ((book['genre'] as String? ?? '').isNotEmpty)
                                Text(
                                  book['genre'],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue[600],
                                  ),
                                ),
                            ],
                          ),
                          isThreeLine:
                              (book['genre'] as String? ?? '').isNotEmpty,
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                          ),
                          onTap: () => _showBookDetails(book),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final dynamic value;
  const _DetailRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
          Expanded(
            child: Text(
              '${value ?? '-'}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
