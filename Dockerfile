FROM python:3.6-alpine

WORKDIR /disqus
ADD requirements.txt /disqus
ADD requirements /disqus/requirements

# Install system dependencies, which are required by python packages

# We are using WebPusher for push notification which uses pyelliptic OpenSSL which
# uses `ctypes.util.find_library`. `ctypes.util.find_library` seems to be broken with current version of alpine.
# `ctypes.util.find_library` make use of gcc to search for library, and hence we need this during
# runtime.
# https://github.com/docker-library/python/issues/111
RUN apk add --no-cache gcc

# Package all libraries installed as build-deps, as few of them might only be required during
# installation and during execution.
RUN apk add --no-cache --virtual build-deps \
      make \
      libc-dev \
      musl-dev \
      linux-headers \
      pcre-dev \
      postgresql-dev \
      libffi \
      libffi-dev \
      # Don't cache pip packages
      && pip install --no-cache-dir -r /disqus/requirements/production.txt \
      # Find all the library dependencies which are required by python packages.
      # This technique is being used in creation of python:alipne & slim images
      # https://github.com/docker-library/python/blob/master/3.6/alpine/Dockerfile
      && runDeps="$( \
      scanelf --needed --nobanner --recursive /usr/local \
              | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
              | sort -u \
              | xargs -r apk info --installed \
              | sort -u \
      )" \
      && apk add --virtual app-rundeps $runDeps \
      # Get rid of all unused libraries
      && apk del build-deps \
      # find_library is broken in alpine, looks like it doesn't take version of lib in consideration
      # and apk del seems to remove sim-link /usr/lib/libcrypto.so
      # Create sim-link again
      # TODO: Find a better way to do this more generically.
      && ln -s /usr/lib/$(ls /usr/lib/ | grep libcrypto | head -n1) /usr/lib/libcrypto.so

ADD . /disqus
RUN python manage.py collectstatic --no-input
RUN chmod +x ./wait-for-it.sh
