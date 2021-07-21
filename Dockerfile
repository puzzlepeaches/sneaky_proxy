########################
# redirect.rules

FROM python:3.8.1-buster AS builder

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

RUN ./redirect_rules.py -d https://${redirect_domain} --exclude-file exclude/exclude.txt

########################
# Apache 

FROM debian:stable-slim

EXPOSE 443

RUN apt update && apt install certbot apache2 git python-certbot-apache -y
RUN a2enmod proxy proxy_http proxy_balancer lbmethod_byrequests rewrite
RUN server restart apache2

# Copying the latest redirect.rules over
COPY --from=builder /tmp/redirect.rules /etc/apache2/redirect.rules

# Getting our certificate
RUN certbot -d ${proxy_domain} --apache --agree-tos -m contact@${proxy_domain} -n

# Removing these lines cause im not really sure how to do this better
RUN sed -i '/<\/VirtualHost>/d' /etc/apache2/sites-enabled/000-default-le-ssl.conf
RUN sed -i '/<\/IfModule/d' /etc/apache2/sites-enabled/000-default-le-ssl.conf


# Updating configuration for proxy
RUN echo 'ProxyPreserveHost On' >> /etc/apache2/sites-enabled/000-default-le-ssl.conf
RUN echo 'SSLProxyEngine On' >> /etc/apache2/sites-enabled/000-default-le-ssl.conf
RUN echo 'SSLProxyVerify none' >> /etc/apache2/sites-enabled/000-default-le-ssl.conf
RUN echo 'SSLProxyCheckPeerCN off' >> /etc/apache2/sites-enabled/000-default-le-ssl.conf
RUN echo 'SSLProxyCheckPeerName off' >> /etc/apache2/sites-enabled/000-default-le-ssl.conf
RUN echo 'SSLProxyCheckPeerExpire off' >> /etc/apache2/sites-enabled/000-default-le-ssl.conf
RUN echo ProxyPass / https://${hidden_host}/ >> /etc/apache2/sites-enabled/000-default-le-ssl.conf
RUN echo ProxyPassReverse / https://${hidden_host}/ >> /etc/apache2/sites-enabled/000-default-le-ssl.conf
RUN echo '</VirtualHost>' >> /etc/apache2/sites-enabled/000-default-le-ssl.conf
RUN echo '</IfModule>' >> /etc/apache2/sites-enabled/000-default-le-ssl.conf

# Updating redirect.rules
RUN echo 'ProxyPreserveHost On' >> /etc/apache2/redirect.rules
RUN echo ProxyPass / https://${hidden_host}/ >> /etc/apache2/redirect.rules
RUN echo ProxyPassReverse / https://${hidden_host}/ >> /etc/apache2/redirect.rules


