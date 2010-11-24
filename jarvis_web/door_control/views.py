from django.shortcuts import render_to_response

from jarvis_web.door_control.decorators import render_to

@render_to('home.html')
def home(self):
    pass
