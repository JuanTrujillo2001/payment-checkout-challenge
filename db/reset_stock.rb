require_relative "../app/db"

stock_values = {
  "Pulsar X2 Mini" => 15,
  "Pulsar X2" => 12,
  "Pulsar X2H" => 8,
  "Pulsar X2A" => 5,
  "Pulsar Xlite V3" => 20,
  "Pulsar Xlite V3 eS" => 3,
  "Pulsar X2 Ace" => 0,
  "Pulsar Superglide Glass Skates" => 50,
  "Pulsar Paracontrol V2 Mousepad" => 25,
  "Pulsar ParaSpeed V2 Mousepad" => 18
}

stock_values.each do |name, stock|
  DB[:products].where(name: name).update(stock: stock)
end

puts "Stock reseteado para #{stock_values.length} productos"
