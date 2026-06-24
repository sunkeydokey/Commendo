DELETE FROM bestseller_books
 WHERE detail_url NOT LIKE '%aladin.co.kr%';

DELETE FROM bestseller_snapshots
 WHERE NOT EXISTS (
   SELECT 1
     FROM bestseller_books
    WHERE bestseller_books.snapshot_id = bestseller_snapshots.id
 );
