from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('core.urls')),
    path('portal/<slug:schema_name>/reports/', include('reports.urls')),
    path('portal/<slug:schema_name>/subscription/', include('subscriptions.urls')),
]

# Media serving for development
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
