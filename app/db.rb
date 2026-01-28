require "sequel"
require "dotenv/load"

Sequel.extension :migration

DB = Sequel.connect(ENV["DATABASE_URL"])

DB.extension :pg_json
DB.extension :pg_array
