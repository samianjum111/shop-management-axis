#!/usr/bin/env python3
import os
import sys
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'saas_system.settings')
django.setup()

from tenants.models import Tenant
from chakki.models import ChakkiCustomer, ChakkiOrder, ChakkiSetting, ChakkiCategory, ChakkiOrderItem
from expenses.models import Expense, Reminder, Worker, WorkerCategory, WorkerAttendance, WorkerPayment

tenant = Tenant.objects.first()
if not tenant:
    print("❌ No tenant found. Please create one via admin.")
    sys.exit(1)

models = [
    ChakkiCustomer, ChakkiOrder, ChakkiSetting, ChakkiCategory, ChakkiOrderItem,
    Expense, Reminder, Worker, WorkerCategory, WorkerAttendance, WorkerPayment
]
for model in models:
    updated = model.objects.all().update(tenant=tenant)
    print(f"{model.__name__}: {updated} rows updated.")
print(f"✅ All records assigned to tenant '{tenant.schema_name}'")
