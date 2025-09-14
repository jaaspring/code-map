# CodeMap

Personalized career recommendation and skill gap analysis powered by AI.

## About

> This project is an AI-powered career recommendation app that analyzes educational background, skill reflections, and validation/follow-up tests, matches them with suitable job profiles, and provides personalized learning recommendations.

---

## Features

- **Career Assessment** _(leverages NLP to analyze user input)_  
  - **Educational Background Test** _(interprets responses using NLP)_  
  - **Skill Reflection Test** _(leverages NLP to extracts skills and insights from text)_  
  - **Follow-Up Test** _(leverages NLP to generates personalized MCQs from user reflections)_
- **Generate Embeddings & Job Matches** _(leverages NLP for semantic similarity and matching)_  
- **Career Recommendations** _(leverages NLP to tailor suggestions based on analyzed input and job data)_  
- **Skill Gap Analysis** _(compares user skills with job requirements using NLP)_


---

## Tech Stack

- **Backend:** FastAPI, Python, SQLAlchemy  
- **Frontend:** Flutter  
- **Database:** PostgreSQL
- **AI / ML:** OpenAI API, Hugging Face Transformers  

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
```
