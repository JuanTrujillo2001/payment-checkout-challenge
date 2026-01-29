#!/bin/bash
set -e

echo "🔄 Running migrations..."
ruby db/migrate.rb

echo "🌱 Seeding database if empty..."
ruby -r ./app/db -e "
  if DB[:products].count == 0
    load 'db/seed/products.rb'
  else
    puts '✅ Products already exist, skipping seed'
  end
"

echo "🚀 Starting server on port ${PORT:-4567}..."
exec bundle exec rackup -p ${PORT:-4567} -o 0.0.0.0
