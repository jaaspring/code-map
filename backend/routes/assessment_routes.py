from typing import List
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from core.database import SessionLocal, get_db
from models.assessment import UserTest, GeneratedQuestion, FollowUpAnswers, CareerRecommendation, CareerJobMatch, UserSkillsKnowledge
from schemas.assessment import (
    UserResponses,
    SkillReflectionRequest,
    FollowUpResponses,
    JobMatch,
    UserProfileMatchResponse,
)
from services.openai_service import generate_questions
from services.embedding_service import create_user_embedding, match_user_to_job, analyze_user_skills_knowledge
import json

router = APIRouter()


# -----------------------------
# Submit user test responses
# -----------------------------
@router.post("/submit-test")
def submit_test(data: UserResponses):
    db = SessionLocal()
    try:
        prog_langs_str = ",".join(data.programmingLanguages)
        new_entry = UserTest(
            educationLevel=data.educationLevel,
            cgpa=data.cgpa,
            major=data.major,
            programmingLanguages=prog_langs_str,
            courseworkExperience=data.courseworkExperience,
            skillReflection=data.skillReflection,
        )
        db.add(new_entry)
        db.commit()
        db.refresh(new_entry)
        return {"message": "Data saved successfully", "id": new_entry.id}
    finally:
        db.close()


# -----------------------------
# Generate follow-up questions
# -----------------------------
@router.post("/generate-questions")
def create_follow_up_questions(
    data: SkillReflectionRequest,
    db: Session = Depends(get_db),
):
    try:
        # 1) Fetch the UserTest
        user_test = db.query(UserTest).filter(UserTest.id == data.user_test_id).first()
        if not user_test or not user_test.skillReflection:
            return {"error": "No skill reflection found for this user_test_id"}

        # 2) Generate questions using OpenAI service
        result = generate_questions(
            user_test.skillReflection
        )  # This returns a dict with "questions" key

        # 3) Extract the actual MCQ questions from the response
        raw_questions = result.get("questions", [])
        if not raw_questions:
            return {"questions": []}

        # 4) Prepare and insert questions
        new_questions = []
        for q in raw_questions:
            # Extract data from the OpenAI response
            question_text = q.get("question")
            options = q.get("options", [])
            answer = q.get("answer")
            difficulty = q.get("difficulty", "easy")
            question_type = q.get("category", "general")  # Use "category" from OpenAI

            if not question_text or not options:
                continue

            new_q = GeneratedQuestion(
                user_test_id=data.user_test_id,
                question_text=question_text,
                options=json.dumps(options),  # Convert list to JSON string
                answer=answer,  # Save the correct answer
                difficulty=difficulty,
                question_type=question_type,
            )
            db.add(new_q)
            db.flush()
            new_questions.append(new_q)

        # 5) Commit all inserts
        db.commit()

        # 6) Prepare response
        saved_questions = [
            {
                "id": q.id,
                "question": q.question_text,
                "options": json.loads(q.options),  # Convert back to list
                "answer": q.answer,  # Include the answer in response
                "difficulty": q.difficulty,
                "category": q.question_type,
            }
            for q in new_questions
        ]

        return {"questions": saved_questions}

    except Exception as e:
        db.rollback()
        return {"error": f"Internal Server Error: {str(e)}"}


# -----------------------------
# Submit follow-up answers
# -----------------------------
@router.post("/submit-follow-up")
def submit_follow_up(data: FollowUpResponses):
    db = SessionLocal()
    try:
        for resp in data.responses:
            db.add(
                FollowUpAnswers(
                    user_test_id=resp.user_test_id,
                    question_id=resp.questionId,
                    selected_option=resp.selectedOption,
                )
            )
        db.commit()
        return {"message": "Follow-up answers saved successfully"}
    except Exception as e:
        db.rollback()
        return {"error": str(e)}
    finally:
        db.close()


# -----------------------------
# Generate user profile and job matches
# -----------------------------
@router.post("/user-profile-match", response_model=UserProfileMatchResponse)
def user_profile_match(request: SkillReflectionRequest, db: Session = Depends(get_db)):
    user_test_id = request.user_test_id
    
    # Debug: Check if user exists
    user_test = db.query(UserTest).filter(UserTest.id == user_test_id).first()
    if not user_test:
        return UserProfileMatchResponse(
            profile_text="",
            top_matches=[],
            error=f"User test ID {user_test_id} not found"
        )

    # Create user embedding + profile text
    user_data = create_user_embedding(user_test_id)
    if "error" in user_data:
        return UserProfileMatchResponse(
            profile_text="",
            top_matches=[],
            error=f"User embedding failed: {user_data['error']}"
        )

    # Analyze skills and knowledge with better error handling
    try:
        skills_knowledge_result = analyze_user_skills_knowledge(user_test_id)
        if "error" in skills_knowledge_result:
            print(f"[ERROR] Skills/Knowledge analysis failed: {skills_knowledge_result['error']}")
            # You might want to return this error or handle it differently
        else:
            print(f"[INFO] Skills/Knowledge saved for user_test_id {user_test_id}")
            print(f"Extracted skills: {skills_knowledge_result.get('skills', [])}")
            print(f"Extracted knowledge: {skills_knowledge_result.get('knowledge', [])}")
    except Exception as e:
        print(f"[ERROR] Unexpected error in skills/knowledge analysis: {str(e)}")
    
    
    # Match jobs
    matches = match_user_to_job(user_test_id, user_data["user_embedding"])
    if "error" in matches:
        return UserProfileMatchResponse(
            profile_text=user_data["profile_text"],
            top_matches=[]
        )

    # Save into DB
    try:
        # Insert recommendation
        rec = CareerRecommendation(
            user_test_id=user_test_id,
            profile_text=user_data["profile_text"],
        )
        db.add(rec)
        db.flush()  # so we get rec.id

        # Insert job matches
        for job in matches["top_matches"]:
            db.add(CareerJobMatch(
                recommendation_id=rec.id,
                job_index=job["job_index"],
                similarity_score=job["similarity_score"],
                similarity_percentage=job["similarity_percentage"],
                job_title=job["job_title"],
                job_description=job["job_description"],
                required_skills=job["required_skills"],
                required_knowledge=job["required_knowledge"],
            ))

        db.commit()
    except Exception as e:
        db.rollback()
        return UserProfileMatchResponse(profile_text=user_data["profile_text"], top_matches=[])

    # Convert job dicts to JobMatch models
    top_matches_list = [JobMatch(**job) for job in matches["top_matches"]]

    # Return response to frontend
    return UserProfileMatchResponse(
        profile_text=user_data["profile_text"],
        top_matches=top_matches_list
    )

