# FITNEST - Your Ultimate Fitness Companion

**FITNEST** is a feature-rich Flutter application designed to provide a comprehensive fitness tracking experience. With a focus on intuitive design and AI-powered insights, it helps users monitor their nutrition, hydration, and activity while providing personalized workout plans.

---

## ✨ Features

### 🥗 AI-Powered Nutrition Tracker
- **Natural Language Logging**: Log your meals by simply typing what you ate (e.g., "3 eggs and a piece of toast").
- **Macro Breakdown**: Automatically calculates calories, protein, carbs, and fats using the Groq AI API.
- **Goal Management**: Set and track daily nutritional targets.
- **Visual Progress**: Glossy summary cards show your remaining daily allowance at a glance.

### 💧 Smart Hydration Tracker
- **Intake Logging**: Quick-add buttons for frequent water amounts.
- **Scheduled Reminders**: Receive push notifications to stay hydrated throughout the day.
- **History View**: Track your hydration consistency over the past 30 days.
- **Dynamic Goals**: Customize your daily water target.

### 🚶 Pedometer & Step Goals
- **Real-time Tracking**: Uses your device's hardware sensors to track daily steps.
- **Custom Goals**: Set daily step targets and monitor progress through a visual progress bar.

### 🏋️ Personalized Workouts
- **BMI-Based Plans**: Exercise suggestions tailored to your Body Mass Index and age.
- **GIF Previews**: High-quality exercise animations powered by RapidAPI.
- **Interactive Workout Player**: Follow along with your routine, mark exercises as complete, and track workout duration.

### 👤 Profile & Progress
- **Body Stat Tracking**: Manage your age, height, weight, and gender.
- **Automatic BMI Calculation**: Visual BMI chart to track your health status.
- **Secure Authentication**: Robust user management powered by Supabase.

---

## 🛠️ Setup and Installation

### Prerequisites
- Flutter SDK (Latest Version)
- Supabase Account
- Groq API Key
- RapidAPI Key (for ExerciseDB)

### Configuration
Create a `.env` file in the root directory with the following variables:

```env
# Supabase Configuration
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key

# Nutrition AI (Groq)
GROQ_API_KEY_1=your_groq_key

# Exercise API (RapidAPI)
EXERCISE_API_HOST=exercisedb.p.rapidapi.com
EXERCISE_API_KEY=your_rapidapi_key
```

### Assets
Ensure that the `.env` file is added to your `assets` section in `pubspec.yaml`:
```yaml
flutter:
  assets:
    - .env
```

### Running the App
```bash
flutter pub get
flutter run
```

---

## 🎨 Design Philosophy
Fitnest utilizes a **Glossy/Glassmorphism** design language, featuring:
- Deep slate and teal gradients.
- Semi-transparent "frosted glass" cards.
- Vibrant cyan and blue accent colors for high visibility and a modern feel.

---

## 🚀 Upcoming Features
- Social fitness challenges with friends.
- Advanced heart rate monitoring integration.
- Wearable device synchronization (Apple Health & Google Fit).
