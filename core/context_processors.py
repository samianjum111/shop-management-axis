def tenant_processor(request):
    return {'tenant': getattr(request, 'tenant', None)}
