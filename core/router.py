from .middleware import get_current_tenant_db

class TenantRouter:
    def _get_tenant_db(self):
        return get_current_tenant_db()

    def db_for_read(self, model, **hints):
        app_label = model._meta.app_label
        # These apps must always read from default DB
        if app_label in ['tenants', 'sessions', 'admin', 'contenttypes']:
            return 'default'
        tenant_db = self._get_tenant_db()
        return tenant_db if tenant_db else 'default'

    def db_for_write(self, model, **hints):
        app_label = model._meta.app_label
        if app_label in ['tenants', 'sessions', 'admin', 'contenttypes']:
            return 'default'
        tenant_db = self._get_tenant_db()
        return tenant_db if tenant_db else 'default'

    def allow_relation(self, obj1, obj2, **hints):
        return True

    def allow_migrate(self, db, app_label, model_name=None, **hints):
        if app_label == 'tenants':
            return db == 'default'
        if db != 'default':
            return True
        # default DB gets tenants, sessions, admin, contenttypes
        return app_label in ['tenants', 'sessions', 'admin', 'contenttypes']
