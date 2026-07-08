from django.db import models
from django.utils import timezone
from decimal import Decimal

class ChakkiCustomer(models.Model):
    tenant = models.ForeignKey('tenants.Tenant', on_delete=models.CASCADE, null=True, blank=True)
    name = models.CharField(max_length=100)
    phone = models.CharField(max_length=20, blank=True)
    address = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    is_regular = models.BooleanField(default=False, help_text='Regular customer (saved for future orders)')

    def __str__(self):
        return self.name

class ChakkiSetting(models.Model):
    tenant = models.ForeignKey('tenants.Tenant', on_delete=models.CASCADE, null=True, blank=True)
    grinding_rate = models.DecimalField(max_digits=10, decimal_places=2, default=10.0, help_text="Per KG (deprecated)")
    cleaning_rate = models.DecimalField(max_digits=10, decimal_places=2, default=5.0, help_text="Per KG (deprecated)")

    def __str__(self):
        return f"Grind: {self.grinding_rate}, Clean: {self.cleaning_rate}"

class ChakkiCategory(models.Model):
    tenant = models.ForeignKey('tenants.Tenant', on_delete=models.CASCADE, null=True, blank=True)
    name = models.CharField(max_length=50, help_text="e.g., Wheat, Rice, Maize")
    description = models.TextField(blank=True)
    grinding_rate = models.DecimalField(max_digits=10, decimal_places=2, default=0, help_text="Per KG grinding charge")
    cleaning_rate = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True, help_text="Per KG cleaning charge (optional)")

    def __str__(self):
        return self.name

class ChakkiOrderItem(models.Model):
    tenant = models.ForeignKey('tenants.Tenant', on_delete=models.CASCADE, null=True, blank=True)
    order = models.ForeignKey('ChakkiOrder', on_delete=models.CASCADE, related_name='items')
    category = models.ForeignKey(ChakkiCategory, on_delete=models.CASCADE)
    total_kg = models.DecimalField(max_digits=10, decimal_places=2)
    is_cleaning_done = models.BooleanField(default=False)
    grinding_charges = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    cleaning_charges = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    item_total = models.DecimalField(max_digits=10, decimal_places=2, default=0)

    def save(self, *args, **kwargs):
        self.grinding_charges = self.total_kg * self.category.grinding_rate
        if self.is_cleaning_done and self.category.cleaning_rate is not None:
            self.cleaning_charges = self.total_kg * self.category.cleaning_rate
        else:
            self.cleaning_charges = 0
        self.item_total = self.grinding_charges + self.cleaning_charges
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.category.name} - {self.total_kg}kg"

class ChakkiOrder(models.Model):
    tenant = models.ForeignKey('tenants.Tenant', on_delete=models.CASCADE, null=True, blank=True)
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('ready', 'Ready'),
        ('completed', 'Completed'),
        ('cancelled', 'Cancelled'),
    ]
    PAYMENT_STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('ready', 'Ready'),
        ('completed', 'Completed'),
        ('cancelled', 'Cancelled'),
    ]
    customer = models.ForeignKey(ChakkiCustomer, on_delete=models.CASCADE)
    total_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    amount_paid = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    ready_time = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    payment_status = models.CharField(max_length=20, choices=PAYMENT_STATUS_CHOICES, default='unpaid')
    created_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    @property
    def remaining_amount(self):
        return self.total_amount - self.amount_paid

    def save(self, *args, **kwargs):
        if self.pk:
            grinding_total = sum(item.item_total for item in self.items.all())
            selling_total = sum(item.total for item in self.selling_items.all())
            self.total_amount = grinding_total + selling_total
        if self.amount_paid == 0:
            self.payment_status = 'unpaid'
        elif self.amount_paid >= self.total_amount:
            self.payment_status = 'paid'
            self.amount_paid = self.total_amount
        else:
            self.payment_status = 'partial'
        super().save(*args, **kwargs)

    def __str__(self):
        return f"Order #{self.id} - {self.customer.name}"


    @property
    def can_cancel(self):
        from django.utils import timezone
        from datetime import timedelta
        if self.status == 'completed' or self.status == 'cancelled':
            return False
        if timezone.now() - self.created_at > timedelta(minutes=30):
            return False
        return True


# ===== Selling (Buying) Items =====
class SellingCategory(models.Model):
    tenant = models.ForeignKey('tenants.Tenant', on_delete=models.CASCADE, null=True, blank=True)
    name = models.CharField(max_length=50)
    description = models.TextField(blank=True)

    def __str__(self):
        return self.name

    class Meta:
        verbose_name_plural = "Selling Categories"

class SellingPrice(models.Model):
    MEASUREMENT_CHOICES = [
        ('kg', 'KG'),
        ('liter', 'Liter'),
        ('gram', 'Gram'),
        ('packet', 'Packet'),
        ('dozen', 'Dozen'),
        ('piece', 'Piece'),
        ('bottle', 'Bottle'),
    ]
    tenant = models.ForeignKey('tenants.Tenant', on_delete=models.CASCADE, null=True, blank=True)
    category = models.ForeignKey(SellingCategory, on_delete=models.CASCADE, related_name='prices')
    measurement = models.CharField(max_length=20, choices=MEASUREMENT_CHOICES)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    stock = models.DecimalField(max_digits=10, decimal_places=2, default=0, help_text="Available quantity in stock")
    purchase_price = models.DecimalField(max_digits=10, decimal_places=2, default=0, help_text="Cost price per unit (for profit calculation)")

    def __str__(self):
        return f"{self.category.name} - {self.get_measurement_display()} (₹{self.price})"

class SellingOrderItem(models.Model):
    tenant = models.ForeignKey('tenants.Tenant', on_delete=models.CASCADE, null=True, blank=True)
    order = models.ForeignKey('ChakkiOrder', on_delete=models.CASCADE, related_name='selling_items')
    selling_price = models.ForeignKey(SellingPrice, on_delete=models.CASCADE)
    quantity = models.DecimalField(max_digits=10, decimal_places=2)
    total = models.DecimalField(max_digits=10, decimal_places=2, default=0)

    def save(self, *args, **kwargs):
        self.total = self.quantity * self.selling_price.price
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.selling_price.category.name} - {self.quantity}{self.selling_price.get_measurement_display()}"
