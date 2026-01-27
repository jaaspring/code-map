class UserResponses {
  String educationLevel;
  String cgpa;
  String thesisTopic;
  String major;
  List<String> programmingLanguages;
  String courseworkExperience;
  String skillReflection;
  String thesisFindings;
  String careerGoals;
  String? userTestId;

  UserResponses({
    this.educationLevel = '',
    this.cgpa = '',
    this.thesisTopic = '',
    this.major = '',
    List<String>? programmingLanguages,
    this.courseworkExperience = '',
    this.skillReflection = '',
    this.thesisFindings = '',
    this.careerGoals = '',
    this.userTestId,
    required Map<String, String> followUpAnswers,
  }) : programmingLanguages = programmingLanguages ?? [];

  Map<String, dynamic> toJson() => {
        "educationLevel": educationLevel,
        "cgpa": double.tryParse(cgpa),
        "thesisTopic": thesisTopic,
        "major": major,
        "programmingLanguages": programmingLanguages,
        "courseworkExperience": courseworkExperience,
        "skillReflection": skillReflection,
        "thesisFindings": thesisFindings,
        "careerGoals": careerGoals,
        "userTestId": userTestId,
      };

  factory UserResponses.fromJson(Map<String, dynamic> json) {
    return UserResponses(
      educationLevel: json['educationLevel'] as String? ?? '',
      cgpa: json['cgpa']?.toString() ?? '',
      thesisTopic: json['thesisTopic'] as String? ?? '',
      major: json['major'] as String? ?? '',
      programmingLanguages:
          (json['programmingLanguages'] as List<dynamic>?)?.map((e) => e as String).toList(),
      courseworkExperience: json['courseworkExperience'] as String? ?? '',
      skillReflection: json['skillReflection'] as String? ?? '',
      thesisFindings: json['thesisFindings'] as String? ?? '',
      careerGoals: json['careerGoals'] as String? ?? '',
      userTestId: json['userTestId'] as String?,
      followUpAnswers: {}, // Initialize empty as it's not currently persisted in basic flow
    );
  }
}

// Global shared object
UserResponses globalUserResponses = UserResponses(followUpAnswers: {});
