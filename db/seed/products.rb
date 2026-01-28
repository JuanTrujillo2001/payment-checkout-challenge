require_relative "../../app/db"

products = [
  {
    name: "Pulsar X2 Mini",
    description: "Mouse ultraligero 52g, sensor PAW3395, switches ópticos, ideal para claw grip",
    price_cents: 35_000_000,
    stock: 15
  },
  {
    name: "Pulsar X2",
    description: "Mouse ergonómico 56g, sensor PAW3395, polling rate 4000Hz, para palm grip",
    price_cents: 38_000_000,
    stock: 12
  },
  {
    name: "Pulsar X2H",
    description: "Versión high-hump del X2, mejor soporte para palm grip, 57g",
    price_cents: 38_000_000,
    stock: 8
  },
  {
    name: "Pulsar X2A",
    description: "Edición All Red limitada, sensor 8K, switches Kailh GM 8.0, 55g",
    price_cents: 42_000_000,
    stock: 5
  },
  {
    name: "Pulsar Xlite V3",
    description: "Mouse ultraligero 49g, diseño ergo asimétrico, sensor PAW3395",
    price_cents: 34_000_000,
    stock: 20
  },
  {
    name: "Pulsar Xlite V3 eS",
    description: "Versión eSports del Xlite V3, polling 8000Hz, 48g, competición pro",
    price_cents: 45_000_000,
    stock: 3
  },
  {
    name: "Pulsar X2 Ace",
    description: "Edición premium con coating especial, sensor mejorado, 54g",
    price_cents: 48_000_000,
    stock: 0
  },
  {
    name: "Pulsar Superglide Glass Skates",
    description: "Pads de vidrio para mouse, fricción ultra baja, compatible X2/Xlite",
    price_cents: 8_500_000,
    stock: 50
  },
  {
    name: "Pulsar Paracontrol V2 Mousepad",
    description: "Mousepad control 450x400mm, superficie de tela premium, base antideslizante",
    price_cents: 12_000_000,
    stock: 25
  },
  {
    name: "Pulsar ParaSpeed V2 Mousepad",
    description: "Mousepad speed 450x400mm, superficie rápida para tracking, 4mm grosor",
    price_cents: 13_000_000,
    stock: 18
  }
]

products.each do |product|
  DB[:products].insert(product)
end

puts "✅ #{products.length} productos creados"
