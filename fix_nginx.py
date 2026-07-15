#!/usr/bin/env python3
import subprocess

nginx_conf = '''user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
    multi_accept on;
}

http {
    ##
    # Basic Settings
    ##
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    types_hash_max_size 2048;
    server_tokens off;
    client_max_body_size 100M;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ##
    # SSL Settings
    ##
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers HIGH:!aNULL:!MD5;

    ##
    # Logging Settings
    ##
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    ##
    # Gzip Settings (ENABLED - for faster loading)
    ##
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_min_length 256;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml
        application/xml+rss
        application/rss+xml
        application/atom+xml
        application/ld+json
        application/manifest+json
        application/x-web-app-manifest+json
        text/cache-manifest
        text/vtt
        image/svg+xml
        application/vnd.ms-fontobject
        application/x-font-ttf
        font/opentype
        font/woff
        font/woff2;

    ##
    # Virtual Host Configs
    ##
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
'''

with open('/etc/nginx/nginx.conf', 'w') as f:
    f.write(nginx_conf)

print("✅ Nginx config updated with full Gzip support.")
print("🔄 Testing and reloading Nginx...")
subprocess.run(["nginx", "-t"], check=True)
subprocess.run(["sudo", "systemctl", "reload", "nginx"], check=True)
print("✅ Nginx reloaded successfully!")
print("   Gzip compression is now enabled for all text-based files.")
print("   This will significantly reduce bandwidth and improve load times.")
