from sqlalchemy import Column, ForeignKey, Integer, String, Float, Text, JSON, DateTime
from sqlalchemy.orm import relationship
from datetime import datetime
from core.database import Base

class UserTest(Base):
    __tablename__ = "user_test"

    id = Column(Integer, primary_key=True, index=True)
    educationLevel = Column(String, nullable=True)
    cgpa = Column(Float, nullable=True)
    major = Column(String, nullable=True)
    programmingLanguages = Column(String, nullable=True)
    courseworkExperience = Column(String, nullable=True)
    skillReflection = Column(Text, nullable=True)
    
    skills_knowledge = relationship("UserSkillsKnowledge", back_populates="user_test", uselist=False)
    career_recommendations = relationship("CareerRecommendation", back_populates="user_test")
    

class GeneratedQuestion(Base):
    __tablename__ = "generated_questions"

    id = Column(Integer, primary_key=True, index=True)
    user_test_id = Column(Integer, nullable=False)  # FK to UserTest.id
    question_text = Column(Text, nullable=False)
    options = Column(Text, nullable=True)
    answer = Column(String, nullable=True)
    difficulty = Column(String, nullable=True)
    question_type = Column(String, nullable=True)
    
class FollowUpAnswers(Base):
    __tablename__ = "follow_up_answers"

    id = Column(Integer, primary_key=True, index=True)
    user_test_id = Column(Integer, ForeignKey("user_test.id"), nullable=False)
    question_id = Column(Integer, ForeignKey("generated_questions.id"), nullable=False)
    selected_option = Column(String, nullable=False)

class CareerRecommendation(Base):
    __tablename__ = "career_recommendations"

    id = Column(Integer, primary_key=True, index=True)
    user_test_id = Column(Integer, ForeignKey("user_test.id"))
    profile_text = Column(String)  # OpenAI-generated summary

    user_test = relationship("UserTest", back_populates="career_recommendations")
    job_matches = relationship("CareerJobMatch", back_populates="recommendation")

class CareerJobMatch(Base):
    __tablename__ = "career_job_matches"

    id = Column(Integer, primary_key=True, index=True)
    recommendation_id = Column(Integer, ForeignKey("career_recommendations.id"))
    job_index = Column(Integer)
    similarity_score = Column(Float)
    similarity_percentage = Column(Float)
    job_title = Column(String)
    job_description = Column(String)
    required_skills = Column(JSON)
    required_knowledge = Column(JSON)

    recommendation = relationship("CareerRecommendation", back_populates="job_matches")

class UserSkillsKnowledge(Base):
    __tablename__ = "user_skills_knowledge"
    
    id = Column(Integer, primary_key=True, index=True)
    user_test_id = Column(Integer, ForeignKey("user_test.id"), unique=True)
    skills = Column(JSON)
    knowledge = Column(JSON)

    user_test = relationship("UserTest", back_populates="skills_knowledge")
