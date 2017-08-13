FROM registry.aegonthtf.com/@base_image_library@/nginx
RUN rm -f /etc/nginx/conf.d/default.conf
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY static-html-directory /usr/share/nginx/html@context_path@