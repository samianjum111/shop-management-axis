from django.urls import path
from . import views

urlpatterns = [
    path('portal/<slug:schema_name>/', views.portal_login, name='portal_login'),
    path('portal/<slug:schema_name>/dashboard/', views.portal_dashboard, name='portal_dashboard'),
    path('portal/<slug:schema_name>/logout/', views.portal_logout, name='portal_logout'),
]
