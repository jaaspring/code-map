# CodeMap

Personalized career recommendation and skill gap analysis powered by AI.

## About

> This project is an AI-powered career recommendation app that analyzes educational background, skill reflections, and validation/follow-up tests, matches them with suitable job profiles, and provides personalized career roadmaps.

---

## Features

- **Career Assessment** _(leverages NLP to analyze user input)_  
  - **Educational Background Test** _(interprets responses using NLP)_  
  - **Skill Reflection Test** _(leverages NLP to extracts skills and insights from texts)_  
  - **Follow-Up Test** _(leverages NLP to generate personalized MCQs from user reflections)_
- **Generate Embeddings & Job Matches** _(leverages NLP for semantic similarity and matching)_  
- **Career Recommendations** _(leverages NLP to tailor suggestions based on analyzed input and job data)_  
- **Gap Analysis** _(compares user skills and knowledge with job requirements using NLP)_
- **Career Analysis Report** _(visualizes user skill gaps and test performance using radar and bar charts via Matplotlib)_
- **Career Roadmap** _(generates structured career progression paths based on skill gap analysis using NLP)_


---

## Tech Stack

- **Backend:** FastAPI, Python
- **Frontend:** Flutter  
- **Database:** Firebase
- **AI / ML:** OpenAI API, Hugging Face Transformers, LangChain  

---

## Project Structure

```
code_map/
├── Frontend (Flutter)
│   ├── lib/
│   │   ├── models/          # Data models
│   │   ├── screens/         # UI screens
│   │   ├── services/        # API services and business logic
│   │   └── main.dart        # Application entry point
│   ├── android/             # Android-specific files
│   ├── ios/                 # iOS-specific files
│   ├── linux/               # Linux-specific files
│   ├── macos/               # macOS-specific files
│   ├── web/                 # Web-specific files
│   ├── windows/             # Windows-specific files
│   └── test/                # Test files
│
├── Backend (Python)
│   ├── core/                # Core application logic
│   ├── data/                # Data management
│   ├── models/              # Database models
│   ├── routes/              # API routes/endpoints
│   ├── schemas/             # Data schemas (Pydantic)
│   ├── services/            # Business logic services
│   ├── venv/                # Python virtual environment
│   ├── __pycache__/         # Python cache files
│   ├── .env                 # Environment variables
│   ├── main.py              # Application entry point
│   └── requirements.txt     # Python dependencies

