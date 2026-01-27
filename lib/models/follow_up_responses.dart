class FollowUpResponse {
  final String questionId;
  String? selectedOption;
  final String userTestId;
  final int attemptNumber;

  FollowUpResponse({
    required this.questionId,
    required this.selectedOption,
    required this.userTestId,
    required this.attemptNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      "questionId": questionId,
      "selectedOption": selectedOption,
      "user_test_id": userTestId, // backend expects snake_case
      "test_attempt": attemptNumber,
    };
  }
}

class FollowUpResponses {
  final List<FollowUpResponse> responses;

  FollowUpResponses({required this.responses});

  Map<String, dynamic> toJson() {
    return {
      "responses": responses.map((r) => r.toJson()).toList(),
    };
  }
}
