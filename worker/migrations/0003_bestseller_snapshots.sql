CREATE TABLE IF NOT EXISTS bestseller_snapshots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  period_start TEXT NOT NULL,
  period_end TEXT NOT NULL,
  fetched_at TEXT NOT NULL,
  item_count INTEGER NOT NULL CHECK (item_count >= 0),
  content_hash TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'complete'))
);

CREATE INDEX IF NOT EXISTS idx_bestseller_snapshots_latest
  ON bestseller_snapshots (status, fetched_at DESC, id DESC);

CREATE TABLE IF NOT EXISTS bestseller_books (
  snapshot_id INTEGER NOT NULL REFERENCES bestseller_snapshots(id) ON DELETE CASCADE,
  rank INTEGER NOT NULL CHECK (rank >= 1),
  title TEXT NOT NULL,
  authors TEXT NOT NULL,
  publisher TEXT NOT NULL,
  publication_year TEXT NOT NULL,
  isbn13 TEXT NOT NULL,
  cover_url TEXT NOT NULL,
  detail_url TEXT NOT NULL,
  PRIMARY KEY (snapshot_id, rank)
);

CREATE INDEX IF NOT EXISTS idx_bestseller_books_snapshot_rank
  ON bestseller_books (snapshot_id, rank);

INSERT OR IGNORE INTO bestseller_snapshots (
  id, period_start, period_end, fetched_at, item_count, content_hash, status
)
SELECT id, period_start, period_end, fetched_at, item_count, content_hash, status
  FROM popular_loan_snapshots;

INSERT OR IGNORE INTO bestseller_books (
  snapshot_id, rank, title, authors, publisher, publication_year, isbn13,
  cover_url, detail_url
)
SELECT snapshot_id, rank, title, authors, publisher, publication_year, isbn13,
       cover_url, detail_url
  FROM popular_loan_books;
