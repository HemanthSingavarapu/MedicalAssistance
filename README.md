# 🏥 Medical Assistance App

A **smart AI-powered healthcare assistant** built with **Flutter**, helping users get instant and accurate medical information through **chat, voice, or image input**.  
This app aims to make **health guidance more accessible, interactive, and intelligent**.

---

## 📱 Screenshots

| Intro Screen | Home Screen | Chat Screen | Chat Response |
|---------------|--------------|--------------|----------------|
| <img src="https://github.com/HemanthSingavarapu/MedicalAssistance/blob/6853ef3dfb653b2cc97f3fd8a08ac812f62547f9/screenshots/Intro.png" width="250"/> | <img src="assets/images/home_screen.png" width="250"/> | <img src="assets/images/chat_screen.png" width="250"/> | <img src="assets/images/chat_content.png" width="250"/> |

> 💡 *Replace the above image paths with your actual screenshot file paths in the `assets/images` folder.*

---

## 🚀 Features

- 🏡 **Home Page with Health Tips**  
  Displays daily wellness insights, nutrition suggestions, and preventive care advice.

- 💬 **Chat Assistant**  
  Ask medical questions through **text**, **voice**, or **image**, and get accurate responses.

- 🧠 **AI-Powered Medical Insights**  
  Backed by **Groq API** for fast and reliable AI-driven answers.

- 🎙️ **Voice Interaction**  
  Communicate with the assistant hands-free using **speech recognition**.

- 📸 **Photo-Based Query**  
  Upload or capture symptom images (e.g., skin conditions, wounds) for basic AI analysis.

- 🔒 **Privacy First**  
  No sensitive health data is stored. All chats are processed securely through the Groq API.

---

## 🧠 Tech Stack

| Layer | Technology |
|--------|-------------|
| **Frontend** | Flutter (Dart) |
| **AI Backend** | Groq API |
| **Speech Recognition** | Flutter Speech-to-Text |
| **Image Processing** | TensorFlow Lite / Vision API |
| **State Management** | Provider / Bloc (as per your app) |

---

## 🔑 API Integration (Groq API)

The app uses the **Groq API** to process user queries and generate intelligent responses.

### Setup Instructions:

1. Go to [Groq Console](https://console.groq.com) and generate your **API Key**.  
2. Create a `.env` file (or use `flutter_dotenv` package) in your Flutter project:

   ```env
   GROQ_API_KEY=your_api_key_here
