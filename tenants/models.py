from django.db import models
from django_tenants.models import TenantMixin, DomainMixin

class Tenant(TenantMixin):
    name = models.CharField(max_length=100)
    schema_name = models.CharField(max_length=63, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    category = models.CharField(max_length=20, default='chakki')

    auto_create_schema = True
    auto_drop_schema = False

    def __str__(self):
        return self.name

class Domain(DomainMixin):
    pass
