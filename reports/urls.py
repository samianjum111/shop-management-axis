from django.urls import path
from . import views

urlpatterns = [
    path('', views.dashboard, name='reports_dashboard'),
    path('revenue/', views.revenue, name='reports_revenue'),
    path('categories/', views.categories, name='reports_categories'),
    path('customers/', views.customers, name='reports_customers'),
    path('orders/', views.orders_report, name='reports_orders'),
]
