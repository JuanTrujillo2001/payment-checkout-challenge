require "sinatra"

# Configuration for production deployment (Railway, Heroku, etc.)
# Disable Rack::Protection::HostAuthorization which blocks external hosts
configure do
  disable :protection
end
