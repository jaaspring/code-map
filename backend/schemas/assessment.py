from enum import Enum
from pydantic import BaseModel, Field
from typing import List, Dict, Optional


# -----------------------------
# User-related schemas
# -----------------------------
class UserResponses(BaseModel):
    educationLevel: Optional[str]
    cgpa: Optional[float]
    thesisTopic: Optional[str]
    major: Optional[str]
    programmingLanguages: List[str] = []
    courseworkExperience: Optional[str]
    skillReflection: Optional[str]
    thesisFindings: Optional[str]
    careerGoals: Optional[str]


class SkillReflectionRequest(BaseModel):
    user_test_id: str


# -----------------------------
# Submit test with user ID
# -----------------------------
class SubmitTestRequest(BaseModel):
    responses: UserResponses
    user_id: str


# -----------------------------
# Follow-up test schemas
# -----------------------------
class FollowUpResponse(BaseModel):
    questionId: str  # camelCase to match JSON
    selectedOption: str  # camelCase to match JSON
    user_test_id: str  # snake_case to match JSON
    test_attempt: int  # snake_case to match JSON


class FollowUpResponses(BaseModel):
    responses: List[FollowUpResponse]


# -----------------------------
# Question generation schemas
# -----------------------------
class Category(str, Enum):
    Coding = "Coding"
    NonCoding = "Non-coding"


class Difficulty(str, Enum):
    Easy = "Easy"
    Medium = "Medium"
    Hard = "Hard"


class Question(BaseModel):
    question: str = Field(description="The question text")
    options: List[str] = Field(description="List of 4 options A, B, C, D")
    answer: str = Field(description="Correct answer A, B, C, or D")
    difficulty: str = Field(description="Easy, Medium, or Hard")
    category: str = Field(description="Coding or Non-coding")


class CodingQuestion(BaseModel):
    question: str = Field(description="Question with embedded code snippet")
    difficulty: str = Field(description="Easy, Medium, or Hard")
    category: str = Field(description="Coding")


# -----------------------------
# Job matching / profile schemas
# -----------------------------
class JobMatch(BaseModel):
    job_index: int
    similarity_score: float
    similarity_percentage: float
    job_title: str
    job_description: str
    required_skills: Dict[str, str]
    required_knowledge: Dict[str, str]


class UserProfileMatchResponse(BaseModel):
    profile_text: str
    top_matches: List[JobMatch]
