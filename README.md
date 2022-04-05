# Guacamole with docker-compose
This project is a fork of `https://github.com/boschkundendienst/guacamole-docker-compose`.
The goal of this fork is to require TOTP authentication using the native Guacamole TOTP extension, to enforce secure Postgres passwords, and to secure nginx with LetsEncrypt and auto renewal by using certbot.  We also secure nginx by rejecting any traffic not accessing the server with it's FQDN with a 444 response.

## Prerequisites
You need a working **docker** installation and **docker-compose** running on your machine.

## Quick start
Clone the GIT repository and start guacamole:

~~~bash
git clone "https://github.com/yois615/guacamole-docker-compose.git"
cd guacamole-docker-compose
./install.sh
~~~

You will be asked 3 questions:
1. The DNS hostname of this server to be used in the SSL Certificate
2. The email address to associate with LetsEncrypt (optional)
3. If you want to download and enable the TOTP extension for Guacamole

After the install, your guacamole server should now be available at `https://DNS of your server/`. Accessing via the IP address will not work as nginx rejects the traffic with 444. The default username is `guacadmin` with password `guacadmin`.  If you enabled TOTP, you will be prompted to set up your authenticator with a QR code.

## About Guacamole
Apache Guacamole is a clientless remote desktop gateway. It supports standard protocols like VNC, RDP, and SSH. It is called clientless because no plugins or client software are required. Thanks to HTML5, once Guacamole is installed on a server, all you need to access your desktops is a web browser.

It supports RDP, SSH, Telnet and VNC and is the fastest HTML5 gateway I know. Checkout the projects [homepage](https://guacamole.apache.org/) for more information.

## Details
To understand some details let's take a closer look at parts of the `docker-compose.yml` file:

### Networking
The following part of docker-compose.yml will create a network with name `guacnetwork_compose` in mode `bridged`.
~~~python
...
# networks
# create a network 'guacnetwork_compose' in mode 'bridged'
networks:
  guacnetwork_compose:
    driver: bridge
...
~~~

## install.sh
`install.sh` is a small script that creates `./init/initdb.sql` by downloading the docker image `guacamole/guacamole` and start it like this:

~~~bash
docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --postgres > ./init/initdb.sql
~~~

It creates the necessary database initialization file for postgres.

`install.sh` also creates the certbot configuration

## reset.sh
To reset the database to the beginning, just run `./reset.sh`.  This will not reset certbot data or reset the PostgresDB passwords.

## WOL

Wake on LAN (WOL) does not work and I will not fix that because it is beyound the scope of this repo. But [zukkie777](https://github.com/zukkie777) who also filed [this issue](https://github.com/boschkundendienst/guacamole-docker-compose/issues/12) fixed it. You can read about it on the [Guacamole mailing list](https://lists.apache.org/thread/tzwc02wxzkqfy48soj3ztsjqjh17tynl)

**Disclaimer**

Downloading and executing scripts from the internet may harm your computer. Make sure to check the source of the scripts before executing them!
