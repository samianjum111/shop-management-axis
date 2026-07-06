from django.urls import path, include
from . import views

urlpatterns = [
    path("", views.root_redirect, name="root"),
    path('login/', views.redirect_to_portal_login, name='login'),
    path('portal/<slug:schema_name>/', views.portal_login, name='portal_login'),
    path('portal/<slug:schema_name>/dashboard/', views.portal_dashboard, name='portal_dashboard'),
    path('portal/<slug:schema_name>/logout/', views.portal_logout, name='portal_logout'),
    path('portal/<slug:schema_name>/chakki/', include('chakki.urls')),
    path('portal/<slug:schema_name>/expenses/', include('expenses.urls')),
]