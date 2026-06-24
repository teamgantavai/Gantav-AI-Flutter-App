# Gantav AI — Your Gantavya 🎯

> Turn YouTube into structured, AI-powered learning paths. Set your destination, and let AI guide you there.

## Features

### 🧠 Smart Onboarding
- **4-step personalization poll** for first-time users
- Language preference (English / Hindi) — affects AI-generated content
- Learning goal selection (Exams, Coding, Skills, Projects, Subjects)
- Optional favorite teacher/channel preference
- Daily study time commitment (15 min → 2 hours)

### 🗺️ AI-Generated Roadmaps
- Personalized day-by-day learning plans powered by Google Gemini
- Each day contains specific, actionable tasks (watch videos, practice exercises)
- Real YouTube video IDs integrated into tasks
- 14-21 day roadmaps based on your daily time budget
- Hindi/English content generation based on language preference

### ✅ Task Completion Tracking
- Tap tasks to mark them complete with animated checkboxes
- Day-level auto-completion when all tasks are done
- Overall roadmap progress with animated progress bars
- "Today's Tasks" card on the home screen

### 📤 Share Roadmap
- Export roadmap as PNG image with Gantav AI branding
- Share directly via any installed app (WhatsApp, Instagram, etc.)

### 📚 YouTube Learning Paths
- AI-curated YouTube video courses
- Module-based curriculum with lessons
- In-app YouTube player with chapter navigation
- AI-powered quiz generation after lessons
- Doubt resolution with AI tutor chat

### 👤 User Profile
- My Roadmaps tab with progress tracking
- Achievement badges (First Step, 7-Day Streak, Quiz Master, etc.)
- Weekly activity tracking
- Gantav Score + streak system

---

## Architecture

```
lib/
├── models/
│   ├── models.dart             # Core data models (User, Course, Module, Lesson)
│   └── onboarding_models.dart  # Onboarding models (Preferences, Roadmap, RoadmapDay, Task)
├── services/
│   ├── app_state.dart          # Global state management (Provider)
│   ├── auth_service.dart       # Firebase Auth (Google, Email/Password)
│   ├── firestore_service.dart  # Firestore CRUD (profiles, courses, roadmaps, preferences)
│   ├── gemini_service.dart     # Multi-provider AI service (Gemini, Groq, OpenRouter)
│   ├── onboarding_service.dart # AI roadmap generation from user preferences
│   ├── api_service.dart        # Mock data API
│   ├── api_config.dart         # AI provider configuration & routing
│   └── recommendation_service.dart
├── screens/
│   ├── auth_screen.dart        # Login / Sign up
│   ├── onboarding_screen.dart  # 4-step personalization poll
│   ├── roadmap_screen.dart     # Roadmap timeline + task tracking + share
│   ├── roadmap_generation_screen.dart # AI generation loading animation
│   ├── home_screen.dart        # Home (roadmap card, recommendations, courses)
│   ├── explore_screen.dart     # Browse categories
│   ├── progress_screen.dart    # Learning analytics
│   ├── profile_screen.dart     # Profile + My Roadmaps
│   ├── course_detail_screen.dart
│   └── lesson_player_screen.dart
├── widgets/
│   ├── widgets.dart            # Reusable UI components
│   └── connectivity_wrapper.dart
├── theme/
│   └── app_theme.dart          # Design system (colors, typography)
└── main.dart                   # App entry point + router
```

---

## Navigation Flow

```
App Launch
  ├── Returning User → Home Screen
  └── New User
       ├── Auth Screen (Google / Email)
       ├── Onboarding Poll (4 steps)
       ├── AI Roadmap Generation (loading)
       └── Home Screen (with Roadmap card)
```

---

## Setup

### Prerequisites
- Flutter SDK 3.8+
- Firebase project configured
- At least one AI API key

### 1. Clone & Install
```bash
git clone <repo-url>
cd gantav_ai
flutter pub get
```

### 2. Firebase Setup
- Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
- Enable Authentication (Google Sign-In + Email/Password)
- Enable Cloud Firestore
- Download config files and run `flutterfire configure`

### 3. Environment Variables
Create a `.env` file in the project root:
```env
GEMINI_API_KEY=your_gemini_api_key
GROQ_API_KEY=your_groq_api_key        # Optional
OPENROUTER_API_KEY=your_openrouter_key # Optional
YOUTUBE_API_KEY=your_youtube_api_key   # Optional
```

At least one AI provider key is required. The app automatically routes between providers with fallback:
- **Gemini** → Best for structured JSON output (courses, roadmaps)
- **Groq** → Fastest inference (chat, recommendations)
- **OpenRouter** → Cost-effective fallback

### 4. Run
```bash
flutter run -d chrome    # Web
flutter run -d android   # Android
```

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.8+ |
| State Management | Provider |
| Authentication | Firebase Auth |
| Database | Cloud Firestore |
| AI | Google Gemini, Groq, OpenRouter |
| Video Player | youtube_player_iframe |
| Design | Material 3 + Custom Design System |
| Typography | DM Sans, DM Mono (Google Fonts) |

---

## License

MIT License — see [LICENSE](LICENSE) for details.
