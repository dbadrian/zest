#!/bin/bash
# start redis service
sudo service redis-server start &

# start postgres services
sudo service postgresql start &

# start nginx services
sudo service nginx start &

# Wait for a bit to ensure services have started
sleep 2

# Print a message to indicate services are running
echo "Services started. Opening Bash shell..."

# Keep the container alive with Bash
exec "$@"
