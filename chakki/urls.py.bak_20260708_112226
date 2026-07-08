
from django.urls import path
from . import views

urlpatterns = [
    path('', views.chakki_home, name='chakki_home'),
    path('add/', views.add_order, name='add_order'),
    path('calculate/', views.calculate_order, name='calculate_order'),
    path('orders/<str:order_type>/', views.order_list, name='order_list'),
    path('order/<int:order_id>/', views.order_detail, name='order_detail'),
    path('complete/<int:order_id>/', views.complete_order, name='complete_order'),
    path('transcript/<int:order_id>/', views.generate_transcript, name='generate_transcript'),
    path('settings/', views.settings_view, name='chakki_settings'),
    path('search/', views.search, name='chakki_search'),
    path('transcript-modal/<int:order_id>/', views.get_transcript_modal, name='get_transcript_modal'),


    path('customers/', views.customer_list, name='customer_list'),
    path('customer/<int:customer_id>/', views.customer_profile, name='customer_profile'),
    path('order/add/', views.add_order, name='add_order'),
    path('order/confirmation/<int:order_id>/', views.order_confirmation, name='order_confirmation'),
    path('customer/add-from-order/<int:order_id>/', views.add_customer_from_order, name='add_customer_from_order'),


    path('complete-action/<int:order_id>/', views.complete_order_action, name='complete_order_action'),
    path('complete-partial/<int:order_id>/', views.order_complete_partial, name='order_complete_partial'),
    path('walk-profile/', views.walk_profile, name='walk_profile'),
    path('convert-walk/<int:customer_id>/', views.convert_walk_to_regular, name='convert_walk_to_regular'),

    path('customer/create/', views.create_customer, name='create_customer'),
    path('check-ready/', views.check_ready_orders, name='check_ready_orders'),
    path('api/selling-prices/', views.selling_prices_api, name='selling_prices_api'),
]