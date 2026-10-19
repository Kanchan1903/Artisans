import sqlite3

conn = sqlite3.connect('D:/KalaSathi/services/api/kalasathi.db')
cur = conn.cursor()

# Delete all seed product-related data in dependency order
tables = ['wishlist_items', 'order_items', 'reviews', 'product_translations', 'product_images', 'products']
for t in tables:
    try:
        cur.execute(f'DELETE FROM {t}')
        print(f'Cleared {t}: {cur.rowcount} rows deleted')
    except Exception as e:
        print(f'Skip {t}: {e}')

# Reset auto-increment counters
for t in ['products', 'product_images', 'product_translations']:
    try:
        cur.execute('DELETE FROM sqlite_sequence WHERE name=?', (t,))
    except Exception:
        pass

conn.commit()
cur.execute('SELECT COUNT(*) FROM products')
print('Products remaining:', cur.fetchone()[0])
conn.close()
print('Cleanup complete.')
