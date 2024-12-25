FROM postgres:latest

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get upgrade -y && apt-get clean
# Optional: Add custom configurations, extensions, or initialization scripts
