from django.db import models

class Tenant(models.Model):
    name = models.CharField(max_length=100)
    schema_name = models.CharField(max_length=100, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    category = models.CharField(max_length=20, default='chakki')

    def __str__(self):
        return self.name
