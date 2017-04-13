# Builds Nginx-RTMP-FFMPEG for sCore library
# - Alpine base
# - ffmpeg custom build
# - nginx with rtmp module

FROM alpine:latest
MAINTAINER BiStormLLC <info@bistorm.org>

ENV NGINX_VERSION 1.12.0
ENV NGINX_RTMP_VERSION 1.1.11
ENV FFMPEG_VERSION 3.2.4

# Entrypoint file
COPY ./storm /usr/local/bin
COPY ./static /static

RUN mkdir -p /etc/data && mkdir /www

# Add nginx user
RUN addgroup -S nginx && adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx 

# Install dependencies
RUN apk update && apk add \
  bash vim gcc binutils-libs binutils build-base libgcc make pkgconf pkgconfig \
  libressl libressl-dev linux-headers gnupg libxslt-dev gd-dev ca-certificates pcre \
  musl-dev libc-dev pcre-dev zlib-dev

# Get nginx source.
RUN cd /tmp && wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
  && tar zxf nginx-${NGINX_VERSION}.tar.gz \
  && rm nginx-${NGINX_VERSION}.tar.gz

# Get nginx-rtmp module.
RUN cd /tmp && wget https://github.com/arut/nginx-rtmp-module/archive/v${NGINX_RTMP_VERSION}.tar.gz \
  && tar zxf v${NGINX_RTMP_VERSION}.tar.gz && rm v${NGINX_RTMP_VERSION}.tar.gz

# Compile nginx with nginx-rtmp module.
RUN cd /tmp/nginx-${NGINX_VERSION} \
  && ./configure \
  --prefix=/etc/nginx \
  --sbin-path=/usr/sbin/nginx \
  --modules-path=/usr/lib/nginx/modules \
  --user=nginx \
  --group=nginx \
  --with-http_ssl_module \
  --with-stream_ssl_module \
  --with-stream_ssl_preread_module \
  --with-stream_realip_module \
  --with-stream_geoip_module=dynamic \
  --with-http_slice_module \
  --add-module=/tmp/nginx-rtmp-module-${NGINX_RTMP_VERSION} \
  --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx-error.log --http-log-path=/var/log/nginx-access.log \
  --with-debug
RUN cd /tmp/nginx-${NGINX_VERSION} && make && make install

# ffmpeg dependencies.
RUN apk add --update build-base nasm yasm lame-dev libogg-dev x264-dev libvpx-dev libvorbis-dev x265-dev freetype-dev libass-dev libwebp-dev rtmpdump-dev libtheora-dev opus-dev
RUN echo http://dl-cdn.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories
RUN apk add --update fdk-aac-dev

# Get ffmpeg source.
RUN cd /tmp/ && wget http://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz \
  && tar zxf ffmpeg-${FFMPEG_VERSION}.tar.gz && rm ffmpeg-${FFMPEG_VERSION}.tar.gz

# Compile ffmpeg.
RUN cd /tmp/ffmpeg-${FFMPEG_VERSION} && \
  ./configure \
  --enable-version3 \
  --enable-gpl \
  --enable-nonfree \
  --enable-small \
  --enable-libmp3lame \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libvpx \
  --enable-libtheora \
  --enable-libvorbis \
  --enable-libopus \
  --enable-libfdk-aac \
  --enable-libass \
  --enable-libwebp \
  --enable-librtmp \
  --enable-postproc \
  --enable-avresample \
  --enable-libfreetype \
  --disable-debug \
  && make && make install && make distclean \
  && ln -s ../../usr/lib/nginx/modules /etc/nginx/modules 

# Cleanup.
RUN rm -rf /var/cache/* /tmp/*

# Add default config file with RTMP configuration
COPY ./nginx.conf /etc/nginx

EXPOSE 1935
EXPOSE 80

ENTRYPOINT ["storm"]
CMD ["nginx", "-g", "pid /tmp/nginx.pid; daemon off;"]
