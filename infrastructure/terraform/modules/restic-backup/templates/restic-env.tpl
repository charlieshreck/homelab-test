#!/bin/bash
# Restic environment configuration
# Sourced by backup scripts and systemd units

export RESTIC_REPOSITORY="${repository}"
export RESTIC_PASSWORD="${password}"

# AWS/MinIO credentials for S3 backend
export AWS_ACCESS_KEY_ID="${aws_access_key}"
export AWS_SECRET_ACCESS_KEY="${aws_secret_key}"

# Restic options
export RESTIC_PROGRESS=true
export RESTIC_VERBOSE=1
