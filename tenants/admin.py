from django.contrib import admin
from django import forms
from django.contrib.auth import get_user_model
from .models import Tenant

User = get_user_model()

class TenantAdminForm(forms.ModelForm):
    admin_username = forms.CharField(max_length=150, required=True, label="Admin Username")
    admin_password = forms.CharField(
        widget=forms.PasswordInput,
        required=False,
        label="Admin Password (leave blank to keep current)"
    )

    class Meta:
        model = Tenant
        fields = ('name', 'schema_name', 'category')

    def save(self, commit=True):
        tenant = super().save(commit=False)
        username = self.cleaned_data['admin_username']
        password = self.cleaned_data.get('admin_password')

        # If tenant already has an owner, update that user
        if tenant.pk and tenant.owner:
            user = tenant.owner
            if user.username != username:
                user.username = username
                user.save()
            if password:
                user.set_password(password)
                user.save()
        else:
            # Create or get user
            user, created = User.objects.get_or_create(username=username)
            if created or password:
                user.set_password(password or User.objects.make_random_password())
                user.save()
            tenant.owner = user

        if commit:
            tenant.save()
        return tenant

@admin.register(Tenant)
class TenantAdmin(admin.ModelAdmin):
    form = TenantAdminForm
    list_display = ('name', 'schema_name', 'category', 'owner', 'created_at')
    readonly_fields = ('created_at',)
    fields = ('name', 'schema_name', 'category', 'admin_username', 'admin_password', 'created_at')
