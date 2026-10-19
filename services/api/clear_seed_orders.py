import sqlite3

conn = sqlite3.connect('D:/KalaSathi/services/api/kalasathi.db')
cur = conn.cursor()

# Clear seed orders (no real products existed so all orders are seed data)
cur.execute('DELETE FROM earnings')
cur.execute('DELETE FROM order_items')
cur.execute('DELETE FROM orders')
cur.execute('DELETE FROM reviews')
cur.execute('DELETE FROM inquiries')
cur.execute('DELETE FROM notifications')

for t in ['orders', 'order_items', 'earnings', 'reviews']:
    try:
        cur.execute('DELETE FROM sqlite_sequence WHERE name=?', (t,))
    except:
        pass

conn.commit()
print('Orders cleared:', cur.rowcount)

cur.execute('SELECT COUNT(*) FROM orders'); print('Orders remaining:', cur.fetchone()[0])
conn.close()
print('Done.')
