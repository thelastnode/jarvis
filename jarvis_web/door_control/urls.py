from django.conf.urls.defaults import *

urlpatterns = patterns('jarvis_web.door_control.views',
    url('^$', 'home', name='home'),
)
