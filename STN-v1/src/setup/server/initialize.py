from aes_file_encryption import encrypt_file
import sqlite3
import bcrypt
import os

data = [
    {
        "username": "admin",
        "password": "ilovemario",
    },
    {
        "username": "john",
        "password": "depresso",
    },
    {
        "username": "jane",
        "password": "volcano1",
    },
    {
        "username": "firefly",
        "password": "scorchedearth",
    },
    {
        "username": "solitude",
        "password": "YBN24{this_is_not_the_flag}",
    }
]
key = os.urandom(16)

def xor(data, key):
    repeated_key = (key * (len(data) // len(key) + 1))[:len(data)]
    xored_result = ''.join(chr(ord(d) ^ k) for d, k in zip(data, repeated_key))
    return xored_result

def initialize():
    try:
        os.remove("instance/vault.db")
    except:
        pass
    conn = sqlite3.connect('instance/vault.db')
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS vaults
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                 username TEXT NOT NULL,
                 password TEXT NOT NULL,
                 data BLOB)''')
    conn.commit()

    for user in data:
        c.execute('SELECT * FROM vaults WHERE username=?', (user['username'],))
        if c.fetchone() is None:
            c.execute('INSERT INTO vaults (username, password) VALUES (?, ?)', (user['username'], xor(user["password"], key)))
            conn.commit()

    conn.close()
    with open("instance/xor.key", "wb") as f:
        f.write(key)
    
    encrypt_file("instance/vault.db", "instance/key.key")
    with open("instance/key.key", "rb") as f:
        keydata = f.read()
    with open("instance/vault.db.aes", "ab") as x:
        x.write(keydata)
    os.rename("instance/vault.db.aes", "instance/vault.db")

if __name__ == "__main__":
    initialize()