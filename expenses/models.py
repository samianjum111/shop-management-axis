from django.db import models

class Expense(models.Model):
    CATEGORY_CHOICES = [
        ('general', 'General'),
        ('medicine', 'Medicine'),
        ('food', 'Food'),
        ('utility', 'Utility'),
        ('given_loan', 'Given Loan (Udhaar)'),
        ('taken_loan', 'Taken Loan'),
        ('other', 'Other'),
    ]
    title = models.CharField(max_length=200)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES, default='general')
    description = models.TextField(blank=True)
    date = models.DateTimeField(auto_now_add=True)
    is_credit = models.BooleanField(default=False, help_text="Given to someone (receivable)")
    person_name = models.CharField(max_length=100, blank=True)
    due_date = models.DateField(null=True, blank=True)

    def __str__(self):
        return f"{self.title} - {self.amount}"
