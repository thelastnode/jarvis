from django.db import models
from django.contrib.auth.models import User

class UserProfile(models.Model):
    user = models.ForeignKey(User, unique=True)

    rfid_tag = models.CharField(max_length=128, blank=True, null=True, default='')
    has_access = models.BooleanField(default=False)

# Automatically create UserProfile for user:
def _create_profile_receiver(sender, instance, **kwargs):
    """Receives a signal whenever a User is created and creates a
    corresponding UserProfile for the user."""
    UserProfile.objects.get_or_create(user=instance)

models.signals.post_save.connect(_create_profile_receiver, sender=User)
