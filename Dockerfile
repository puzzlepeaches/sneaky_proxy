########################
# redirect.rules
FROM python:3.8.1-buster AS builder

ARG REDIRECT_URL
ENV REDIRECT_URL $REDIRECT_URL

RUN apt-get update

RUN apt-get install -y whois git

RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /
RUN git clone https://github.com/0xZDH/redirect.rules
WORKDIR /redirect.rules

RUN pip install --no-cache-dir -r requirements.txt

RUN chmod +x redirect_rules.py && \
    sed -i 's/\r//' redirect_rules.py

ADD ./exclude/ /redirect.rules/exclude/

RUN ./redirect_rules.py -d https://${REDIRECT_URL} --exclude-file exclude/exclude.txt
RUN sed -i -e '159d' /tmp/redirect.rules

########################
# Apache
FROM debian:stable-slim

ARG PROXY_DOMAIN
ARG HIDDEN_HOST

ENV PROXY_DOMAIN $PROXY_DOMAIN
ENV HIDDEN_HOST $HIDDEN_HOST

EXPOSE 443

RUN apt update && apt install certbot apache2 git python-certbot-apache vim -y
RUN a2enmod proxy proxy_http proxy_balancer lbmethod_byrequests rewrite proxy proxy_ajp proxy_http rewrite deflate headers proxy_balancer proxy_connect proxy_html

# Copying the latest redirect.rules over
COPY --from=builder /tmp/redirect.rules /etc/apache2/redirect.rules

# Getting our certificate
RUN certbot -d ${PROXY_DOMAIN} --apache --agree-tos -m contact@${PROXY_DOMAIN} -n

# Removing these lines cause im not really sure how to do this better
RUN sed -i '/<\/VirtualHost>/d' /etc/apache2/sites-enabled/000-default-le-ssl.conf
RUN sed -i '/<\/IfModule/d' /etc/apache2/sites-enabled/000-default-le-ssl.conf

# Adding redirect.rules to config 
RUN echo 'Include /etc/apache2/redirect.rules' >> /etc/apache2/sites-enabled/000-default-le-ssl.conf

# Updating configuration for proxy
RUN echo 'ProxyPreserveHost On' >> /etc/apache2/sites-enabled/000-default-le-ssl.conf
RUN echo '\t' SSLProxyEngine On >> /etc/apache2/sites-enabled/000-default-le-ssl.conf
RUN echo '\t' SSLProxyVerify none >> /etc/apache2/sites-enabled/000-default-le-ssl.conf
RUN echo '\t' SSLProxyCheckPeerCN off >> /etc/apache2/sites-enabled/000-default-le-ssl.conf
RUN echo '\t' SSLProxyCheckPeerName off >> /etc/apache2/sites-enabled/000-default-le-ssl.conf
RUN echo '\t' SSLProxyCheckPeerExpire off >> /etc/apache2/sites-enabled/000-default-le-ssl.conf
RUN echo '\t' ProxyPass / https://${HIDDEN_HOST}/ >> /etc/apache2/sites-enabled/000-default-le-ssl.conf
RUN echo '\t' ProxyPassReverse / https://${HIDDEN_HOST}/ >> /etc/apache2/sites-enabled/000-default-le-ssl.conf
RUN echo '</VirtualHost>' >> /etc/apache2/sites-enabled/000-default-le-ssl.conf
RUN echo '</IfModule>' >> /etc/apache2/sites-enabled/000-default-le-ssl.conf

# Updating redirect.rules
RUN sed -i '27 s/#//' /etc/apache2/redirect.rules
RUN sed -i -e '159d' /etc/apache2/redirect.rules
# RUN echo '\t' RewriteRule                           ^.*$             https://${HIDDEN_HOST}/                 [P] >> /etc/apache2/redirect.rules
# RUN echo ProxyPreserveHost On >> /etc/apache2/redirect.rules
# RUN echo ProxyPass / https://${HIDDEN_HOST}/ >> /etc/apache2/redirect.rules
# RUN echo ProxyPassReverse / https://${HIDDEN_HOST}/ >> /etc/apache2/redirect.rules
# RUN echo 'RewriteRule                           ^.*$                                    [P]' >> /etc/apache2/redirect.rules

CMD apachectl -D BACKGROUND && tail -f /var/log/apache2/error.log -f /var/log/apache2/access.log
