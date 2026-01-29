require_relative "../../app/db"

products = [
  {
    name: "Pulsar X2 Mini",
    description: "Mouse ultraligero 52g, sensor PAW3395, switches ópticos, ideal para claw grip",
    price_cents: 35_000_000,
    stock: 15,
    image_url: "https://www.pulsar.gg/cdn/shop/files/X2_v1_Gaming_Mouse_Mini_black_large.png?v=1758619300"
  },
  {
    name: "Pulsar X2",
    description: "Mouse ergonómico 56g, sensor PAW3395, polling rate 4000Hz, para palm grip",
    price_cents: 38_000_000,
    stock: 12,
    image_url: "https://www.pulsar.gg/cdn/shop/files/Pulsar-X2-CL-jetblack_Gaming-Mouse_001_abd7a0cb-9165-4721-ba66-c1481a711c4f_large.png?v=1758610433"
  },
  {
    name: "Pulsar X2H",
    description: "Versión high-hump del X2, mejor soporte para palm grip, 57g",
    price_cents: 38_000_000,
    stock: 8,
    image_url: "https://www.pulsar.gg/cdn/shop/files/X2H_gaming_mouse_medium_Black_large.png?v=1758619066"
  },
  {
    name: "Pulsar X2A",
    description: "Edición All Red limitada, sensor 8K, switches Kailh GM 8.0, 55g",
    price_cents: 42_000_000,
    stock: 5,
    image_url: "https://www.pulsar.gg/cdn/shop/products/X2AgamingMouse_top-234273_large.png?v=1718795946"
  },
  {
    name: "Pulsar Xlite V3",
    description: "Mouse ultraligero 49g, diseño ergo asimétrico, sensor PAW3395",
    price_cents: 34_000_000,
    stock: 20,
    image_url: "https://www.pulsar.gg/cdn/shop/products/PulsarXliteV3LargeGamingMouse_Black_001-123342_large.png?v=1718796134"
  },
  {
    name: "Pulsar Xlite V3 eS",
    description: "Versión eSports del Xlite V3, polling 8000Hz, 48g, competición pro",
    price_cents: 45_000_000,
    stock: 3,
    image_url: "https://www.pulsar.gg/cdn/shop/products/PulsarXliteV3eSGamingMouse_Black_001-104249_large.png?v=1718795973"
  },
  {
    name: "Pulsar X2 Ace",
    description: "Edición premium con coating especial, sensor mejorado, 54g",
    price_cents: 48_000_000,
    stock: 0,
    image_url: "https://www.pulsar.gg/cdn/shop/files/Pulsar-X2-CL-jetblack_Gaming-Mouse_001_abd7a0cb-9165-4721-ba66-c1481a711c4f_large.png?v=1758610433"
  },
  {
    name: "Pulsar Superglide Glass Skates",
    description: "Pads de vidrio para mouse, fricción ultra baja, compatible X2/Xlite",
    price_cents: 8_500_000,
    stock: 50,
    image_url: "https://www.pulsar.gg/cdn/shop/files/Superglide2-Type-C-Glass_X3_Thumbnail_03-W_large.png?v=1735190283"
  },
  {
    name: "Pulsar Paracontrol V2 Mousepad",
    description: "Mousepad control 450x400mm, superficie de tela premium, base antideslizante",
    price_cents: 12_000_000,
    stock: 25,
    image_url: "https://www.pulsar.gg/cdn/shop/products/PulsarGamingGearsParacontrolgamingmousepad_XL_12a63018-2c20-49cd-b80b-e2654649616e-836426_large.png?v=1718795763"
  },
  {
    name: "Pulsar ParaSpeed V2 Mousepad",
    description: "Mousepad speed 450x400mm, superficie rápida para tracking, 4mm grosor",
    price_cents: 13_000_000,
    stock: 18,
    image_url: "https://www.pulsar.gg/cdn/shop/products/PulsarGamingGearsParaspeedgamingmousepad_XXL_e07c034b-3923-4f24-b9c5-59e2de52371f-840606_large.png?v=1718795155"
  }
]

products.each do |product|
  DB[:products].insert(product)
end

puts "#{products.length} productos creados"
