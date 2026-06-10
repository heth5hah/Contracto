# Contracto App

A comprehensive B2B contracting platform built with Flutter. Contracto streamlines the entire contracting workflow from quote requests to project completion, designed specifically for professional contractors and their clients.

## Features

- **Quote Management**: Request and manage quotes with detailed specifications
- **Project Tracking**: Monitor project progress and milestones
- **Client Portal**: Dedicated interface for client interactions
- **Admin Dashboard**: Comprehensive admin panel for business management
- **Real-time Updates**: Live notifications and status updates
- **Document Management**: Secure document storage and sharing
- **Payment Integration**: Streamlined payment processing
- **Analytics**: Detailed reporting and analytics dashboard

## Getting Started

This project is built with Flutter and requires Flutter SDK to be installed.

### Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK (included with Flutter)
- Android Studio / Xcode for mobile development
- Supabase account for backend services

### Installation

1. Clone the repository
```bash
git clone https://github.com/your-username/contracto-app.git
cd contracto-app
```

2. Install dependencies
```bash
flutter pub get
```

3. Configure Supabase
- Update the Supabase URL and API key in `lib/core/config/app_config.dart`
- Run the SQL schema from `supabase_schema.sql` in your Supabase project

4. Run the app
```bash
flutter run
```

## Project Structure

```
lib/
├── core/
│   ├── config/          # App configuration
│   ├── network/         # Network services
│   └── theme/           # App theme and styling
├── features/
│   ├── auth/            # Authentication
│   ├── cart/            # Shopping cart
│   ├── credit/          # Credit management
│   ├── products/        # Product management
│   ├── profile/         # User profile
│   └── quotations/      # Quote management
└── shared/
    └── widgets/         # Reusable widgets
```

## Admin Panel

The admin panel is located in the `admin/` directory and provides:
- Dashboard with analytics
- Product management
- User management
- Quote request handling
- System settings

Access the admin panel at `admin/index.html` with:
- Email: admin@contracto.com
- Password: admin123

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support, email support@contracto.com or visit our website at https://www.contracto.com
