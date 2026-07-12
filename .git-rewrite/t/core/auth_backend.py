from django.contrib.auth.backends import ModelBackend
from django.contrib.auth import get_user_model
from .middleware import get_current_tenant_db

class TenantAuthBackend(ModelBackend):
    def authenticate(self, request, username=None, password=None, **kwargs):
        db = get_current_tenant_db()
        if not db:
            return None
        User = get_user_model()
        try:
            user = User.objects.using(db).get(username=username)
            if user.check_password(password):
                return user
        except User.DoesNotExist:
            return None
        return None
