#!/usr/bin/env python3
"""
LudoMaster Database Backup, Restore, and Integrity Verification Tool
Phase 12: Hardening & Operational Readiness

Supports:
- Point-in-time snapshot backup with SHA-256 checksum generation
- Safe restore with pre-restore safety copy and checksum verification
- Deep database integrity check (PRAGMA integrity_check, foreign keys, table row stats)
- Automated Disaster Recovery Drill (creates live copy, simulates restore, verifies parity)
"""

import argparse
import hashlib
import json
import os
import shutil
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_DB_PATH = Path(__file__).resolve().parent.parent / "ludomaster.db"
DEFAULT_BACKUP_DIR = Path(__file__).resolve().parent.parent / "backups"

def compute_checksum(filepath: Path) -> str:
    """Computes SHA-256 hash of a file."""
    hasher = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            hasher.update(chunk)
    return hasher.hexdigest()

def backup_database(db_path: Path, backup_dir: Path, note: str = "") -> Path:
    """Creates a consistent backup copy of the database and records metadata."""
    if not db_path.exists():
        raise FileNotFoundError(f"Database not found at {db_path}")

    backup_dir.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    backup_filename = f"ludomaster_backup_{timestamp}.db"
    backup_path = backup_dir / backup_filename

    print(f"[*] Initiating backup from: {db_path}")
    print(f"[*] Target backup destination: {backup_path}")

    # Use SQLite online backup API to ensure transaction consistency
    src_conn = sqlite3.connect(str(db_path))
    dst_conn = sqlite3.connect(str(backup_path))
    try:
        with dst_conn:
            src_conn.backup(dst_conn, pages=100)
    finally:
        dst_conn.close()
        src_conn.close()

    checksum = compute_checksum(backup_path)
    file_size_bytes = backup_path.stat().st_size

    # Verify backup integrity
    verify_sqlite_integrity(backup_path)

    # Save metadata descriptor
    meta_path = backup_path.with_suffix(".json")
    metadata = {
        "backup_file": backup_filename,
        "source_db": str(db_path),
        "created_at": datetime.now(timezone.utc).isoformat(),
        "sha256": checksum,
        "size_bytes": file_size_bytes,
        "note": note,
    }
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(metadata, f, indent=2)

    print(f"[OK] Backup completed successfully!")
    print(f"    - File: {backup_path.name} ({file_size_bytes} bytes)")
    print(f"    - SHA-256: {checksum}")
    print(f"    - Metadata: {meta_path.name}")
    return backup_path

def verify_sqlite_integrity(db_path: Path) -> dict:
    """Performs deep PRAGMA integrity checks and collects table row statistics."""
    if not db_path.exists():
        raise FileNotFoundError(f"Database file not found: {db_path}")

    conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    cursor = conn.cursor()
    try:
        # 1. Integrity check
        cursor.execute("PRAGMA integrity_check;")
        integrity_rows = cursor.fetchall()
        integrity_ok = len(integrity_rows) == 1 and integrity_rows[0][0] == "ok"
        if not integrity_ok:
            raise RuntimeError(f"Integrity check failed: {integrity_rows}")

        # 2. Foreign key check
        cursor.execute("PRAGMA foreign_key_check;")
        fk_violations = cursor.fetchall()
        if fk_violations:
            print(f"[!] Warning: Foreign key violations detected: {len(fk_violations)}")

        # 3. Table row counts
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
        tables = [row[0] for row in cursor.fetchall()]

        stats = {}
        for tbl in tables:
            try:
                cursor.execute(f"SELECT COUNT(*) FROM \"{tbl}\";")
                stats[tbl] = cursor.fetchone()[0]
            except Exception as e:
                stats[tbl] = f"Error: {e}"

        result = {
            "status": "HEALTHY",
            "integrity_check": "ok",
            "foreign_key_violations": len(fk_violations),
            "tables_found": len(tables),
            "row_counts": stats,
        }
        return result
    finally:
        conn.close()

def restore_database(backup_path: Path, target_db_path: Path, force: bool = False) -> None:
    """Restores database from backup file, ensuring safety snapshot and validation."""
    if not backup_path.exists():
        raise FileNotFoundError(f"Backup file not found at {backup_path}")

    print(f"[*] Starting restore drill...")
    print(f"    - Source backup: {backup_path}")
    print(f"    - Target DB: {target_db_path}")

    # Check checksum if metadata JSON exists
    meta_path = backup_path.with_suffix(".json")
    if meta_path.exists():
        with open(meta_path, "r", encoding="utf-8") as f:
            meta = json.load(f)
        expected_sha = meta.get("sha256")
        if expected_sha:
            actual_sha = compute_checksum(backup_path)
            if actual_sha != expected_sha:
                raise ValueError(
                    f"Checksum mismatch! Expected {expected_sha}, got {actual_sha}. Corrupted backup file!"
                )
            print("    - Checksum verified: SHA-256 match!")

    # Verify backup integrity before replacing active DB
    verify_sqlite_integrity(backup_path)

    # Pre-restore safety copy if target DB exists
    if target_db_path.exists():
        safety_copy = target_db_path.with_suffix(f".pre_restore_{datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')}.bak")
        shutil.copy2(target_db_path, safety_copy)
        print(f"    - Pre-restore safety snapshot saved to: {safety_copy.name}")

    # Restore via SQLite backup
    src_conn = sqlite3.connect(str(backup_path))
    dst_conn = sqlite3.connect(str(target_db_path))
    try:
        with dst_conn:
            src_conn.backup(dst_conn, pages=100)
    finally:
        dst_conn.close()
        src_conn.close()

    # Final post-restore verification
    res = verify_sqlite_integrity(target_db_path)
    print(f"[OK] Restore completed and verified! Target DB status: {res['status']}")

def run_drill(db_path: Path, tmp_dir: Path) -> bool:
    """Executes an end-to-end Disaster Recovery drill without affecting production files."""
    print("=" * 60)
    print("      LUDOMASTER DISASTER RECOVERY & BACKUP DRILL      ")
    print("=" * 60)

    tmp_dir.mkdir(parents=True, exist_ok=True)
    drill_db = tmp_dir / "drill_source.db"
    drill_backups = tmp_dir / "drill_backups"
    drill_restore_target = tmp_dir / "drill_restored.db"

    try:
        if db_path.exists():
            shutil.copy2(db_path, drill_db)
        else:
            # Create a mock schema if DB doesn't exist yet
            conn = sqlite3.connect(str(drill_db))
            conn.execute("CREATE TABLE users (id TEXT PRIMARY KEY, status TEXT);")
            conn.execute("INSERT INTO users VALUES ('usr_1', 'ACTIVE');")
            conn.commit()
            conn.close()

        # Step 1: Backup
        print("\n[Step 1/3] Creating verified backup snapshot...")
        backup_file = backup_database(drill_db, drill_backups, note="Disaster Recovery Automated Drill")

        # Step 2: Restore into separate target
        print("\n[Step 2/3] Simulating bare-metal restore into new environment...")
        restore_database(backup_file, drill_restore_target)

        # Step 3: Compare data parity
        print("\n[Step 3/3] Validating source and restored data parity...")
        src_info = verify_sqlite_integrity(drill_db)
        dst_info = verify_sqlite_integrity(drill_restore_target)

        assert src_info["row_counts"] == dst_info["row_counts"], "Data row counts differ after restore!"
        print(f"    - Table row parity: 100% MATCH across {len(src_info['row_counts'])} tables.")
        print("\n[PASS] DISASTER RECOVERY DRILL PASSED SUCCESSFULLY! [PASS]\n")
        return True
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)

def main():
    parser = argparse.ArgumentParser(description="LudoMaster Database Backup & Disaster Recovery CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # backup
    p_backup = subparsers.add_parser("backup", help="Create a timestamped database backup")
    p_backup.add_argument("--db", type=Path, default=DEFAULT_DB_PATH, help="Path to database")
    p_backup.add_argument("--out", type=Path, default=DEFAULT_BACKUP_DIR, help="Output directory")
    p_backup.add_argument("--note", type=str, default="", help="Optional note")

    # restore
    p_restore = subparsers.add_parser("restore", help="Restore database from a backup")
    p_restore.add_argument("backup_file", type=Path, help="Backup file to restore from")
    p_restore.add_argument("--db", type=Path, default=DEFAULT_DB_PATH, help="Destination database file")
    p_restore.add_argument("--force", action="store_true", help="Force restore without confirmation")

    # verify
    p_verify = subparsers.add_parser("verify", help="Check database integrity and stats")
    p_verify.add_argument("--db", type=Path, default=DEFAULT_DB_PATH, help="Path to database")

    # drill
    p_drill = subparsers.add_parser("drill", help="Execute an isolated disaster recovery drill")
    p_drill.add_argument("--db", type=Path, default=DEFAULT_DB_PATH, help="Path to database")

    args = parser.parse_args()

    if args.command == "backup":
        backup_database(args.db, args.out, note=args.note)
    elif args.command == "restore":
        restore_database(args.backup_file, args.db, force=args.force)
    elif args.command == "verify":
        res = verify_sqlite_integrity(args.db)
        print(json.dumps(res, indent=2))
    elif args.command == "drill":
        tmp_drill_dir = Path(__file__).resolve().parent.parent / ".drill_tmp"
        success = run_drill(args.db, tmp_drill_dir)
        sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
