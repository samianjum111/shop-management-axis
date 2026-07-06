#!/usr/bin/env python3
import os
import sys
import django

# Django environment setup
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'saas_system.settings')
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
django.setup()

from django.db import connection

def add_column_if_not_exists(table, column, definition):
    with connection.cursor() as cursor:
        cursor.execute("""
            SELECT column_name
            FROM information_schema.columns
            WHERE table_name = %s AND column_name = %s
        """, [table, column])
        if not cursor.fetchone():
            print(f"➕ Adding column '{column}' to {table}...")
            cursor.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition}")
            print(f"✅ {column} added.")
            return True
        else:
            print(f"ℹ️ {column} already exists in {table}.")
            return False

def main():
    print("🔍 Checking local database for missing columns...\n")

    # ---------- ChakkiOrder ----------
    add_column_if_not_exists('chakki_chakkiorder', 'payment_status', "varchar(20) DEFAULT 'unpaid'")
    add_column_if_not_exists('chakki_chakkiorder', 'amount_paid', "decimal(10,2) DEFAULT 0")

    # ---------- Expense ----------
    add_column_if_not_exists('expenses_expense', 'expense_date', "date DEFAULT now()")
    add_column_if_not_exists('expenses_expense', 'is_repaid', "boolean DEFAULT false")
    add_column_if_not_exists('expenses_expense', 'phone', "varchar(20) DEFAULT ''")
    add_column_if_not_exists('expenses_expense', 'address', "text DEFAULT ''")
    add_column_if_not_exists('expenses_expense', 'notes', "text DEFAULT ''")
    add_column_if_not_exists('expenses_expense', 'reason', "varchar(200) DEFAULT ''")

    # ---------- (Optional) If future columns needed, add here ----------

    print("\n✅ All missing columns added (if any).")
    print("🚀 Now you can run `python manage.py runserver` and it should work.")

if __name__ == "__main__":
    main()
