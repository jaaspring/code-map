from models.firestore_models import (
    get_profile_text_by_user,
    get_job_by_index,
    get_user_skills,
    get_generated_questions,
    get_follow_up_answers_by_user,
)
import matplotlib

matplotlib.use("Agg")  # use non-interactive backend
import matplotlib.pyplot as plt
import numpy as np
import io
import base64


def generate_radar_chart(skills, user_level, required_level):
    """Generate radar chart and return as base64 string."""
    # angles for radar
    angles = np.linspace(0, 2 * np.pi, len(skills), endpoint=False).tolist()
    user_level_radar = user_level + user_level[:1]
    required_level_radar = required_level + required_level[:1]
    angles += angles[:1]

    # plot
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
    ax.set_yticks([0, 1, 2])
    ax.set_yticklabels(["Not Detected", "Beginner", "Intermediate"])
    ax.set_title("Skill Gap Analysis", size=12)
    ax.legend(loc="upper right")

    # Save to buffer
    buf = io.BytesIO()
    plt.savefig(buf, format="png", dpi=300, bbox_inches="tight")
    buf.seek(0)
    plt.close()

    # Encode as base64
    return base64.b64encode(buf.getvalue()).decode("utf-8")


from models.firestore_models import (
    get_generated_questions,
    get_follow_up_answers_by_user,
)


from models.firestore_models import (
    get_generated_questions,
    get_follow_up_answers_by_user,
)


def calculate_test_performance(user_test_id: str):
    """
    Calculate accuracy by difficulty and question type.
    """
    # Fetch questions and user answers
    questions = get_generated_questions(user_test_id)
    answers = get_follow_up_answers_by_user(user_test_id)

    # Map answers by question_id for quick lookup
    answers_map = {a["question_id"]: a["selected_option"] for a in answers}
    print(f"Answers Map: {answers_map}")

    # Initialize performance counters
    performance_by_difficulty = {}
    performance_by_type = {}

    for q in questions:
        qid = q.get("id") or q.get("question_id")
        correct_answer = q.get("answer")
        user_answer = answers_map.get(qid)

        difficulty = q.get("difficulty", "Unknown")
        qtype = q.get("question_type", "Unknown")

        # Initialize counters
        performance_by_difficulty.setdefault(difficulty, {"correct": 0, "total": 0})
        performance_by_type.setdefault(qtype, {"correct": 0, "total": 0})

        # Increment totals
        performance_by_difficulty[difficulty]["total"] += 1
        performance_by_type[qtype]["total"] += 1

        # Normalize user's answer to just the option letter
        user_choice = None
        if user_answer:
            user_choice = user_answer.strip()[0].upper()  # e.g., "B. text" -> "B"

        # Check correctness
        is_correct = user_choice == correct_answer.upper()
        if is_correct:
            performance_by_difficulty[difficulty]["correct"] += 1
            performance_by_type[qtype]["correct"] += 1

    # Convert counts to percentages
    difficulty_accuracy = {
        k: (v["correct"] / v["total"]) * 100 if v["total"] > 0 else 0
        for k, v in performance_by_difficulty.items()
    }
    type_accuracy = {
        k: (v["correct"] / v["total"]) * 100 if v["total"] > 0 else 0
        for k, v in performance_by_type.items()
    }

    return {"by_difficulty": difficulty_accuracy, "by_type": type_accuracy}


def generate_bar_chart(data: dict, title: str, xlabel: str, ylabel: str):
    """Generate bar chart from dict and return base64 string."""
    categories = list(data.keys())
    values = list(data.values())

    plt.figure(figsize=(6, 4))
    bars = plt.bar(categories, values, color="#A8D0F7")
    plt.title(title)
    plt.xlabel(xlabel)
    plt.ylabel(ylabel)
    plt.ylim(0, 100)

    # Add labels on bars
    for bar, value in zip(bars, values):
        plt.text(
            bar.get_x() + bar.get_width() / 2,
            bar.get_height() + 1,
            f"{value:.1f}%",
            ha="center",
            fontsize=8,
        )

    # Save to buffer
    buf = io.BytesIO()
    plt.savefig(buf, format="png", dpi=300, bbox_inches="tight")
    buf.seek(0)
    plt.close()

    return base64.b64encode(buf.getvalue()).decode("utf-8")


def get_report_data(user_test_id: str, job_index: str):
    """
    Combine profile_text and job details into a single report.
    """
    profile_text = get_profile_text_by_user(user_test_id)
    job_data = get_job_by_index(job_index)

    # get user skills and knowledge
    user_data = get_user_skills(user_test_id)
    user_skills = user_data.get("skills", {})

    # extract job skill requirements
    job_skills = job_data.get("required_skills", {})  # dict {skill: level}

    # align skill levels
    skills = list(job_skills.keys())
    required_level = [job_skills[s] for s in skills]
    user_level = [user_skills.get(s, 0) for s in skills]

    # chart
    radar_chart_base64 = generate_radar_chart(skills, user_level, required_level)

    # Test performance charts
    performance = calculate_test_performance(user_test_id)
    difficulty_chart = generate_bar_chart(
        performance["by_difficulty"],
        "Accuracy by Difficulty",
        "Difficulty",
        "Accuracy %",
    )
    type_chart = generate_bar_chart(
        performance["by_type"], "Accuracy by Question Type", "Type", "Accuracy %"
    )

    report = {
        "user_test_id": user_test_id,
        "profile_text": profile_text,
        "job": job_data,
        "charts": {
            "radar_chart": radar_chart_base64,  # base64 string to PNG
            "difficulty_chart": difficulty_chart,
            "type_chart": type_chart,
        },
    }
    return report
