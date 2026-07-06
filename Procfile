web: python manage.py migrate --noinput --fake-initial && python manage.py migrate_schemas --noinput && python manage.py collectstatic --noinput && gunicorn saas_system.wsgi
