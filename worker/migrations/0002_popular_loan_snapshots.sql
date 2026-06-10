CREATE TABLE IF NOT EXISTS popular_loan_snapshots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  period_start TEXT NOT NULL,
  period_end TEXT NOT NULL,
  fetched_at TEXT NOT NULL,
  item_count INTEGER NOT NULL CHECK (item_count >= 0),
  content_hash TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'complete'))
);

CREATE INDEX IF NOT EXISTS idx_popular_loan_snapshots_latest
  ON popular_loan_snapshots (status, fetched_at DESC, id DESC);

CREATE TABLE IF NOT EXISTS popular_loan_books (
  snapshot_id INTEGER NOT NULL REFERENCES popular_loan_snapshots(id) ON DELETE CASCADE,
  rank INTEGER NOT NULL CHECK (rank >= 1),
  title TEXT NOT NULL,
  authors TEXT NOT NULL,
  publisher TEXT NOT NULL,
  publication_year TEXT NOT NULL,
  isbn13 TEXT NOT NULL,
  cover_url TEXT NOT NULL,
  detail_url TEXT NOT NULL,
  loan_count INTEGER NOT NULL CHECK (loan_count >= 0),
  PRIMARY KEY (snapshot_id, rank)
);

CREATE INDEX IF NOT EXISTS idx_popular_loan_books_snapshot_rank
  ON popular_loan_books (snapshot_id, rank);
