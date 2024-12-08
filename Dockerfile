FROM golang:1.22.5-alpine AS builder

# Install required system packages and update certificates
RUN apk update && \
    apk upgrade && \
    apk add --no-cache ca-certificates git && \
    update-ca-certificates

# Add Maintainer Info
LABEL maintainer="Your Name <your.email@example.com>"
LABEL description="VPN Client with iptables support"

# Set the Current Working Directory inside the container
WORKDIR /build

# Copy files
COPY . .

# Download all dependencies
RUN go mod download

# Build the Go app
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o go-vpn .

# Start a new stage from scratch
FROM alpine:3.15

# Install required system packages
RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
    ca-certificates \
    iptables \
    ip6tables \
    iproute2 \
    bash \
    curl \
    && update-ca-certificates

WORKDIR /app

# Copy the Pre-built binary file from the previous stage
COPY --from=builder /build/go-vpn /app/go-vpn
COPY entrypoint.sh /app/entrypoint.sh

# Make scripts executable
RUN chmod +x /app/go-vpn /app/entrypoint.sh

# Environment variables with defaults
ENV SERVER_IP=""
ENV SERVER_PORT="47401"
ENV CLIENT_CIDR=""
ENV SHARED_KEY=""
# INTERFACE will be auto-detected in entrypoint script
ENV INTERFACE=""

# Entrypoint script
ENTRYPOINT ["/app/entrypoint.sh"]
