from django.urls import path
from . import views

app_name = 'subscriptions'

urlpatterns = [
    path('payment/', views.payment_required, name='subscription_payment'),
    path('upload/', views.upload_screenshot, name='upload_screenshot'),
    path('processing/', views.processing_page, name='subscription_processing'),

    path('review/', views.review_subscriptions, name='review_subscriptions'),
    path('approve/<int:request_id>/', views.approve_request, name='approve_request'),
    path('reject/<int:request_id>/', views.reject_request, name='reject_request'),
]
