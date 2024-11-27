# AWS Setup

This project runs easily on the free-tier hardware. Let's set it up.



i) download pem
ii) set `chmod 400`
iii) ubuntu@PUBLIC_DNS_SHIT

## SSH
```bash
ssh -i ~/workspace/zest_aws.pem ubuntu@YOUR-INSTANCE.compute.amazonaws.com
```

## bin

```
cat <<EOF >>~/.bashrc
PATH=\$PATH:~/bin
EOF
```


## Preparing the instance

```bash
sudo apt update
sudo apt upgrade

sudo apt install nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# get cert
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d dbadrian.com 
```

### Github Access
Generate a fine-grained access token on github.


### Setup of Python
```bash
curl -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh"
bash Miniforge3-$(uname)-$(uname -m).sh

source ~/.bashrc
mamba create -n zest python=3.11
mamba activate zest
```

### Setup Postgress
```bash
sudo apt install postgresql postgresql-contrib
sudo -i -u postgres
```

```
sudo -u postgres psql
createuser --interactive
```

```
{
    "DJANGO_SETTINGS_MODULE": "zest.settings.production",
    "DJANGO_SECRET_KEY": "YOUR_SECRET_KEY,
    "DJANGO_ALLOWED_HOSTS": "dbadrian.com",
    "DJANGO_AUTH_MODE": "jwt",
    "CORS_ALLOWED_ORIGINS": "https://0.0.0.0:8000,http://0.0.0.0:8000,https://dbadrian.com",
    "CSRF_TRUSTED_ORIGINS": "https://0.0.0.0:8000,http://0.0.0.0:8000,https://dbadrian.com",
    "SQL_ENGINE": "django.db.backends.postgresql",
    "SQL_HOST": "localhost",
    "SQL_PORT": "5432",
    "SQL_DATABASE": "postgres",
    "SQL_USER": "postgres",\\)pwf0h8pz@rtpu(ub^((c4hm(0oo+3ppoah#lzx_b-zambn+#m"
    "SQL_PASSWORD": "postgres",
    "MEDIA_ROOT": "/var/www/html/zest/media",
    "STATIC_ROOT": "/var/www/html/zest/static",
    "REDIS_ADDRESS": "redis://127.0.0.1:6379"
}
```

Create `~/.pgpass` 
```
localhost:5432:postgres:postgres:postgres
```
and `chmod 600 ~/.pgpass`.

```
sudo nano /etc/postgresql/14/main/pg_hba.conf 
```

### Dunno Dunoo

### Utility Scripts and Automatic Backups
```bash
# copy server utility scripts
cp ~/zest-git/server/bin ~/
```


### Clear Text Dump of Django Models
```bash
cd ~/zest/
DATE=$(date +%Y-%m-%d)

./zest --env env.json manage dumpdata tags > tags.json
./zest --env env.json manage dumpdata --indent 2 users > ${DATE}_users.json
./zest --env env.json manage dumpdata --indent 2 favorites > ${DATE}_favorites.json
./zest --env env.json manage dumpdata --indent 2 recipes > ${DATE}_recipes.json
./zest --env env.json manage dumpdata --indent 2 shopping_lists > ${DATE}_shopping_lists.json
./zest --env env.json manage dumpdata --indent 2 units > ${DATE}_units.json
./zest --env env.json manage dumpdata --indent 2 tags > ${DATE}_tags.json
./zest --env env.json manage dumpdata --indent 2 foods > ${DATE}_food.json
```

### Backups

Install b2 cli
```
cd ~/bin
wget https://github.com/Backblaze/B2_Command_Line_Tool/releases/latest/download/b2-linux
chmod +x b2-linux
ln -s b2-linux b2
```

Now we authorize a bucket:
```
b2 account authorize <KEY_ID> <APPLICATION_KEY>
```

### Install cronjobs
```bash
crontab -e
```
and add
```
0 0 * * * /home/ubuntu/bin/backup_zest_db > /home/ubuntu/backup_logs 2>&1
```