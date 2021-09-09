# sneaky_proxy

Hiding infrastructure from the boys in blue! See my blog article linked below for details on how all this works:

* [Never stop frontin](https://www.sprocketsecurity.com/blog/never-stop-frontin-how-to-quickly-setup-a-redirector-and-transparent-reverse-proxy)

# Why?

A reverse proxy allows you to quickly and transparently proxy traffic to and from your infrastructure. Traditionally, it has been difficult to automate this process and is never an easy one size fits all solution. The container included in this project not only stands up a reverse proxy, it also grabs an SSL certificate and installs the latest version of [redirect.rules](https://github.com/0xZDH/redirect.rules). 

# How?

Getting the container up and running is very simple. The following pre-requisites are required prior to starting the container:

* A host with an assigned A record of the domain you plan to front with
* The host must allow inbound traffic on port 443/tcp
* Docker and docker-compose installed

Following this, modify the included .env file to reflect your desired configuration. The .env file currently looks like this:

```
REDIRECT_URL=outlook.office365.com
PROXY_DOMAIN=example.com
HIDDEN_HOST=test.example.com
```

Let's say you want to redirect undesireable traffic to outlook.office365.com, have an DNS A record of acme.com assigned to your host and a GoPhish server hosted somewhere else with the subdomain mail.acme.com. Your configuration file will then appear like the following:

```
REDIRECT_URL=outlook.office365.com
PROXY_DOMAIN=acme.com
HIDDEN_HOST=mail.acme.com
```

Once you have modified your configuration file to meet your needs, execute the following command to build the container:

```
docker-compose build
```

Note that during this process a certificate is created for your A record and installed inside of the container. Following this, execute the following command to start the sneaky_proxy container in the background:

```
docker-compose up -d
```

On run, the container tails the error and access logs from Apache. You can review these logs by executing the following command:

```
docker logs -f sneaky_proxy
```
