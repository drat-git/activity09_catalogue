import 'package:flutter/material.dart';

import 'database_helper.dart';
import 'models.dart';

class FoldersPage extends StatefulWidget {
  const FoldersPage({
    super.key,
    required this.helper,
    required this.openGuests,
  });
  final DatabaseHelper helper;
  final VoidCallback openGuests;

  @override
  State<FoldersPage> createState() => _FoldersPageState();
}

class _FoldersPageState extends State<FoldersPage> {
  List<Folder> _folders = [];
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final folders = await widget.helper.getFoldersWithCounts();
      if (mounted) setState(() => _folders = folders);
    } catch (error, stack) {
      debugPrint('Folder read failed: $error\n$stack');
      if (mounted)
        setState(
          () => _error = 'Could not load folders. Use Refresh to retry.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => FolderForm(helper: widget.helper)),
    );
    if (!mounted) return;
    await _load();
    if (!mounted || result == null) return;
    _message(_error == null ? result : '$result Refresh failed; use Refresh.');
  }

  Future<void> _open(Folder folder) async {
    if (_busy) return;
    setState(() => _busy = true);
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CardsPage(helper: widget.helper, folder: folder),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _delete(Folder folder) async {
    if (_busy) return;
    setState(() => _busy = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text(
          'Delete ${folder.name} (ID ${folder.id}) and its ${folder.cardCount} cards? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) {
      setState(() => _busy = false);
      return;
    }
    try {
      final changed = await widget.helper.deleteFolder(folder.id!);
      if (!mounted) return;
      final message = changed == 1
          ? 'Deleted ${folder.name}: 1 folder row.'
          : 'Folder no longer exists; no row was deleted.';
      await _load();
      if (mounted)
        _message(
          _error == null ? message : '$message Refresh failed; use Refresh.',
        );
    } catch (error, stack) {
      debugPrint('Folder delete failed: $error\n$stack');
      if (mounted) _message('Could not delete folder. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Card Catalogue'),
      actions: [
        IconButton(
          tooltip: 'Part I guests',
          onPressed: _busy ? null : widget.openGuests,
          icon: const Icon(Icons.people_outline),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Folders',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('Open a folder to view its cards.'),
        const SizedBox(height: 16),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Text(_error!),
        if (!_busy && _error == null && _folders.isEmpty)
          const Text('No folders yet. Add your first folder.'),
        if (_error == null)
          for (final folder in _folders)
            Card(
              child: ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(folder.name),
                subtitle: Text('ID ${folder.id} · ${folder.cardCount} cards'),
                onTap: _busy ? null : () => _open(folder),
                trailing: IconButton(
                  tooltip: 'Delete ${folder.name}',
                  onPressed: _busy ? null : () => _delete(folder),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _busy || _error != null ? null : _add,
      icon: const Icon(Icons.add),
      label: const Text('Add folder'),
    ),
  );
}

class FolderForm extends StatefulWidget {
  const FolderForm({super.key, required this.helper});
  final DatabaseHelper helper;

  @override
  State<FolderForm> createState() => _FolderFormState();
}

class _FolderFormState extends State<FolderForm> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_key.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await widget.helper.insertFolder(
        Folder(
          name: _name.text.trim(),
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      if (mounted) Navigator.pop(context, 'Added folder ID $id.');
    } catch (error, stack) {
      debugPrint('Folder save failed: $error\n$stack');
      if (mounted)
        setState(
          () => _error = 'Could not save folder. That name may already exist. Choose a different name or try again.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('New folder')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _key,
            child: TextFormField(
              controller: _name,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Folder name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a folder name.'
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null) Text(_error!),
          if (_busy) const LinearProgressIndicator(),
          Row(
            children: [
              ElevatedButton(
                onPressed: _busy ? null : _save,
                child: const Text('Save folder'),
              ),
              TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class CardsPage extends StatefulWidget {
  const CardsPage({super.key, required this.helper, required this.folder});
  final DatabaseHelper helper;
  final Folder folder;

  @override
  State<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends State<CardsPage> {
  List<CardRecord> _cards = [];
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cards = await widget.helper.getCards(widget.folder.id!);
      if (mounted) setState(() => _cards = cards);
    } catch (error, stack) {
      debugPrint('Card read failed: $error\n$stack');
      if (mounted)
        setState(() => _error = 'Could not load cards. Use Refresh to retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _form([CardRecord? card]) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => CardForm(
          helper: widget.helper,
          folderId: widget.folder.id!,
          card: card,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
    if (!mounted || result == null) return;
    _message(_error == null ? result : '$result Refresh failed; use Refresh.');
  }

  Future<void> _delete(CardRecord card) async {
    if (_busy) return;
    setState(() => _busy = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete card?'),
        content: Text('Delete ${card.title} (ID ${card.id})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) {
      setState(() => _busy = false);
      return;
    }
    try {
      final changed = await widget.helper.deleteCard(card.id!);
      if (!mounted) return;
      final message = changed == 1
          ? 'Deleted card ID ${card.id}: 1 row.'
          : 'Card no longer exists; no row was deleted.';
      await _load();
      if (mounted)
        _message(
          _error == null ? message : '$message Refresh failed; use Refresh.',
        );
    } catch (error, stack) {
      debugPrint('Card delete failed: $error\n$stack');
      if (mounted) _message('Could not delete card. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.folder.name),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Folder ID ${widget.folder.id}'),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Text(_error!),
        if (!_busy && _error == null) Text('Cards: ${_cards.length}'),
        if (!_busy && _error == null && _cards.isEmpty)
          const Text('No cards in this folder. Add your first card.'),
        if (_error == null)
          for (final card in _cards)
            Card(
              child: ListTile(
                leading: CardArtwork(card: card),
                title: Text(card.title),
                subtitle: Text(
                  'ID ${card.id} · ${card.suit}${card.notes.isEmpty ? '' : '\n${card.notes}'}',
                ),
                onTap: _busy ? null : () => _form(card),
                trailing: IconButton(
                  tooltip: 'Delete card ${card.id}',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _busy ? null : () => _delete(card),
                ),
              ),
            ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _busy || _error != null ? null : () => _form(),
      icon: const Icon(Icons.add),
      label: const Text('Add card'),
    ),
  );
}

class CardForm extends StatefulWidget {
  const CardForm({
    super.key,
    required this.helper,
    required this.folderId,
    this.card,
  });
  final DatabaseHelper helper;
  final int folderId;
  final CardRecord? card;

  @override
  State<CardForm> createState() => _CardFormState();
}

class _CardFormState extends State<CardForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late final TextEditingController _image;
  late int _folderId;
  late String _suit;
  List<Folder> _folders = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.card?.title ?? '');
    _notes = TextEditingController(text: widget.card?.notes ?? '');
    _image = TextEditingController(text: widget.card?.imageRef ?? '');
    _folderId = widget.card?.folderId ?? widget.folderId;
    _suit = widget.card?.suit ?? CardRecord.suits.first;
    _loadFolders();
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _image.dispose();
    super.dispose();
  }

  Future<void> _loadFolders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final folders = await widget.helper.getFoldersWithCounts();
      if (mounted) setState(() => _folders = folders);
    } catch (error, stack) {
      debugPrint('Form folders failed: $error\n$stack');
      if (mounted)
        setState(() => _error = 'Could not load folders. Tap Retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_busy || _loading || !_key.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final image = _image.text.trim();
    final card = CardRecord(
      id: widget.card?.id,
      title: _title.text.trim(),
      suit: _suit,
      folderId: _folderId,
      notes: _notes.text.trim(),
      imageRef: image.isEmpty ? null : image,
    );
    try {
      final changed = card.id == null
          ? await widget.helper.insertCard(card)
          : await widget.helper.updateCard(card);
      if (!mounted) return;
      if (card.id != null && changed == 0) {
        setState(() => _error = 'Card no longer exists. No row was changed.');
        return;
      }
      // Return only after the write; the list refresh cannot repeat this save.
      Navigator.pop(
        context,
        card.id == null
            ? 'Added card ID $changed.'
            : 'Updated card ID ${card.id}: $changed row.',
      );
    } catch (error, stack) {
      debugPrint('Card save failed: $error\n$stack');
      if (mounted)
        setState(
          () => _error = 'Could not save card. Check the folder and try again. Your input is still here.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.card == null ? 'Add card' : 'Edit card'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Text(_error!),
          if (!_loading && _folders.isEmpty)
            TextButton(onPressed: _loadFolders, child: const Text('Retry')),
          Form(
            key: _key,
            child: Column(
              children: [
                TextFormField(
                  controller: _title,
                  enabled: !_busy && !_loading,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a card title.'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: CardRecord.suits.contains(_suit) ? _suit : null,
                  decoration: const InputDecoration(labelText: 'Suit'),
                  items: [
                    for (final suit in CardRecord.suits)
                      DropdownMenuItem(value: suit, child: Text(suit)),
                  ],
                  onChanged: _busy || _loading
                      ? null
                      : (value) => setState(() => _suit = value!),
                  validator: (value) => CardRecord.suits.contains(value)
                      ? null
                      : 'Choose a supported suit.',
                ),
                const SizedBox(height: 16),
                if (!_loading)
                  DropdownButtonFormField<int>(
                    initialValue: _folders.any((f) => f.id == _folderId)
                        ? _folderId
                        : null,
                    decoration: const InputDecoration(labelText: 'Folder'),
                    items: [
                      for (final folder in _folders)
                        DropdownMenuItem(
                          value: folder.id,
                          child: Text(folder.name),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _folderId = value!),
                    validator: (value) => _folders.any((f) => f.id == value)
                        ? null
                        : 'Choose an existing folder.',
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notes,
                  enabled: !_busy && !_loading,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _image,
                  enabled: !_busy && !_loading,
                  decoration: const InputDecoration(
                    labelText: 'Image reference (optional)',
                    helperText:
                        'Bundled asset path, or leave blank for a suit symbol.',
                  ),
                ),
                const SizedBox(height: 24),
                if (_busy) const LinearProgressIndicator(),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _busy || _loading || _folders.isEmpty
                          ? null
                          : _save,
                      child: const Text('Save card'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class CardArtwork extends StatelessWidget {
  const CardArtwork({super.key, required this.card});
  final CardRecord card;

  @override
  Widget build(BuildContext context) {
    const symbols = {
      'Hearts': '♥',
      'Diamonds': '♦',
      'Clubs': '♣',
      'Spades': '♠',
    };
    final placeholder = Semantics(
      label: '${card.suit} placeholder',
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Text(
            symbols[card.suit] ?? '?',
            style: const TextStyle(fontSize: 30),
          ),
        ),
      ),
    );
    final reference = card.imageRef;
    if (reference == null || !reference.startsWith('assets/'))
      return placeholder;
    return Image.asset(
      reference,
      width: 40,
      height: 40,
      fit: BoxFit.contain,
      errorBuilder: (_, error, stack) => placeholder,
    );
  }
}
