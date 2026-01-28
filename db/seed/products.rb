require_relative "../../app/db"

DB[:products].insert(
  name: "Audífonos Bluetooth",
  description: "Audífonos inalámbricos con cancelación de ruido",
  price_cents: 150_000,
  stock: 10
)

DB[:products].insert(
  name: "Teclado Mecánico",
  description: "Teclado RGB switches azules",
  price_cents: 280_000,
  stock: 5
)

puts "✅ Productos creados"
