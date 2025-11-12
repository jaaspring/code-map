from models.firestore_models import (
    get_profile_text_by_user,
    get_job_by_index,
    get_user_skills_knowledge,
    get_generated_questions,
    get_follow_up_answers_by_user,
)
import matplotlib

matplotlib.use("Agg")  # non-interactive backend
import matplotlib.pyplot as plt
import numpy as np
import io
import base64

# Map text labels to numeric levels
LEVEL_MAP = {
    "Not Provided": 0,
    "Basic": 1,
    "Intermediate": 2,
    "Advanced": 3,
}


def normalize_level(level):
    """Convert skill level text/number into a consistent numeric scale."""
    if isinstance(level, (int, float)):
        return level
    if level is None:
        return 0
    return LEVEL_MAP.get(str(level).strip(), 0)


def generate_radar_chart(skills, user_level, required_level):
    """Generate radar chart and return as base64 string."""
    angles = np.linspace(0, 2 * np.pi, len(skills), endpoint=False).tolist()
    user_level_radar = user_level + user_level[:1]
    required_level_radar = required_level + required_level[:1]
    angles += angles[:1]

    plt.figure(figsize=(6, 6))
    ax = plt.subplot(111, polar=True)

    soft_red = "#F7A8A8"
    soft_blue = "#A8D0F7"

    ax.plot(angles, user_level_radar, label="Your Level", color=soft_red, linewidth=2)
    ax.fill(angles, user_level_radar, color=soft_red, alpha=0.25)
    ax.plot(
        angles,
        required_level_radar,
        label="Required Level",
        color=soft_blue,
        linewidth=2,
        linestyle="dashed",
    )
    ax.fill(angles, required_level_radar, color=soft_blue, alpha=0.1)

    ax.set_xticks(angles[:-1])
    ax.set_xticklabels(skills)
    ax.set_yticks([0, 1, 2, 3])
    ax.set_yticklabels(["Not Detected", "Basic", "Intermediate", "Advanced"])
    ax.set_title("Skill Gap Analysis", size=12)
    ax.legend(loc="upper right")

    buf = io.BytesIO()
    plt.savefig(buf, format="png", dpi=300, bbox_inches="tight")
    buf.seek(0)
    plt.close()

    return base64.b64encode(buf.getvalue()).decode("utf-8")


def calculate_test_performance(user_test_id: str):
    """Calculate total correct vs incorrect answers."""
    questions = get_generated_questions(user_test_id)
    answers = get_follow_up_answers_by_user(user_test_id)

    answers_map = {a["question_id"]: a["selected_option"] for a in answers}

    correct = 0
    total = len(questions)

    for q in questions:
        qid = q.get("id") or q.get("question_id")
        correct_answer = q.get("answer")
        user_answer = answers_map.get(qid)

        if not user_answer:
            continue

        user_choice = user_answer.strip()[0].upper()  # e.g., "B. text" -> "B"
        if user_choice == correct_answer.upper():
            correct += 1

    incorrect = total - correct
    return {"Correct": correct, "Incorrect": incorrect}


def generate_bar_chart(data: dict):
    """Generate bar chart showing how many answers are correct vs incorrect."""
    categories = list(data.keys())
    values = list(data.values())

    plt.figure(figsize=(4, 4))
    bars = plt.bar(categories, values, color=["#A8D0F7", "#F7A8A8"])
    plt.title("Overall Test Performance")
    plt.xlabel("Result")
    plt.ylabel("Number of Questions")
    plt.ylim(0, max(values) + 1)

    for bar, value in zip(bars, values):
        plt.text(
            bar.get_x() + bar.get_width() / 2,
            bar.get_height() + 0.1,
            str(value),
            ha="center",
            fontsize=9,
        )

    buf = io.BytesIO()
    plt.savefig(buf, format="png", dpi=300, bbox_inches="tight")
    buf.seek(0)
    plt.close()

    return base64.b64encode(buf.getvalue()).decode("utf-8")


def get_report_data(user_test_id: str, job_index: str):
    """Combine profile_text and job details into a single report."""
    profile_text = get_profile_text_by_user(user_test_id)
    job_data = get_job_by_index(job_index)
    user_data = get_user_skills_knowledge(user_test_id)

    job_skills_raw = job_data.get("required_skills", {})
    user_skills_raw = user_data.get("skills", {})

    skills = list(job_skills_raw.keys())
    required_level = [normalize_level(job_skills_raw.get(skill, 0)) for skill in skills]
    user_level = [
        normalize_level(
            user_skills_raw.get(skill)
            or user_skills_raw.get(skill.lower())
            or user_skills_raw.get(skill.title())
            or 0
        )
        for skill in skills
    ]

    radar_chart_base64 = generate_radar_chart(skills, user_level, required_level)
    test_performance = calculate_test_performance(user_test_id)
    result_chart = generate_bar_chart(test_performance)

    report = {
        "user_test_id": user_test_id,
        "profile_text": profile_text,
        "job": job_data,
        "charts": {
            "radar_chart": radar_chart_base64,
            "result_chart": result_chart,
        },
    }

    return report
