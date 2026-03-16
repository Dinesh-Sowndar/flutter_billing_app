# 🛒 Mobile POS & Billing App 

A feature-rich, high-performance offline-first billing and Point of Sale (POS) application built with Flutter. Designed for seamless retail checkout operations featuring barcode scanning, thermal Bluetooth printing, and robust local data persistence.

## Screenshot


https://github.com/user-attachments/assets/f2d16454-5408-43b3-b207-cd843bbc2c9e



## 🎯 Project Scope

This application serves as a complete offline POS system for small to medium-sized retail shops. It streamlines the checkout process, catalog management, and receipt generation securely entirely on-device.

### Core Features:
- **Product Management System**: Complete CRUD operations for inventory items with barcode/QR code support.
- **Smart Checkout System**: Rapid cart building via camera-based barcode scanning or manual entry, and robust order calculation functionality.
- **Bluetooth Thermal Printing**: Direct integration with thermal printers (`print_bluetooth_thermal`) to instantly output physical receipts.
- **Shop Settings & Customization**: Centrally managed shop details printed dynamically on receipts.
- **Order History Management**: Persistent local record of all past checkouts with intelligent sorting and filtering.
- **PDF Invoice Engine**: Dynamic generation of 80mm roll-format digital receipts for sharing or a-sync viewing.
- **Offline-First Architecture**: Powered by `Hive` for lightning-fast localized NoSQL data storage. No active internet connectivity required.

## 🛠 Tech Stack & Architecture

Built leveraging industry-standard architectural principles (Clean Architecture & Feature-Driven Design) ensuring scalability, separation of concerns, and robust testability. 

- **Framework**: [Flutter](https://flutter.dev/) (SDK >=3.1.0)
- **State Management**: `flutter_bloc`
- **Dependency Injection**: `get_it`
- **Routing**: `go_router`
- **Local Database**: `hive` & `hive_flutter`
- **Data Modeling**: `json_serializable`, `equatable`
- **Functional Programming**: `fpdart`
- **Hardware Integrations**: `mobile_scanner` (barcodes), `print_bluetooth_thermal` (thermal printing)
- **Document Engine**: `pdf`, `printing` (PDF generation and system print dialogs)

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
    ├── settings/               # App configuration: Printer connections, App settings
    └── shop/                   # Shop details configuration
```

*Note: Each feature is further subdivided internally into Clean Architecture layers: `data`, `domain`, and `presentation`.*

## 💡 Use Cases

- **Rapid Billing Entry**: A cashier launches the app, navigates to the checkout page, and uses the device camera to instantly scan product barcodes. The products are added to the cart, the total is calculated including taxes, and a receipt is finalized.
- **Physical Receipt Generation**: After checkout confirmation, the app triggers a connected external Bluetooth thermal POS printer to instantly print an itemized paper receipt with the shop’s header.
- **Inventory Sideloading**: A manager opens the Product feature to add new stock to the local database, taking a picture of the barcode to bind the SKU for future lightning-fast checkouts.
- **Audit & Receipt Re-generation**: A customer returns for a copy of their bill; the manager searches the Order History (persisted in Hive), retrieves the record, and either shares a PDF or prints a duplicate thermal receipt instantly.
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
