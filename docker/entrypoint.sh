#!/bin/bash


# # start nginx services
# nginx

# # start redis service
redis-server & 

# IMPORTANT: CLEAN LAST AS HEALTH CHECK CHECKS FOR PORT 5432
sudo su - postgres -c "pg_ctl start -D /var/lib/postgresql/data"

# Print a message to indicate services are running
echo "Services started. Opening Bash shell..."

# Keep the container alive with Bash
exec "$@"
