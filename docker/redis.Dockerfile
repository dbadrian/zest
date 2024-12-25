FROM redis:latest
RUN apt-get update && apt-get upgrade -y && apt-get clean

# Optional: Add custom configurations if needed