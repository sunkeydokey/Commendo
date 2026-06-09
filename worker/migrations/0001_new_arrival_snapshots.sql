CREATE TABLE IF NOT EXISTS new_arrival_snapshots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  list_type TEXT NOT NULL CHECK (list_type IN ('all', 'special')),
  snapshot_date TEXT NOT NULL,
  fetched_at TEXT NOT NULL,
  item_count INTEGER NOT NULL CHECK (item_count >= 0),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'complete'))
);

CREATE INDEX IF NOT EXISTS idx_new_arrival_snapshots_latest
  ON new_arrival_snapshots (list_type, status, fetched_at DESC, id DESC);

CREATE TABLE IF NOT EXISTS new_arrival_books (
  snapshot_id INTEGER NOT NULL REFERENCES new_arrival_snapshots(id) ON DELETE CASCADE,
  rank INTEGER NOT NULL CHECK (rank >= 1),
  title TEXT NOT NULL,
  author TEXT NOT NULL,
  publisher TEXT NOT NULL,
  published_date TEXT NOT NULL,
  isbn TEXT NOT NULL,
  isbn13 TEXT NOT NULL,
  cover_url TEXT NOT NULL,
  category_name TEXT NOT NULL,
  description TEXT NOT NULL,
  price_standard INTEGER NOT NULL DEFAULT 0,
  price_sales INTEGER NOT NULL DEFAULT 0,
  link TEXT NOT NULL,
  PRIMARY KEY (snapshot_id, rank)
);

CREATE INDEX IF NOT EXISTS idx_new_arrival_books_snapshot_rank
  ON new_arrival_books (snapshot_id, rank);
