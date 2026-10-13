import 'package:path/path.dart';
import 'models.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static const _databaseName = "MyDatabase.db";
  static const _databaseVersion = 2;
  static const table = 'my_table';
  static const columnId = '_id';
  static const columnName = 'name';
  static const columnAge = 'age';
  late Database _db;
// this opens the database (and creates it if it doesn't exist)
  Future<void> init() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    _db = await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createCatalogueTables(db);
      },
    );
  }

// SQL code to create the database table
  Future _onCreate(Database db, int version) async {
    await db.execute('''
CREATE TABLE $table (
$columnId INTEGER PRIMARY KEY,
$columnName TEXT NOT NULL,
$columnAge INTEGER NOT NULL
)
''');
    await _createCatalogueTables(db);
  }

// Helper methods
// Inserts a row in the database where each key in the
//Map is a column name
// and the value is the column value. The return value
//is the id of the
// inserted row.
  Future<int> insert(Map<String, dynamic> row) async {
    return await _db.insert(table, row);
  }

// All of the rows are returned as a list of maps, where each map is
// a key-value list of columns.
  Future<List<Map<String, dynamic>>> queryAllRows() async {
    return await _db.query(table);
  }

// All of the methods (insert, query, update, delete) can also be done using
// raw SQL commands. This method uses a raw query to give the row count.
  Future<int> queryRowCount() async {
    final results = await _db.rawQuery('SELECT COUNT(*) FROM $table');
    return Sqflite.firstIntValue(results) ?? 0;
  }

// We are assuming here that the id column in the map is set. The other
// column values will be used to update the row.
  Future<int> update(Map<String, dynamic> row) async {
    int id = row[columnId];
    return await _db.update(
      table,
      row,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

// Deletes the row specified by the id. The number of affected rows is
// returned. This should be 1 as long as the row exists.
  Future<int> delete(int id) async {
    return await _db.delete(
      table,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }
  // The upgrade adds tables without changing the original guest rows.
  Future<void> _createCatalogueTables(Database db) async {
    await db.execute('CREATE TABLE folders ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'name TEXT NOT NULL UNIQUE, created_at TEXT NOT NULL)');
    await db.execute("CREATE TABLE cards ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, "
        "suit TEXT NOT NULL, notes TEXT NOT NULL DEFAULT '', image_ref TEXT, "
        "folder_id INTEGER NOT NULL, "
        "FOREIGN KEY (folder_id) REFERENCES folders(id) ON DELETE CASCADE)");
    await db.execute('CREATE INDEX idx_cards_folder_id ON cards(folder_id)');
  }

  Future<int> insertFolder(Folder folder) => _db.insert('folders', folder.toMap());

  Future<List<Folder>> getFoldersWithCounts() async {
    final rows = await _db.rawQuery(
      'SELECT f.*, COUNT(c.id) AS card_count FROM folders f '
      'LEFT JOIN cards c ON c.folder_id = f.id '
      'GROUP BY f.id ORDER BY f.name COLLATE NOCASE, f.id',
    );
    return rows.map(Folder.fromMap).toList();
  }

  Future<List<CardRecord>> getCards(int folderId) async {
    final rows = await _db.query('cards', where: 'folder_id = ?',
      whereArgs: [folderId], orderBy: 'title COLLATE NOCASE, id');
    return rows.map(CardRecord.fromMap).toList();
  }

  Future<int> insertCard(CardRecord card) => _db.insert('cards', card.toMap());

  Future<int> updateCard(CardRecord card) => _db.update('cards', card.toMap(),
    where: 'id = ?', whereArgs: [card.id]);

  Future<int> deleteCard(int id) => _db.delete('cards', where: 'id = ?', whereArgs: [id]);

  Future<int> deleteFolder(int id) => _db.delete('folders', where: 'id = ?', whereArgs: [id]);

  Future<Map<String, Object?>> inspectSchema() async => {
    'version': await _db.rawQuery('PRAGMA user_version'),
    'foreign_keys': await _db.rawQuery('PRAGMA foreign_keys'),
    'card_foreign_key': await _db.rawQuery('PRAGMA foreign_key_list(cards)'),
    'card_indexes': await _db.rawQuery('PRAGMA index_list(cards)'),
    'guests': await queryAllRows(),
  };
}
