#!/usr/bin/env python3
import os
import sys
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'saas_system.settings')
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
django.setup()

from django.db import connection

def fix_shop_column():
    with connection.cursor() as cursor:
        # Check if column exists and its nullability
        cursor.execute("""
            SELECT column_name, is_nullable
            FROM information_schema.columns
            WHERE table_name = 'expenses_expense' AND column_name = 'shop_id'
        """)
        result = cursor.fetchone()
        if result:
            column_name, is_nullable = result
            if is_nullable == 'NO':
                print("🔧 Altering column 'shop_id' in expenses_expense to allow NULL...")
                cursor.execute("ALTER TABLE expenses_expense ALTER COLUMN shop_id DROP NOT NULL;")
                print("✅ shop_id is now nullable.")
            else:
                print("ℹ️ shop_id is already nullable.")
        else:
            print("ℹ️ Column 'shop_id' does not exist in expenses_expense. No action needed.")

if __name__ == "__main__":
    print("🔍 Checking expenses_expense.shop_id...")
    fix_shop_column()
    print("✅ Done. Now you can add daily expenses without errors.")
