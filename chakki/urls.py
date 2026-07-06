
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

]