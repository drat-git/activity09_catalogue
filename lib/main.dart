import 'package:flutter/material.dart';

import 'database_helper.dart';
import 'catalogue.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final helper = DatabaseHelper();
  try {
    await helper.init();
  } catch (error, stack) {
    debugPrint('Database initialization failed: $error\n$stack');
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Could not open local storage. Restart the app.'),
          ),
        ),
      ),
    );
    return;
  }
  assert(() {
    helper.inspectSchema().then(
      (details) => debugPrint('Schema diagnostics: $details'),
    );
    return true;
  }());
  runApp(DirectoryApp(helper: helper));
}

class DirectoryApp extends StatelessWidget {
  const DirectoryApp({super.key, required this.helper});
  final DatabaseHelper helper;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Builder(
      builder: (context) => FoldersPage(
        helper: helper,
        openGuests: () => Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => GuestRoster(helper: helper)),
        ),
      ),
    ),
  );
}

class GuestRoster extends StatefulWidget {
  const GuestRoster({super.key, required this.helper});
  final DatabaseHelper helper;

  @override
  State<GuestRoster> createState() => _GuestRosterState();
}

class _GuestRosterState extends State<GuestRoster> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  int _count = 0;
  int? _selectedId;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    super.dispose();
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
      final rows = await widget.helper.queryAllRows();
      final count = await widget.helper.queryRowCount();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _count = count;
      });
    } catch (error, stack) {
      debugPrint('Guest read failed: $error\n$stack');
      if (mounted) {
        setState(() => _error = 'Could not load guests. Use Refresh to retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clear() {
    _selectedId = null;
    _name.clear();
    _age.clear();
    _formKey.currentState?.reset();
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final row = <String, dynamic>{
        DatabaseHelper.columnName: _name.text.trim(),
        DatabaseHelper.columnAge: int.parse(_age.text.trim()),
      };
      final id = _selectedId;
      final result = id == null
          ? await widget.helper.insert(row)
          : await widget.helper.update({...row, DatabaseHelper.columnId: id});
      if (!mounted) return;
      if (id != null && result == 0) {
        _message('Guest no longer exists. No row was changed.');
        await _load();
        return;
      }
      setState(_clear);
      _message(
        id == null
            ? 'Added guest ID $result.'
            : 'Updated guest ID $id: $result row.',
      );
      await _load();
      if (mounted && _error != null) {
        _message('Saved, but refresh failed. Use Refresh.');
      }
    } catch (error, stack) {
      debugPrint('Guest save failed: $error\n$stack');
      if (mounted) _message('Could not save guest. Your input is still here.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (_busy) return;
    final id = row[DatabaseHelper.columnId] as int;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete guest?'),
        content: Text('Delete ${row[DatabaseHelper.columnName]} (ID $id)?'),
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
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await widget.helper.delete(id);
      if (!mounted) return;
      if (_selectedId == id && result == 1) setState(_clear);
      _message(
        result == 1
            ? 'Deleted guest ID $id: 1 row.'
            : 'Guest no longer exists.',
      );
      await _load();
      if (mounted && _error != null) {
        _message('Deleted, but refresh failed. Use Refresh.');
      }
    } catch (error, stack) {
      debugPrint('Guest delete failed: $error\n$stack');
      if (mounted) _message('Could not delete guest. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Fall Festival Roster'),
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
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a guest name.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _age,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Age'),
                validator: (value) {
                  final age = int.tryParse(value?.trim() ?? '');
                  return age == null || age < 0 || age > 130
                      ? 'Enter a whole-number age from 0 to 130.'
                      : null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _busy ? null : _save,
                    child: Text(
                      _selectedId == null ? 'Add guest' : 'Save guest',
                    ),
                  ),
                  if (_selectedId != null)
                    TextButton(
                      onPressed: _busy ? null : () => setState(_clear),
                      child: const Text('Cancel edit'),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Text(_error!),
        if (_error == null && !_busy) Text('Guests: $_count'),
        if (_error == null && !_busy && _rows.isEmpty)
          const Text('No festival guests yet.'),
        for (final row in _rows)
          Card(
            child: ListTile(
              title: Text('${row[DatabaseHelper.columnName]}'),
              subtitle: Text(
                'ID ${row[DatabaseHelper.columnId]} · Age ${row[DatabaseHelper.columnAge]}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Edit guest',
                    icon: const Icon(Icons.edit),
                    onPressed: _busy
                        ? null
                        : () {
                            setState(() {
                              _selectedId = row[DatabaseHelper.columnId] as int;
                              _name.text =
                                  row[DatabaseHelper.columnName] as String;
                              _age.text = '${row[DatabaseHelper.columnAge]}';
                            });
                          },
                  ),
                  IconButton(
                    tooltip: 'Delete guest',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _busy ? null : () => _delete(row),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
