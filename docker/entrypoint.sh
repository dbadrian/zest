#!/bin/bash


# start nginx services
sudo service nginx start

# start redis service
sudo service redis-server start

# IMPORTANT: CLEAN LAST AS HEALTH CHECK CHECKS FOR PORT 5432
# start postgres services
sudo service postgresql start

# Print a message to indicate services are running
echo "Services started. Opening Bash shell..."

# Keep the container alive with Bash
exec "$@"
