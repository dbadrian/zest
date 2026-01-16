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
sudo certbot --nginx -d yourdomain.com 
sudo ufw allow 'Nginx Full'
```

Install `uv` to manage python and venvs later on.
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh

# to refresh PATH
source ~/.bashrc

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
## Setup github token if your repo is private
```bash
cat > ~/.netrc<< EOF
machine github.com
login dbadrian
password <your_PAT_token>
EOF

chmod 600 ~/.netrc
```

## Setup zest
Create folder for bin files, if it does not yet exist.
```bash
mkdir -p bin
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
echo 'export ZEST_ENV="production"' >> ~/.bashrc
source　~/.bashrc
```

We now bootstrap the folder layout for zest and its releases.
- TODO: Explain layout
```
mkdir -p zest/upstream
git clone https://github.com/yourdomain/zest.git zest/upstream
ln -s ~/zest/upstream/server/bin/* ~/bin/
```

Next we prepare the environment files that will be shared across all the releases, and we symlink in
```
mkdir -p ~/zest/shared/logs
mkdir -p ~/zest/releases
cat > ~/zest/shared/env.production<< EOF
PROJECT_NAME="zest"
ENVIRONMENT=production

# Backend
SECRET_KEY=secret-test-key
FIRST_SUPERUSER=admin@test.com
FIRST_SUPERUSER_PASSWORD=changethis

# Emails
SMTP_HOST=
SMTP_USER=
SMTP_PASSWORD=
EMAILS_FROM_EMAIL=info@example.com
SMTP_TLS=True
SMTP_SSL=False
SMTP_PORT=587

# Postgres
POSTGRES_SERVER=localhost
POSTGRES_PORT=5432
POSTGRES_DB=zest
POSTGRES_USER=zest
POSTGRES_PASSWORD=changethis

MEILISEARCH_URL=http://meilisearch:7700
MEILISEARCH_MASTER_KEY=your-secure-master-key-here-min-16-chars

GEMINI_API_KEY=your-gemini-key-here

# Configure these with your own Docker registry images
DOCKER_IMAGE_BACKEND=backend
EOF
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
```
Then connect to the database
```
\c zest;
```

And install extensions if desired.
```
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gin;
```


Adjust the nginx config as follows
```nginx
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
    client_max_body_size 4G;

    # set the correct host(s) for your site
    server_name yourdomain.com www.yourdomain.com;

    keepalive_timeout 5;

    # path for static files
#    root /var/www/html/zest/static;

    location /static/ {
        alias /var/www/html/zest/static/;
    }

    location /media/ {
        alias /var/www/html/zest/media/;
    }

    location / {
      # check if backend is alive
      auth_request /api/v1/info; # should yield 2xx http status code

      error_page 500 =503 @status_offline;

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
  
    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

}


  server {
    if ($host = yourdomain.com) {
        return 301 https://$host$request_uri;
    } # managed by Certbot


    listen 80;
    server_name yourdomain.com www.yourdomain.com;
    return 404; # managed by Certbot
  }
}
```

```bash
sudo certbot --nginx -d yourdomain.com
```

!!! note

    If using cloudflare, make sure to use "full" mode for SSL.

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



zest@zest-backend:~/zest/upstream$ sudo cp /home/zest/zest/upstream/server/zest.service /etc/systemd/system/
zest@zest-backend:~/zest/upstream$ sudo systemctl daemon-reload
zest@zest-backend:~/zest/upstream$ sudo systemctl restart zest.serviceS