#!/bin/bash
set -e

echo "Running migrations..."
ruby db/migrate.rb

echo "Running reset..."
ruby db/reset.rb

echo "Running seeds..."
ruby db/seed/products.rb

echo "Starting server..."
exec bundle exec rackup -p ${PORT:-8080} -o 0.0.0.0
