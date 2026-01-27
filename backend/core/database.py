# core/database.py

import firebase_admin
from firebase_admin import credentials, firestore
import os
from dotenv import load_dotenv

load_dotenv()

# Build absolute path relative to backend/
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIREBASE_CREDENTIALS = os.getenv("FIREBASE_CREDENTIALS", "serviceAccountKey.json")
FIREBASE_CREDENTIALS = os.path.join(BASE_DIR, FIREBASE_CREDENTIALS)

if not firebase_admin._apps:
    cred = credentials.Certificate(FIREBASE_CREDENTIALS)
    firebase_admin.initialize_app(cred)

db = firestore.client()


def get_collection(name: str):
    return db.collection(name)


def get_db():
    return db
