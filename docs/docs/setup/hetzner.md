# Setting Up Zest (Backend) on Hetzner Cloud

We will utilize the [Hetzner provider](https://www.hetzner.com) for affordable hosting of the backend (< 4 EUR per month).

## First Time Registration
1. [Register](https://accounts.hetzner.com/signUp) an account.
2. Activate 2FA.
3. Personal Details Verifcation
4. Create a `zest-backend` project

## Cloud Setup
Now we prepare the cloud vCPU server.

... Create the server, set up an SSH key and thats that.

First we update the system and create a non-root user
```bash
apt update -y && apt upgrade -y && apt autoremove -y
adduser zest
usermod -aG sudo zest # select a secure password, but we will disable this in a moment for SSH logins

apt install unattended-upgrades
dpkg-reconfigure unattended-upgrades
systemctl status unattended-upgrades
apt-get install git
```

Now, we configure the SSH
```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sudo nano /etc/ssh/sshd_config
```
and append the following
```
PasswordAuthentication no
PermitRootLogin no
ClientAliveInterval 300
ClientAliveCountMax 1
```

Validate that the config is correct and valid
```bash
sudo sshd -t
```

Now reboot to load new kernels etc..

Lets add some protection, by first adding a firewall

```bash
sudo ufw enable
sudo ufw allow OpenSSH
sudo ufw allow 22

```
 and fail2ban
```bash
sudo apt install fail2ban -y
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo nano /etc/fail2ban/jail.local
```
And now ensure that sshd is enabled

```
[sshd]
enabled = true
port    = ssh
```

Install nginx and add to firewall
```bash
sudo apt-get install nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# get cert
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d dbadrian.com 
sudo ufw allow 'Nginx Full'
```

Configure python
```bash
curl -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh"
bash Miniforge3-$(uname)-$(uname -m).sh -b

source ~/.bashrc
mamba create -n zest python=3.11
mamba activate zest
```

Prepare postgresql
```bash
sudo apt install postgresql postgresql-contrib
sudo -i -u postgres
```

```
psql

psql# ALTER USER postgres WITH PASSWORD 'TYPE STRONG PASSWORD HERE';
```

Last, we install redis
```bash
sudo apt install redis
```

And only allow local connections `nano /etc/redis/redis.conf`

```
# uncomment the following line
# bind 127.0.0.1 ::1
```
and restart redis
```
systemctl restart redis
```

## Setup zest
```bash
mkdir bin
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source　~/.bashrc
git clone https://github.com/dbadrian/zest.git zest-git
ln -s ~/zest-git/server/bin/* ~/bin/
deploy_zest # to trigger an initial deployment
```

For the first time and initial setup, we need to perform a few small updates to postgres and to the database.

First we install some extension, create the role we want to use, and the database we want to connect to in the future.


Add extensions to postgres
`sudo su - postgres` and `psql -d zest`

```
CREATE ROLE zest
LOGIN
PASSWORD 'GENERATE SECURE PASSWORD';
CREATE DATABASE zest
WITH
OWNER zest;
\c zest;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gin;
```

Next, we create an .env in the deployed zest, 

```bash
nano ~/zest/env.json
```

```json
{
    "DJANGO_SETTINGS_MODULE": "zest.settings.production",
    "DJANGO_SECRET_KEY": "$(python3 -c 'import secrets; print(secrets.token_urlsafe(100))')",
    "DJANGO_ALLOWED_HOSTS": "dbadrian.com",
    "DJANGO_AUTH_MODE": "jwt",
    "CORS_ALLOWED_ORIGINS": "https://0.0.0.0:8000,http://0.0.0.0:8000,https://dbadrian.com",
    "CSRF_TRUSTED_ORIGINS": "https://0.0.0.0:8000,http://0.0.0.0:8000,https://dbadrian.com",
    "SQL_ENGINE": "django.db.backends.postgresql",
    "SQL_HOST": "localhost",
    "SQL_PORT": "5432",
    "SQL_DATABASE": "zest",
    "SQL_USER": "zest",
    "SQL_PASSWORD": "SET POSTGRES PASSWORD FOR ROLE zest",
    "MEDIA_ROOT": "/var/www/html/zest/media",
    "STATIC_ROOT": "/var/www/html/zest/static",
    "REDIS_ADDRESS": "redis://127.0.0.1:6379"
}
```

Now we can make the migrations, migrate, and install the fixtures
```bash
./zest --env env.json manage makemigrations users shared units foods tags recipes shopping_lists favorites
./zest --env env.json manage migrate
./zest --env env.json manage loaddata users.json units.json foods.json foods_synonyms.json tags.json recipes.json recipe_categories.json shoppinglists.json

# create folder for statics and media
sudo mkdir -p /var/www/html/zest/media
sudo mkdir -p /var/www/html/zest/static
sudo chown -R zest:zest /var/www/html/zest/static /var/www/html/zest/media
sudo chmod -R 755 /var/www/html/zest/static /var/www/html/zest/media
./zest --env env.json manage collectstatic
```

Adjust the nginx config as follows
```
worker_processes 1;

user nobody nogroup;
# 'user nobody nobody;' for systems with 'nobody' as a group instead
error_log  /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
  worker_connections 1024; # increase if you have lots of clients
  accept_mutex off; # set to 'on' if nginx worker_processes > 1
  # 'use epoll;' to enable for Linux 2.6+
  # 'use kqueue;' to enable for FreeBSD, OSX
}

http {
  include mime.types;
  # fallback in case we can't determine a type
  default_type application/octet-stream;
  access_log /var/log/nginx/access.log combined;
  sendfile on;

  upstream app_server {
    # fail_timeout=0 means we always retry an upstream even if it failed
    # to return a good HTTP response

    # for UNIX domain socket setups
    server 127.0.0.1:8000 fail_timeout=0;

    # for a TCP configuration
    # server 192.168.0.7:8000 fail_timeout=0;
  }

  server {
    # if no Host match, close the connection to prevent host spoofing
    listen 80 default_server;
    return 444;
  }

  server {
    # use 'listen 80 deferred;' for Linux
    # use 'listen 80 accept_filter=httpready;' for FreeBSD
    listen 80;
    client_max_body_size 4G;

    # set the correct host(s) for your site
    server_name dbadrian.com www.dbadrian.com;

    keepalive_timeout 5;

    # path for static files
    root /var/www/html/zest/static;

    location / {
      # checks for static file, if not found proxy to app
      try_files $uri @proxy_to_app;
    }

    location @proxy_to_app {
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
      proxy_set_header Host $http_host;
      # we don't want nginx trying to do something clever with
      # redirects, we set the Host: header above already.
      proxy_redirect off;
      proxy_pass http://app_server;
    }

    error_page 500 502 503 504 /500.html;
    location = /500.html {
      root /path/to/app/current/public;
    }
  }
}
```

Reload nginx
```
sudo systemctl restart nginx
```

Test run the deployment
```
./zest --env env.json production
```

## Maintenance

First we setup a backup solution
```
touch ~/backup_logs

cd ~/bin
wget https://github.com/Backblaze/B2_Command_Line_Tool/releases/latest/download/b2-linux
chmod +x b2-linux
ln -s b2-linux b2
```

Now we authorize a bucket:
```
b2 account authorize <KEY_ID> <APPLICATION_KEY>
```

We add the `backup_logs` script to the crontab
```bash
crontab -e
```
and add
```
0 0 * * * /home/zest/bin/backup_zest_db > /home/zest/backup_logs 2>&1
```





Add to .bashrc for convenience
```
alias startbackend='tmux new-session -s "zest-live" -d "/home/zest/zest/zest --env /home/zest/zest/env.json production"'
```