#!/bin/bash
set -e

echo "Running migrations..."
ruby db/migrate.rb

echo "Running seeds..."
ruby db/seed.rb

echo "Starting server..."
exec bundle exec rackup -p ${PORT:-4567} -o 0.0.0.0
