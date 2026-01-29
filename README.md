# Wompi Payment Gateway - Backend API

API REST para procesamiento de pagos con integración a Wompi, construida con Ruby y Sinatra siguiendo arquitectura hexagonal (Ports & Adapters).

## 🏗️ Arquitectura

El proyecto implementa **Arquitectura Hexagonal** (también conocida como Ports & Adapters) que separa la lógica de negocio de los detalles de infraestructura.

```
app/
├── adapters/           # Implementaciones concretas (Sequel, Wompi API)
├── controllers/        # Endpoints HTTP (Sinatra)
├── domain/
│   └── entities/       # Modelos de dominio (Sequel::Model)
├── ports/              # Interfaces/contratos abstractos
└── use_cases/          # Lógica de negocio (casos de uso)
```

### Capas

| Capa | Descripción | Ejemplos |
|------|-------------|----------|
| **Domain** | Entidades del negocio | `Product`, `Transaction`, `Customer` |
| **Ports** | Interfaces abstractas (contratos) | `PaymentGateway`, `ProductRepository` |
| **Adapters** | Implementaciones concretas | `WompiPaymentGateway`, `SequelProductRepository` |
| **Use Cases** | Orquestación de lógica de negocio | `ProcessPayment`, `CreateTransactionFromCart` |
| **Controllers** | Endpoints HTTP | `transactions_controller.rb` |

### Flujo de una Transacción

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐     ┌─────────────┐
│  Controller │ ──▶│   Use Case   │ ──▶ │    Port     │ ──▶│   Adapter   │
│  (HTTP)     │     │  (Business)  │     │ (Interface) │     │  (Impl)     │
└─────────────┘     └──────────────┘     └─────────────┘     └─────────────┘
```

## 🛠️ Stack Tecnológico

- **Ruby** 3.2.2
- **Sinatra** - Framework web minimalista
- **Sequel** - ORM para PostgreSQL
- **PostgreSQL** 15 - Base de datos
- **dry-monads** - Railway Oriented Programming (ROP)
- **HTTParty** - Cliente HTTP para Wompi API
- **RSpec** - Testing
- **Docker** - Contenedor para PostgreSQL

## 📁 Estructura del Proyecto

```
wompi-challenge-backend/
├── app/
│   ├── adapters/
│   │   ├── sequel_cart_repository.rb
│   │   ├── sequel_customer_repository.rb
│   │   ├── sequel_delivery_repository.rb
│   │   ├── sequel_product_repository.rb
│   │   ├── sequel_transaction_repository.rb
│   │   └── wompi_payment_gateway.rb
│   ├── controllers/
│   │   ├── cart_controller.rb
│   │   ├── products_controller.rb
│   │   └── transactions_controller.rb
│   ├── domain/
│   │   └── entities/
│   │       ├── cart_item.rb
│   │       ├── customer.rb
│   │       ├── delivery.rb
│   │       ├── product.rb
│   │       ├── transaction.rb
│   │       └── transaction_item.rb
│   ├── ports/
│   │   ├── cart_repository.rb
│   │   ├── customer_repository.rb
│   │   ├── delivery_repository.rb
│   │   ├── payment_gateway.rb
│   │   ├── product_repository.rb
│   │   └── transaction_repository.rb
│   ├── use_cases/
│   │   ├── create_transaction.rb
│   │   ├── create_transaction_from_cart.rb
│   │   ├── fulfill_transaction.rb
│   │   └── process_payment.rb
│   └── db.rb
├── db/
│   ├── migrations/
│   ├── seed/
│   ├── migrate.rb
│   └── reset.rb
├── spec/
├── config.ru
├── docker-compose.yml
├── Gemfile
└── .env
```

## 🚀 Instalación

### Prerrequisitos

- Ruby 3.2.2 (recomendado usar `rbenv` o `mise`)
- Docker y Docker Compose
- Bundler

### Pasos

1. **Clonar el repositorio**
   ```bash
   git clone <repo-url>
   cd wompi-challenge-backend
   ```

2. **Instalar dependencias**
   ```bash
   bundle install
   ```

3. **Iniciar PostgreSQL con Docker**
   ```bash
   docker-compose up -d
   ```

4. **Configurar variables de entorno**
   ```bash
   cp .env.example .env
   # Editar .env con tus credenciales de Wompi
   ```

   Variables requeridas:
   ```env
   DATABASE_URL=postgres://postgres:postgres@localhost:5432/wompi_challenge_dev
   WOMPI_PUBLIC_KEY=pub_stagtest_xxxxx
   WOMPI_PRIVATE_KEY=prv_stagtest_xxxxx
   WOMPI_API_URL=https://api-sandbox.co.uat.wompi.dev/v1
   ```

5. **Crear base de datos y ejecutar migraciones**
   ```bash
   docker exec backend_postgres psql -U postgres -c "CREATE DATABASE wompi_challenge_dev;"
   bundle exec sequel -m db/migrations $DATABASE_URL
   ```

6. **Cargar datos de prueba (seed)**
   ```bash
   bundle exec ruby db/seed/products.rb
   ```

7. **Iniciar el servidor**
   ```bash
   bundle exec rackup -p 4567
   ```

   El servidor estará disponible en `http://localhost:4567`

## 📡 API Endpoints

### Productos

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `GET` | `/products` | Listar todos los productos |

**Response:**
```json
[
  {
    "id": "uuid",
    "name": "Pulsar X2 Mini",
    "description": "Mouse ultraligero 52g...",
    "price_cents": 35000000,
    "stock": 15
  }
]
```

### Carrito

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `GET` | `/cart/:session_id` | Obtener carrito por sesión |
| `POST` | `/cart/:session_id/items` | Agregar item al carrito |
| `PUT` | `/cart/:session_id/items/:product_id` | Actualizar cantidad |
| `DELETE` | `/cart/:session_id/items/:product_id` | Eliminar item |
| `DELETE` | `/cart/:session_id` | Vaciar carrito |

**POST /cart/:session_id/items:**
```json
{
  "product_id": "uuid",
  "quantity": 2
}
```

### Transacciones

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `POST` | `/transactions/from-cart` | Crear transacción desde carrito |
| `POST` | `/transactions/:id/pay` | Procesar pago con Wompi |
| `GET` | `/transactions/:id/status` | Consultar estado de transacción |
| `GET` | `/transactions/reference/:reference` | Buscar por referencia |

**POST /transactions/from-cart:**
```json
{
  "session_id": "uuid",
  "customer": {
    "full_name": "Juan Pérez",
    "identity_document": "1234567890",
    "email": "juan@example.com",
    "phone": "3001234567"
  },
  "delivery": {
    "address": "Calle 123 #45-67",
    "city": "Bogotá",
    "country": "Colombia"
  }
}
```

**POST /transactions/:id/pay:**
```json
{
  "card": {
    "number": "4242424242424242",
    "exp_month": "12",
    "exp_year": "2026",
    "cvc": "123",
    "card_holder": "JUAN PEREZ"
  },
  "installments": 1
}
```

## 💳 Flujo de Pago

```
1. Usuario agrega productos al carrito
   └── POST /cart/:session_id/items

2. Usuario inicia checkout
   └── POST /transactions/from-cart
       └── Crea transacción en estado PENDING
       └── Guarda session_id para fulfillment posterior
       └── NO descuenta stock aún

3. Usuario ingresa datos de tarjeta
   └── POST /transactions/:id/pay
       └── Tokeniza tarjeta con Wompi
       └── Crea payment source
       └── Crea transacción en Wompi
       └── Si APPROVED: ejecuta fulfillment
           └── Descuenta stock
           └── Limpia carrito
           └── Marca fulfilled_at

4. Si queda PENDING, frontend hace polling
   └── GET /transactions/:id/status
       └── Consulta estado en Wompi
       └── Si cambió a APPROVED: ejecuta fulfillment
```

## 🧪 Tarjetas de Prueba (Sandbox)

| Número | Resultado |
|--------|-----------|
| `4242 4242 4242 4242` | ✅ APPROVED (Visa) |
| `4111 1111 1111 1111` | ✅ APPROVED (Visa) |
| `4012 8888 8888 1881` | ❌ DECLINED (Visa) |

- **CVC:** Cualquier 3 dígitos (ej: `123`)
- **Fecha:** Cualquier fecha futura (ej: `12/26`)

## 🔧 Use Cases

### CreateTransactionFromCart

Crea una transacción a partir del carrito del usuario.

- Valida que el carrito no esté vacío
- Valida stock disponible para todos los items
- Crea customer y delivery
- Crea transacción en estado `PENDING`
- **NO** descuenta stock ni limpia carrito (se hace en fulfillment)

### ProcessPayment

Procesa el pago con Wompi.

1. Obtiene acceptance token de Wompi
2. Tokeniza la tarjeta
3. Crea payment source
4. Crea transacción en Wompi
5. Actualiza estado de la transacción local
6. Si `APPROVED`: ejecuta `FulfillTransaction`

### FulfillTransaction

Ejecuta las acciones post-pago cuando la transacción es aprobada.

- Valida que no esté ya fulfilled
- Valida que el estado sea `APPROVED`
- Descuenta stock de todos los productos
- Limpia el carrito del usuario
- Marca `fulfilled_at` en la transacción

## 🗃️ Base de Datos

### Esquema

```
┌─────────────────┐     ┌─────────────────┐
│    products     │     │   customers     │
├─────────────────┤     ├─────────────────┤
│ id (UUID)       │     │ id (UUID)       │
│ name            │     │ full_name       │
│ description     │     │ identity_doc    │
│ price_cents     │     │ email           │
│ stock           │     │ phone           │
└─────────────────┘     └─────────────────┘
         │                      │
         │                      │
         ▼                      ▼
┌─────────────────┐     ┌─────────────────┐
│  transactions   │◀────│   deliveries    │
├─────────────────┤     ├─────────────────┤
│ id (UUID)       │     │ id (UUID)       │
│ reference       │     │ customer_id     │
│ status          │     │ address         │
│ amount_cents    │     │ city            │
│ base_fee_cents  │     │ country         │
│ delivery_fee    │     └─────────────────┘
│ wompi_tx_id     │
│ customer_id     │
│ delivery_id     │
│ session_id      │
│ fulfilled_at    │
└─────────────────┘
         │
         ▼
┌─────────────────┐     ┌─────────────────┐
│transaction_items│     │   cart_items    │
├─────────────────┤     ├─────────────────┤
│ id (UUID)       │     │ id (UUID)       │
│ transaction_id  │     │ session_id      │
│ product_id      │     │ product_id      │
│ quantity        │     │ quantity        │
│ price_cents     │     └─────────────────┘
│ subtotal_cents  │
└─────────────────┘
```

### Migraciones

```bash
# Ejecutar migraciones
bundle exec sequel -m db/migrations $DATABASE_URL

# Reset completo (drop + create + migrate + seed)
bundle exec ruby db/reset.rb
```

## 🧪 Testing

El proyecto usa **RSpec** para tests y **WebMock** para mockear las llamadas HTTP a la API de Wompi (evitando requests reales al sandbox durante los tests).

### Herramientas de Testing

| Gema | Propósito |
|------|-----------|
| `rspec` | Framework de testing |
| `rack-test` | Testing de endpoints HTTP |
| `webmock` | Mock de requests HTTP externos (Wompi API) |
| `simplecov` | Cobertura de código (mínimo 90%) |

### WebMock

WebMock intercepta las llamadas HTTP y permite simular respuestas de Wompi sin hacer requests reales:

```ruby
# Ejemplo de stub en los tests
stub_request(:post, "#{ENV['WOMPI_API_URL']}/tokens/cards")
  .to_return(
    status: 200,
    body: { data: { id: "tok_test_123" } }.to_json,
    headers: { 'Content-Type' => 'application/json' }
  )
```

Esto permite:
- Tests rápidos (sin latencia de red)
- Tests determinísticos (respuestas predecibles)
- Tests sin depender del sandbox de Wompi
- Simular escenarios de error fácilmente

### Resultado Actual

```
146 examples, 0 failures
Line Coverage: 88.11%
```

### Suites de Tests

| Suite | Tests | Descripción |
|-------|-------|-------------|
| `adapters/sequel_cart_repository_spec.rb` | 10 | Repositorio de carrito |
| `adapters/sequel_customer_repository_spec.rb` | 4 | Repositorio de clientes |
| `adapters/sequel_delivery_repository_spec.rb` | 5 | Repositorio de entregas |
| `adapters/sequel_product_repository_spec.rb` | 4 | Repositorio de productos |
| `adapters/sequel_transaction_repository_spec.rb` | 14 | Repositorio de transacciones |
| `adapters/wompi_payment_gateway_spec.rb` | 12 | Gateway de pagos Wompi |
| `controllers/cart_controller_spec.rb` | 14 | Endpoints de carrito |
| `controllers/products_controller_spec.rb` | 5 | Endpoints de productos |
| `controllers/transactions_controller_spec.rb` | 27 | Endpoints de transacciones |
| `use_cases/create_transaction_spec.rb` | 12 | Crear transacción (legacy) |
| `use_cases/create_transaction_from_cart_spec.rb` | 9 | Crear transacción desde carrito |
| `use_cases/fulfill_transaction_spec.rb` | 10 | Fulfillment post-pago |
| `use_cases/process_payment_spec.rb` | 20 | Procesamiento de pagos |

### Comandos

```bash
# Ejecutar todos los tests
bundle exec rspec

# Con formato detallado
bundle exec rspec --format documentation

# Tests específicos
bundle exec rspec spec/use_cases/process_payment_spec.rb

# Ver reporte de cobertura (genera en coverage/index.html)
bundle exec rspec && open coverage/index.html
```

## 📝 Railway Oriented Programming (ROP)

El proyecto usa `dry-monads` para manejar flujos de éxito/error de forma funcional:

```ruby
def call(params)
  transaction = yield find_transaction(params[:id])
  yield validate_status(transaction)
  yield process_payment(transaction)
  
  Success(transaction)
end

private

def find_transaction(id)
  transaction = repo.find(id)
  return Failure(error: :not_found) unless transaction
  Success(transaction)
end
```

Beneficios:
- Código más legible y declarativo
- Manejo explícito de errores
- Fácil composición de operaciones
- Sin excepciones para control de flujo

## 🌐 CORS

La configuración de CORS usa la variable de entorno `ALLOWED_ORIGINS`:

```ruby
# config.ru
origins ENV.fetch('ALLOWED_ORIGINS', '*').split(',').map(&:strip)
```

### Configuración por entorno

| Entorno | ALLOWED_ORIGINS |
|---------|-----------------|
| **Desarrollo** | `*` o `http://localhost:5173` |
| **Producción (CloudFront)** | `https://d1234abcd.cloudfront.net` |
| **Múltiples orígenes** | `https://dominio1.com,https://dominio2.com` |

### Ejemplo .env

```env
# Desarrollo
ALLOWED_ORIGINS=http://localhost:5173

# Producción con CloudFront
ALLOWED_ORIGINS=https://d1234abcd.cloudfront.net,https://tu-dominio.com
```

## 🔒 Seguridad y Buenas Prácticas

El backend cumple con las siguientes prácticas de seguridad recomendadas por OWASP:

- ✅ **HTTPS**: Railway sirve la API con HTTPS, asegurando que toda comunicación esté cifrada.
- ✅ **CORS restringido**: solo permite requests desde orígenes autorizados (frontend en CloudFront).
- ✅ **Cabeceras de seguridad (Security Headers)**: CloudFront y Sinatra permiten agregar cabeceras como:
  - `Content-Security-Policy` → Previene inyección de scripts.
  - `X-Content-Type-Options: nosniff` → Evita que el navegador interprete mal archivos.
  - `Strict-Transport-Security` → Fuerza uso de HTTPS.
- ✅ **Validación de datos** en todos los endpoints para evitar inyecciones y entradas maliciosas.
- ✅ **Tokenización de tarjetas**: No se almacenan datos sensibles de tarjetas, todo se maneja mediante tokens de Wompi.
- ✅ **Principios OWASP** aplicados en toda la arquitectura: separación de capas, manejo seguro de errores y control de accesos.

## 🚀 Despliegue

- **Backend**: [Railway](https://railway.app)
- **Frontend**: S3 + CloudFront

---
