FROM redis:latest
RUN apt-get update && apt-get upgrade && apt-get clean

# Optional: Add custom configurations if needed