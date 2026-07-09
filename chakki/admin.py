from django.contrib import admin
from .models import ChakkiCustomer, ChakkiSetting, ChakkiOrder, SellingCategory, SellingPrice, SellingOrderItem

admin.site.register(ChakkiCustomer)
admin.site.register(ChakkiSetting)
admin.site.register(ChakkiOrder)
admin.site.register(SellingCategory)
admin.site.register(SellingPrice)
admin.site.register(SellingOrderItem)
