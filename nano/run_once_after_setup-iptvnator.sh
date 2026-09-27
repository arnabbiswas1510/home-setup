#!/usr/bin/env bash
# Ensures IPTVnator has the Stalker Portal source configured.
# Portable across Linux and macOS. Uses standard python3 sqlite3.

command -v python3 >/dev/null 2>&1 || exit 0

python3 - << 'EOF'
import os
import sqlite3

DB_PATH = os.path.expanduser("~/.iptvnator/databases/iptvnator.db")

STALKER_ID = "1a6720df-ef7b-44b4-a9a9-22eebdf3fdb8"
STALKER_NAME = "b4u"
STALKER_MAC = "00:1A:79:35:36:33"
STALKER_URL = "http://portal.elite4k.co/stalker_portal/server/load.php"
STALKER_PAYLOAD = (
    '{"_id":"1a6720df-ef7b-44b4-a9a9-22eebdf3fdb8","title":"b4u",'
    '"macAddress":"00:1A:79:35:36:33",'
    '"portalUrl":"http://portal.elite4k.co/stalker_portal/server/load.php",'
    '"importDate":"2026-09-26T04:32:40.916Z","isFullStalkerPortal":true}'
)

if not os.path.exists(DB_PATH):
    exit(0)

try:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='playlists';")
    if not cur.fetchone():
        conn.close()
        exit(0)

    cur.execute("SELECT id FROM playlists WHERE id = ? OR macAddress = ?;", (STALKER_ID, STALKER_MAC))
    existing = cur.fetchone()

    if existing:
        cur.execute(
            """
            UPDATE playlists
            SET name = ?, portal_url = ?, url = ?, payload = ?
            WHERE id = ?;
            """,
            (STALKER_NAME, STALKER_URL, STALKER_URL, STALKER_PAYLOAD, existing[0])
        )
    else:
        cur.execute(
            """
            INSERT INTO playlists (
                id, name, type, macAddress, url, portal_url, count, import_date, payload
            ) VALUES (?, ?, 'stalker', ?, ?, ?, 0, datetime('now'), ?);
            """,
            (STALKER_ID, STALKER_NAME, STALKER_MAC, STALKER_URL, STALKER_URL, STALKER_PAYLOAD)
        )

    conn.commit()
    conn.close()
except Exception:
    pass
EOF
