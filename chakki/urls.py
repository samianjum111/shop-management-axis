from django.urls import path
from . import views

urlpatterns = [
    path('', views.dashboard, name='chakki_dashboard'),
    path('add/', views.add_order, name='add_order'),
    path('complete/<int:order_id>/', views.complete_order, name='complete_order'),
    path('settings/', views.settings_view, name='chakki_settings'),
]
