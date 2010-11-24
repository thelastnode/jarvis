from django.db import models
from django.contrib.auth.models import User

class UserProfile(models.Model):
    user = models.ForeignKey(User, unique=True)

    rfid_tag = models.CharField(max_length=128, blank=True, null=True, default='')
    has_access = models.BooleanField(default=False)
    is_admin = models.BooleanField(default=False)

    def __unicode__(self):
        return self.user.username

class DoorState(models.Model):
    creation_time = models.DateTimeField(auto_now_add=True)
    is_locked = models.BooleanField(blank=False, null=False)

    def __unicode__(self):
        return str(self.creation_time) + ": " + str(self.is_locked)

class RfidLogEntry(models.Model):
    creation_time = models.DateTimeField(auto_now_add=True)
    tag = models.CharField(max_length=256, blank=False, null=False)

    def __unicode__(self):
        return str(self.creation_time) + ": " + str(self.tag)

class QueueEntry(models.Model):
    COMMAND_CHOICES = (
        (0, 'Toggle'),
        (1, 'Lock'),
        (2, 'Unlock'),
        (3, 'Invalid'),
    )
    creation_time = models.DateTimeField(auto_now_add=True, blank=False, null=False)
    command = models.IntegerField(choices=COMMAND_CHOICES, blank=False, null=False)

    def __unicode__(self):
        return str(self.creation_time) + ": " + COMMAND_CHOICES[command][1]

# Automatically create UserProfile for user:
def _create_profile_receiver(sender, instance, **kwargs):
    """Receives a signal whenever a User is created and creates a
    corresponding UserProfile for the user."""
    UserProfile.objects.get_or_create(user=instance)

models.signals.post_save.connect(_create_profile_receiver, sender=User)
