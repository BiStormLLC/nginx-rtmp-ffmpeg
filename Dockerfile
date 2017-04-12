# Builds sCore Primary Services Container
# - Alpine base
# - ffmpeg custom build
# - nginx with rtmp module
# - HDHomerun Config
# Dockerfile config borrowed from automated build of nginx image, 4/6/2016

FROM alpine:latest
MAINTAINER BiStormLLC <info@bistorm.org>

ENV NGINX_VERSION=1.11.9 \
    FFMPEG_VERSION=3.0.2

# Entrypoint file
COPY ./storm /usr/local/bin

WORKDIR /tmp/bistorm

RUN addgroup -S nginx && \
    adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx && \
    apk add --update --no-cache \
        vim \
        bash && \
    ngConfig="\ 
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --modules-path=/usr/lib/nginx/modules \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
        --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
        --user=nginx \
        --group=nginx \
        --with-http_ssl_module \
        --with-http_realip_module \
        --with-http_addition_module \
        --with-http_sub_module \
        --with-http_dav_module \
        --with-http_flv_module \
        --with-http_mp4_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_random_index_module \
        --with-http_secure_link_module \
        --with-http_stub_status_module \
        --with-http_auth_request_module \
        --with-http_xslt_module=dynamic \
        --with-http_image_filter_module=dynamic \
        --with-http_geoip_module=dynamic \
        --with-http_perl_module=dynamic \
        --with-threads \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module \
        --with-stream_realip_module \
        --with-stream_geoip_module=dynamic \
        --with-http_slice_module \
        --with-mail \
        --with-mail_ssl_module \
        --with-compat \
        --with-file-aio \
        --with-http_v2_module \
        --add-module=nginx-rtmp-module" && \
    buildDeps="autoconf \
        automake \
        binutils \
        build-base \
        nasm \
        tar \
        bzip2 \
        zlib-dev \
        libc-dev \
        openssl \
        libstdc++ \
        ca-certificates \
        pcre-dev \
        yasm-dev \
        lame-dev \
        libogg-dev \
        x264-dev \
        libvpx-dev \
        libvorbis-dev \
        x265-dev \
        freetype-dev \
        libass-dev \
        libwebp-dev \
        rtmpdump-dev \
        libtheora-dev \
        opus-dev \
        cmake \
        curl \
        coreutils \
        g++ \
        gcc \
        gnupg \
        libtool \
        make \
        python \
        linux-headers \
        libxslt-dev \
        gd-dev \
        geoip-dev \
        perl-dev \
        git \
        " && \
    export MAKEFLAGS="-j$(($(grep -c ^processor /proc/cpuinfo) + 1))" && \
    apk add --update --no-cache --virtual .build-deps ${buildDeps} \
    \
    ##
    #
    # NGINX
    #
    ##
    && curl -f http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
    && mkdir -p /usr/src \
    && tar -zxC /usr/src -f nginx.tar.gz \
    && rm nginx.tar.gz \
    \
    # Added by BiStorm: Nginx-RTMP module
    && cd /usr/src/nginx-$NGINX_VERSION \
    && git clone https://github.com/sergey-dryabzhinsky/nginx-rtmp-module.git \
    && ./configure $ngConfig  \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && mv objs/nginx objs/nginx-debug \
    && mv objs/ngx_http_xslt_filter_module.so objs/ngx_http_xslt_filter_module-debug.so \
    && mv objs/ngx_http_image_filter_module.so objs/ngx_http_image_filter_module-debug.so \
    && mv objs/ngx_http_geoip_module.so objs/ngx_http_geoip_module-debug.so \
    && mv objs/ngx_http_perl_module.so objs/ngx_http_perl_module-debug.so \
    && mv objs/ngx_stream_geoip_module.so objs/ngx_stream_geoip_module-debug.so \
    && ./configure $ngConfig \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && make install \
    && rm -rf /etc/nginx/html/ \
    && mkdir /etc/nginx/conf.d/ \
    && mkdir -p /usr/share/nginx/html/ \
    && install -m644 html/index.html /usr/share/nginx/html/ \
    && install -m644 html/50x.html /usr/share/nginx/html/ \
    && install -m755 objs/nginx-debug /usr/sbin/nginx-debug \
    && install -m755 objs/ngx_http_xslt_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_xslt_filter_module-debug.so \
    && install -m755 objs/ngx_http_image_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_image_filter_module-debug.so \
    && install -m755 objs/ngx_http_geoip_module-debug.so /usr/lib/nginx/modules/ngx_http_geoip_module-debug.so \
    && install -m755 objs/ngx_http_perl_module-debug.so /usr/lib/nginx/modules/ngx_http_perl_module-debug.so \
    && install -m755 objs/ngx_stream_geoip_module-debug.so /usr/lib/nginx/modules/ngx_stream_geoip_module-debug.so \
    && ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
    && strip /usr/sbin/nginx* \
    && strip /usr/lib/nginx/modules/*.so \
    && rm -rf /usr/src/nginx-$NGINX_VERSION \
    \
    # Bring in gettext so we can get `envsubst`, then throw 
    # the rest away. To do this, we need to install `gettext` 
    # then move `envsubst` out of the way so `gettext` can 
    # be deleted completely, then move `envsubst` back. 
    && apk add --no-cache --virtual .gettext gettext \
    && mv /usr/bin/envsubst /tmp/ \
    && runDeps="$( \
            scanelf --needed --nobanner /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
                    | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
                    | sort -u \
                    | xargs -r apk info --installed \
                    | sort -u \
    )" \
    && apk add --no-cache --virtual .nginx-rundeps $runDeps \
    && apk del .gettext \
    && mv /tmp/envsubst /usr/local/bin/ \
    \
    # forward request and error logs to docker log collector \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log && \
    \
    ##
    #
    # FFMPEG
    #
    ##
    DIR=$(mktemp -d) && cd ${DIR} \
    && curl -s http://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.gz | tar zxvf - -C . \
    && cd ffmpeg-${FFMPEG_VERSION} && \
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
        --enable-libass \
        --enable-libwebp \
        --enable-librtmp \
        --enable-postproc \
        --enable-avresample \
        --enable-libfreetype \
        --enable-openssl \
        --disable-debug \
    && make \
    && make install \
    # cleanup
    && make distclean \
    && rm -rf ${DIR} \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/* /usr/local/include

# Add default config file with RTMP configuration
COPY ./nginx.conf /etc/nginx

EXPOSE 80 443 1935
ENTRYPOINT ["storm"]
CMD ["nginx", "-g", "pid /tmp/nginx.pid; daemon off;"]