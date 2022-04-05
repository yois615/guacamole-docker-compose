#!/bin/sh
#
# check if docker is running
if ! (docker ps >/dev/null 2>&1)
then
	echo "docker daemon not running, will exit here!" >&2
	exit
fi

if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Error: docker-compose is not installed.' >&2
  exit 1
fi


read -p 'Domain name for SSL and nginx: ' domain_name
read -p 'Email address for LetsEncrypt: ' email_address
read -p 'Use Guacamole TOTP extension? (Y/n) ' use_totp

if [ "$use_totp" != 'n' ] && [ "$use_totp" != 'N' ]; then
	echo "Configuring TOTP"
	mkdir -p ./home/extensions >/dev/null 2>&1
	wget https://dlcdn.apache.org/guacamole/1.4.0/binary/guacamole-auth-totp-1.4.0.tar.gz
	tar -xf guacamole-auth-totp-1.4.0.tar.gz
	mv ./guacamole-auth-totp-1.4.0/guacamole-auth-totp-1.4.0.jar ./home/extensions
fi

echo "Creating random database password..."
DBPW=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13 ; echo '')
sed -i "s/ChooseYourOwnPasswordHere1234/$DBPW/g" docker-compose.yml

echo "Preparing folder init and creating ./init/initdb.sql"
mkdir ./init >/dev/null 2>&1
chmod -R +x ./init
docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --postgres > ./init/initdb.sql
echo "done"

echo "Staging LetsEncrypt config for certbot"
rsa_key_size=2048
data_path="./nginx/certbot"
staging=0 # Set to 1 if you're testing your setup to avoid hitting request limits

if [ -d "$data_path" ]; then
  read -p "Existing data found for $domain_name. Continue and replace existing certificate? (y/N) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    exit
  fi
fi

if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  echo "### Downloading recommended TLS parameters ..."
  mkdir -p "$data_path/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$data_path/conf/options-ssl-nginx.conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$data_path/conf/ssl-dhparams.pem"
  echo
fi

echo "### Creating dummy certificate for $domain_name ..."
path="/etc/letsencrypt/live/$domain_name"
mkdir -p "$data_path/conf/live/$domain_name"
docker-compose run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1\
    -keyout '$path/privkey.pem' \
    -out '$path/fullchain.pem' \
    -subj '/CN=localhost'" certbot
echo

echo "### Creating nginx config..."
sed -i "s/example.example/$domain_name/g" ./nginx/mysite.template

echo "### Starting nginx ..."
docker-compose up --force-recreate -d nginx
echo

echo "### Deleting dummy certificate for $domain_name ..."
docker-compose run --rm --entrypoint "\
  rm -Rf /etc/letsencrypt/live/$domain_name && \
  rm -Rf /etc/letsencrypt/archive/$domain_name && \
  rm -Rf /etc/letsencrypt/renewal/$domain_name.conf" certbot
echo


echo "### Requesting Let's Encrypt certificate for $domain_name ..."

# Select appropriate email arg
case "$email_address" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $email_address" ;;
esac

# Enable staging mode if needed
if [ $staging != "0" ]; then staging_arg="--staging"; fi

docker-compose run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot \
    $staging_arg \
    $email_arg \
    -d $domain_name \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --force-renewal" certbot
echo

echo "### Reloading nginx ..."
docker-compose exec nginx nginx -s reload

echo "### Starting all containers as daemons"
docker-compose up -d
echo "done"
