# Rakufuku Flutter App

AI Personal Stylist - Daily outfit recommendations

## Getting Started

### Prerequisites

- Flutter SDK 3.2.0 or higher
- Dart SDK 3.2.0 or higher
- Android Studio / Xcode for mobile development

### Installation

1. Clone the repository
2. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app:
   ```bash
   flutter run
   ```

### Backend Connection

The app connects to a FastAPI backend. Make sure the backend is running:

```bash
cd backend
uvicorn main:app --reload
```

By default, the app connects to `http://localhost:8000/api/v1`.

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── config/
│   ├── theme.dart           # Theme configuration
│   └── router.dart          # Navigation routes
├── core/
│   ├── api/api_client.dart  # API client
│   └── models/              # Data models
├── features/
│   ├── auth/                # Authentication
│   ├── home/                # Daily outfit
│   ├── closet/              # Wardrobe management
│   ├── history/             # Outfit history
│   └── settings/            # App settings
└── shared/widgets/          # Shared components
```

## Features

- Daily outfit recommendations based on weather and calendar
- Digital wardrobe management
- Camera capture for adding new items
- Outfit history tracking
- Style preferences
