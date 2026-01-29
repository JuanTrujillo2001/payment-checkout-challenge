require "sequel"
require_relative "../app/db"

Sequel.extension :migration

version = ARGV[0]&.to_i

if version
  Sequel::Migrator.run(DB, "db/migrations", target: version)
else
  Sequel::Migrator.run(DB, "db/migrations")
end

puts "Migraciones actualizadas"
