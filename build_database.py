"""Build the SQLite database from the raw ACT emergency department CSV.

Run:  python build_database.py
Creates data/act_ed.db
"""
import csv
import sqlite3
from pathlib import Path

ROOT = Path(__file__).parent
RAW_CSV = ROOT / "data" / "raw" / "act_ed_performance.csv"
DB_PATH = ROOT / "data" / "act_ed.db"
SQL_DIR = ROOT / "sql"


def main():
    DB_PATH.unlink(missing_ok=True)
    con = sqlite3.connect(DB_PATH)

    # 1. Create empty tables
    con.executescript((SQL_DIR / "01_schema.sql").read_text())

    # 2. Copy the CSV into the staging table, unchanged
    with open(RAW_CSV, newline="", encoding="utf-8-sig") as f:
        reader = csv.reader(f)
        next(reader)  # skip the header row
        con.executemany(
            "INSERT INTO raw_ed_performance VALUES (?, ?, ?, ?, ?, ?, ?, ?)", reader
        )

    # 3. Clean the staging data into the final tables (all in SQL)
    con.executescript((SQL_DIR / "02_transform.sql").read_text())
    con.commit()

    for table in ["raw_ed_performance", "hospitals", "measures",
                  "triage_categories", "ed_performance"]:
        count = con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
        print(f"{table:<20} {count:>5} rows")
    con.close()
    print(f"\nDatabase written to {DB_PATH}")


if __name__ == "__main__":
    main()
