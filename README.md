# Good Plate · Restaurant ordering demo

A responsive restaurant-ordering demo. The Android and iOS experience uses Flutter. The web view is a standalone HTML, CSS and JavaScript app. Customers can browse a sample menu, adjust quantities, and submit an order with a kitchen note; staff can manage menu items and review/update the saved order queue.

This project has no restaurant backend, customer accounts, or payment processing. The clearly labeled sample menu, menu changes, and demo orders are stored locally on the device with Hive in Flutter and browser local storage on the web. They are not sent to a live restaurant or synchronized between devices.

### Web view

Open `web/index.html` through a static web server (for example `flutter run -d chrome` or `python -m http.server --directory web 8000` from the repository root). The web implementation is dependency-free and uses browser local storage for its demo menu and orders.

## Screenshot


https://github.com/user-attachments/assets/f2d16454-5408-43b3-b207-cd843bbc2c9e



## Project scope

The app demonstrates a complete local ordering loop for phone and desktop widths.

### Core features:
- **Customer menu**: Browse and search dishes by section, inspect descriptions and prices, and add any quantity to an order.
- **Order details**: Record a customer name and optional kitchen requirements; review an itemized total before saving.
- **Kitchen queue**: Review incoming orders, item quantities, customer notes and status; update order status.
- **Menu management**: Create, edit, delete, price and availability updates for menu items.
- **Local demo flow**: Seed clearly identified sample dishes on first launch; menu changes and orders persist on the device.
- **Existing POS utilities**: Barcode scanning, shop settings and Bluetooth thermal printing remain available.
- **Bluetooth Thermal Printing**: Direct integration with thermal printers (`print_bluetooth_thermal`) to instantly output physical receipts.
- **Shop Settings & Customization**: Centrally managed shop details printed dynamically on receipts.

## 🛠 Tech Stack & Architecture

Built leveraging industry-standard architectural principles (Clean Architecture & Feature-Driven Design) ensuring scalability, separation of concerns, and robust testability. 

- **Framework**: [Flutter](https://flutter.dev/) (SDK >=3.1.0)
- **State Management**: `flutter_bloc`
- **Dependency Injection**: `get_it`
- **Routing**: `go_router`
- **Local Database**: `hive` & `hive_flutter`
- **Data Modeling**: `json_serializable`, `equatable`
- **Functional Programming**: `fpdart`
- **Hardware Integrations**: `mobile_scanner` (barcodes), `print_bluetooth_thermal`

## 📁 File Structure

The codebase is organized using a **Feature-First Clean Architecture** utilizing domain-driven concepts.

```text
lib/
├── core/                       # Core application utilities and shared components
│   ├── data/                   # Global data sources (e.g., Hive initialization)
│   ├── error/                  # Standardized Failure/Exception models (fpdart compatible)
│   ├── theme/                  # UI aesthetics, typography, styling
│   ├── usecase/                # Base UseCase contracts
│   ├── utils/                  # Helpers (e.g., PrinterHelper, formatters)
│   ├── widgets/                # Reusable global UI widgets (AppBars, generic buttons)
│   └── service_locator.dart    # get_it dependency injection setup
│
└── features/                   # Independent feature modules
    ├── billing/                # Core POS operations: Cart, Checkout, Invoice Generation
    ├── product/                # Inventory management: Adding, Listing, Scanning products
    ├── orders/                 # Restaurant menu ordering and local kitchen queue
    ├── settings/               # App configuration: Printer connections, App settings
    └── shop/                   # Shop details configuration
```

*Note: Each feature is further subdivided internally into Clean Architecture layers: `data`, `domain`, and `presentation`.*

## 💡 Use Cases

- **Customer order**: A customer selects menu items and quantities, adds a name and optional kitchen note, and saves a demo order locally.
- **Kitchen review**: Staff opens Kitchen from the order board to review tickets and change their status. This demo does not synchronize with another device.

- **Rapid Billing Entry**: A cashier launches the app, navigates to the checkout page, and uses the device camera to instantly scan product barcodes. The products are added to the cart, the total is calculated including taxes, and a receipt is finalized.
- **Physical Receipt Generation**: After checkout confirmation, the app triggers a connected external Bluetooth thermal POS printer to instantly print an itemized paper receipt with the shop’s header.
- **Inventory Sideloading**: A manager opens the Product feature to add new stock to the local database, taking a picture of the barcode to bind the SKU for future lightning-fast checkouts.
- **No-Connection Operation**: The business operates a stall at an exhibition with poor networking. The app functions entirely via its embedded Hive local database and Bluetooth, completely undisturbed by network drops.

## 🚀 Getting Started

### Prerequisites
- Flutter SDK `^3.1.0` or higher
- Android Studio / Xcode for emulators and building.
- *Optional*: A physical Android/iOS device and a Bluetooth Thermal Printer for testing hardware integrations natively.

### Installation

1. Clone the repository and navigate to the project directory:
   ```bash
   git clone <repository_url>
   cd billing_app
   ```

2. Fetch dependencies:
   ```bash
   flutter pub get
   ```

3. Run code generation (required for Hive adapters and JSON serialization):
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. Run the project:
   ```bash
   flutter run
   ```

## 🤝 Contributing Guidelines
As a senior-focused project, please adhere to:
1. **Clean Architecture Rules**: Maintain strict boundaries between `domain`, `data`, and `presentation` layers.
2. **Immutable States**: Emit only immutable states from BLoCs utilizing `equatable`.
3. **No Direct Exceptions in Domain**: Utilize `fpdart`'s `Either<Failure, Type>` pattern to handle control flow for exceptions.
