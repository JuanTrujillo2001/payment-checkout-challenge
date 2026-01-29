require "dotenv/load"
require "sequel"

DB = Sequel.connect(ENV["DATABASE_URL"])

puts "🗑️  Limpiando tablas..."

# Orden correcto por dependencias (foreign keys)
tables_to_clean = [
  :transaction_items,
  :cart_items,
  :transactions,
  :deliveries,
  :customers,
  :products
]

tables_to_clean.each do |table|
  if DB.table_exists?(table)
    count = DB[table].count
    DB[table].delete
    puts "   ✓ #{table}: #{count} registros eliminados"
  else
    puts "   ⚠ #{table}: tabla no existe"
  end
end

puts "\n📊 Verificando estructura de tablas..."

DB.tables.each do |table|
  next if table == :schema_migrations
  
  puts "\n#{table}:"
  DB.schema(table).each do |col|
    name, info = col
    type = info[:db_type]
    nullable = info[:allow_null] ? "NULL" : "NOT NULL"
    puts "   - #{name}: #{type} #{nullable}"
  end
end

puts "\n Base de datos limpia"
