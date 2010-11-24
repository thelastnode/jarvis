from django.shortcuts import render_to_response
from django.template import RequestContext

def render_to(template):
    def wrapper(f):
        def wrapped_f(request, *args, **kwargs):
            d = f(request, *args, **kwargs)
            if d == None:
                d = {}
            if isinstance(d, dict):
                return render_to_response(template,
                              d,context_instance=RequestContext(request))
            else:
                return d
        return wrapped_f
    return wrapper
