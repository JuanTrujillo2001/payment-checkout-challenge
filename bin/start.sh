#!/bin/bash
set -e

echo "Running migrations..."
ruby db/migrate.rb

echo "Checking stock levels..."

ACTION=$(ruby -r ./app/db -e "
count = DB[:products].count

if count == 0
  puts 'RESET'
elsif DB[:products].where { stock > 0 }.count == 0
  puts 'RESET'
else
  puts 'KEEP'
end
")

if [ \"$ACTION\" = \"RESET\" ]; then
  echo \"Resetting inventory...\"
  ruby db/reset.rb
  ruby db/seed/products.rb
else
  echo \"Keeping existing inventory\"
fi

echo \"Starting server...\"
exec bundle exec rackup -p \${PORT:-8080} -o 0.0.0.0
