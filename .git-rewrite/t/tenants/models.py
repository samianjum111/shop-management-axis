from django.db import models
from django.contrib.auth.models import User

class Tenant(models.Model):
    name = models.CharField(max_length=100)
    CATEGORY_CHOICES = [('chakki', 'Atta Chakki')]
    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES, default='chakki')
    schema_name = models.CharField(max_length=100, unique=True)
    db_name = models.CharField(max_length=100, unique=True)
    db_user = models.CharField(max_length=100, blank=True)
    db_password = models.CharField(max_length=100, blank=True)
    db_host = models.CharField(max_length=100, default='localhost')
    db_port = models.CharField(max_length=10, default='5432')
    owner = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name
