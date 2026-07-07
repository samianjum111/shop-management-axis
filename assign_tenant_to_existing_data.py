#!/usr/bin/env python3
import os
import sys
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'saas_system.settings')
django.setup()

from tenants.models import Tenant
from chakki.models import ChakkiCustomer, ChakkiOrder, ChakkiSetting, ChakkiCategory
from expenses.models import Expense, Reminder, Worker, WorkerCategory, WorkerAttendance, WorkerPayment

tenant_schema = '2'
try:
    tenant = Tenant.objects.get(schema_name=tenant_schema)
except Tenant.DoesNotExist:
    tenant = Tenant.objects.first()
if not tenant:
    print("No tenant found.")
    sys.exit(1)

models = [ChakkiCustomer, ChakkiOrder, ChakkiSetting, ChakkiCategory,
          Expense, Reminder, Worker, WorkerCategory, WorkerAttendance, WorkerPayment]
for model in models:
    updated = model.objects.all().update(tenant=tenant)
    print(f"{model.__name__}: {updated} rows updated.")
print("✅ All existing records assigned to tenant", tenant.schema_name)
