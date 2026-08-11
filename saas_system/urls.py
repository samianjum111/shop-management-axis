from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from subscriptions import views as subscription_views

urlpatterns = [
    path('admin/subscriptions/review/', subscription_views.review_subscriptions, name='global_subscription_review'),
    path('admin/', admin.site.urls),
    path('', include('core.urls')),
    path('portal/<slug:schema_name>/reports/', include('reports.urls')),
    path('portal/<slug:schema_name>/subscription/', include('subscriptions.urls')),    
    path('admin/subscriptions/approve/<int:request_id>/', subscription_views.admin_approve_request, name='admin_approve_request'),
    path('admin/subscriptions/reject/<int:request_id>/', subscription_views.admin_reject_request, name='admin_reject_request'),
]

# Media serving for development
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)