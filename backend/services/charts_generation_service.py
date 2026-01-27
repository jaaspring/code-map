from models.firestore_models import (
    get_all_jobs,
    get_user_skills_knowledge,
    get_recommendation_id_by_user_test_id,
    get_generated_questions,
    get_follow_up_answers_by_user,
    save_job_charts,
    get_job_charts,
)
import matplotlib

matplotlib.use("Agg")
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
    if isinstance(level, (int, float)):
        return level
    if level is None:
        return 0
    return LEVEL_MAP.get(str(level).strip(), 0)


def _generate_generic_radar_chart(labels, user_level, required_level, title):
    if not labels:
        return ""

    angles = np.linspace(0, 2 * np.pi, len(labels), endpoint=False).tolist()
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
    ax.set_xticklabels(labels)
    ax.set_yticks([0, 1, 2, 3])
    ax.set_yticklabels(["Not Detected", "Basic", "Intermediate", "Advanced"])
    ax.set_title(title, size=12)
    ax.legend(loc="upper right")

    buf = io.BytesIO()
    plt.savefig(buf, format="png", dpi=120, bbox_inches="tight")
    buf.seek(0)
    plt.close()

    return base64.b64encode(buf.getvalue()).decode("utf-8")


def generate_skills_radar_chart(skills, user_level, required_level):
    return _generate_generic_radar_chart(skills, user_level, required_level, "Skill Gap Analysis")


def generate_knowledge_radar_chart(knowledge, user_level, required_level):
    return _generate_generic_radar_chart(knowledge, user_level, required_level, "Knowledge Gap Analysis")


def calculate_test_performance(user_test_id: str, attempt_number: int):
    questions = get_generated_questions(user_test_id, attempt_number)
    answers = get_follow_up_answers_by_user(user_test_id, attempt_number)

    answers_map = {a["question_id"]: a["selected_option"] for a in answers}

    correct = 0
    total = len(questions)

    for q in questions:
        qid = q.get("id") or q.get("question_id")
        correct_answer = q.get("answer")
        user_answer = answers_map.get(qid)

        if not user_answer:
            continue

        user_choice = user_answer.strip()[0].upper()
        if user_choice == correct_answer.upper():
            correct += 1

    incorrect = total - correct
    return {"Correct": correct, "Incorrect": incorrect}


def generate_bar_chart(data: dict):
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
    plt.savefig(buf, format="png", dpi=120, bbox_inches="tight")
    buf.seek(0)
    plt.close()

    return base64.b64encode(buf.getvalue()).decode("utf-8")


def compute_and_save_charts_for_all_jobs(user_test_id: str, attempt_number: int):
    rec_id = get_recommendation_id_by_user_test_id(user_test_id)
    if not rec_id:
        return {"error": "No career recommendation found for this user test ID."}

    print(f"[DEBUG] Found recommendation ID: {rec_id}")

    recommended_jobs = get_all_jobs(rec_id)
    print(f"[DEBUG] Found {len(recommended_jobs)} jobs for this recommendation")

    if not recommended_jobs:
        return {"error": "No jobs found for this recommendation."}

    user_data = get_user_skills_knowledge(user_test_id)
    results = []

    for job in recommended_jobs:
        try:
            # Check if charts already exist for this attempt
            existing_charts = get_job_charts(rec_id, job["job_index"], attempt_number)
            if existing_charts:
                print(f"[DEBUG] Charts already exist for job {job['job_index']}, skipping generation.")
                results.append(
                    {
                        "rec_id": rec_id,
                        "job_index": job["job_index"],
                        "charts": existing_charts,
                    }
                )
                continue

            job_skills_raw = job.get("required_skills") or {}
            user_skills_raw = user_data.get("skills") or {}

            skills = list(job_skills_raw.keys())
            required_level = [
                normalize_level(job_skills_raw.get(skill, 0)) for skill in skills
            ]
            user_level = [
                normalize_level(
                    user_skills_raw.get(skill)
                    or user_skills_raw.get(skill.lower())
                    or user_skills_raw.get(skill.title())
                    or 0
                )
                for skill in skills
            ]

            # Process Knowledge
            job_knowledge_raw = job.get("required_knowledge") or {}
            user_knowledge_raw = user_data.get("knowledge") or {}
            
            knowledge_list = list(job_knowledge_raw.keys())
            required_knowledge_level = [
                normalize_level(job_knowledge_raw.get(k, 0)) for k in knowledge_list
            ]
            user_knowledge_level = [
                normalize_level(
                    user_knowledge_raw.get(k)
                    or user_knowledge_raw.get(k.lower())
                    or user_knowledge_raw.get(k.title())
                    or 0
                ) 
                for k in knowledge_list
            ]

            radar_chart_base64 = generate_skills_radar_chart(skills, user_level, required_level)
            knowledge_chart_base64 = generate_knowledge_radar_chart(knowledge_list, user_knowledge_level, required_knowledge_level)

            test_performance = calculate_test_performance(user_test_id, attempt_number)
            result_chart = generate_bar_chart(test_performance)

            charts_data = {
                "radar_chart": radar_chart_base64,
                "knowledge_radar_chart": knowledge_chart_base64,
                "result_chart": result_chart,
            }

            save_job_charts(rec_id, job["job_index"], charts_data)

            results.append(
                {
                    "rec_id": rec_id,
                    "job_index": job["job_index"],
                    "charts": charts_data,
                }
            )
        except Exception as e:
            print(f"[ERROR] Failed to generate charts for job {job.get('job_index')}: {e}")
            import traceback
            traceback.print_exc()
            continue

    return results
