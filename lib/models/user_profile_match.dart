class JobMatch {
  final String userTestId;
  final String jobIndex;
  final double similarityScore;
  final double similarityPercentage;
  final String jobTitle;
  final String jobDescription;
  Map<String, dynamic>? requiredSkills;
  Map<String, dynamic>? requiredKnowledge;
  Map<String, dynamic>? chartData;
  final Map<String, dynamic>? comparison;

  String? dbJobIndex;

  JobMatch({
    required this.userTestId,
    required this.jobIndex,
    required this.similarityScore,
    required this.similarityPercentage,
    required this.jobTitle,
    required this.jobDescription,
    this.requiredSkills,
    this.requiredKnowledge,
    this.chartData,
    this.comparison,
  });

  factory JobMatch.fromJson(Map<String, dynamic> json) => JobMatch(
        userTestId: json["user_test_id"]?.toString() ?? 'N/A',
        jobIndex: json["job_index"]?.toString() ?? 'N/A',
        similarityScore: (json["similarity_score"] as num?)?.toDouble() ?? 0.0,
        similarityPercentage:
            (json["similarity_percentage"] as num?)?.toDouble() ?? 0.0,
        jobTitle: json["job_title"] as String? ?? 'N/A',
        jobDescription: json["job_description"] as String? ?? 'N/A',
        requiredSkills:
            (json["required_skills"] as Map<String, dynamic>?) ?? {},
        requiredKnowledge:
            (json["required_knowledge"] as Map<String, dynamic>?) ?? {},
        chartData: json["chart_data"] as Map<String, dynamic>?,
        comparison: json["comparison"] as Map<String, dynamic>?,
      );
}

class UserProfileMatchResponse {
  final String profileText;
  final List<JobMatch> topMatches;

  UserProfileMatchResponse({
    required this.profileText,
    required this.topMatches,
  });

  factory UserProfileMatchResponse.fromJson(Map<String, dynamic> json) {
    List<JobMatch> matches = [];

    final topMatchesRaw = json['top_matches'];
    if (topMatchesRaw is List) {
      matches = topMatchesRaw
          .map((e) => JobMatch.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (topMatchesRaw is Map<String, dynamic>) {
      matches = [JobMatch.fromJson(topMatchesRaw)];
    } else {
      matches = [];
    }

    return UserProfileMatchResponse(
      profileText: json["profile_text"] as String? ?? "Gap analysis",
      topMatches: matches,
    );
  }
}
