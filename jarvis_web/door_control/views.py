from django.contrib.auth import authenticate
from django.contrib.auth import login as auth_login
from django.contrib.auth import logout as auth_logout
from django.contrib.auth.decorators import login_required
from django.core.urlresolvers import reverse
from django.http import HttpResponseRedirect
from django.shortcuts import render_to_response

from jarvis_web.door_control.decorators import render_to
from jarvis_web.door_control.forms import LoginForm
from jarvis_web.door_control.models import QueueEntry, DoorState

@login_required
@render_to('home.html')
def home(request):
    if request.method == 'POST':
        QueueEntry(command=QueueEntry.COMMAND_CHOICES[0]).save()
    recent = DoorState.objects.order_by('-creation_time')[0]
    return {'is_locked': recent.is_locked }

@render_to('login.html')
def login(request, **kwargs):
    if request.method != 'POST':
        return { 'form' : LoginForm() }

    form = LoginForm(request.POST)
    if form.is_valid():
        username = form.cleaned_data['username']
        password = form.cleaned_data['password']

        user = authenticate(username=username, password=password)
        if user is not None:
            if user.is_active:
                auth_login(request, user)
                if 'next' in kwargs:
                    return HttpResponseRedirect(kwargs['next'])
                else:
                    return HttpResponseRedirect(reverse('home'))
            else:
                return { 'form': form , 'errors': ['User is suspended!']}
        else:
            return { 'form': form, 'errors': ['Invalid login!'] }
    else:
        return { 'form': form }

def logout(request):
    auth_logout(request)
    return HttpResponseRedirect(reverse('home'))
