import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/follow_up_responses.dart';
import '../models/user_profile_match.dart';
import '../models/user_responses.dart';

class ApiService {
  static Future<http.Response> _requestWithRetry(
    Future<http.Response> Function() request, {
    int maxRetries = 3,
  }) async {
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        print('API Attempt ${attempt + 1}');
        final response = await request().timeout(const Duration(seconds: 30));
        return response;
      } catch (e) {
        attempt++;
        print('API Attempt $attempt failed: $e');

        if (attempt >= maxRetries) rethrow;
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    throw Exception('Max retries exceeded');
  }

  static final String baseUrl =
      dotenv.env['BASE_URL'] ?? "http://localhost:8000";

  // Submit the initial test and return the generated userTestId (String)
  static Future<String> submitTest(UserResponses responses) async {
    final url = Uri.parse("$baseUrl/submit-test");

    final response = await _requestWithRetry(() => http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(responses.toJson()),
        ));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      print("Submit Success: $decoded");
      return decoded['id'] as String; // Firebase IDs are strings
    } else {
      throw Exception("Submit Error: ${response.statusCode} ${response.body}");
    }
  }

  // Generate questions
  static Future<List<Map<String, dynamic>>> generateQuestions({
    required String skillReflection,
    required String thesisFindings,
    required String careerGoals,
    required String userTestId,
  }) async {
    final url = Uri.parse("$baseUrl/generate-questions");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"user_test_id": userTestId}),
    );

    print("Raw questions response body: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      if (decoded is Map && decoded.containsKey('questions')) {
        final rawQuestions = decoded['questions'];
        if (rawQuestions is List) {
          return rawQuestions
              .where((q) => q != null && q is Map)
              .map((q) => Map<String, dynamic>.from(q))
              .map((q) {
            if (q['options'] == null ||
                (q['options'] is List && q['options'].isEmpty)) {
              q['options'] = ["Option A", "Option B", "Option C", "Option D"];
            }
            return q;
          }).toList();
        }
      }

      if (decoded.containsKey('error')) throw Exception(decoded['error']);
      throw Exception("Unexpected response format");
    } else {
      throw Exception("Error generating questions: ${response.body}");
    }
  }

  // Send follow-up answers to backend
  static Future<void> submitFollowUpResponses({
    required FollowUpResponses responses,
  }) async {
    final url = Uri.parse("$baseUrl/submit-follow-up");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(responses.toJson()),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      print("Follow-up Submit Success: $decoded");
    } else {
      throw Exception(
          "Follow-up Submit Error: ${response.statusCode} ${response.body}");
    }
  }

  // Get user profile and job match
  static Future<UserProfileMatchResponse?> getUserProfileMatch({
    required String userTestId,
    String? skillReflection,
  }) async {
    final url = Uri.parse("$baseUrl/user-profile-match");

    final body = {
      "user_test_id": userTestId,
      if (skillReflection != null) "skillReflection": skillReflection,
    };

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return UserProfileMatchResponse.fromJson(decoded);
    } else {
      print("Error ${response.statusCode}: ${response.body}");
      return null;
    }
  }

  // Get skill and knowledge gap analysis for all jobs
  static Future<List<Map<String, dynamic>>> getGapAnalysis({
    required String userTestId,
  }) async {
    final url = Uri.parse("$baseUrl/gap-analysis/all/$userTestId");

    final response = await _requestWithRetry(() => http.post(
          url,
          headers: {"Content-Type": "application/json"},
        ));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      // Extract the 'data' list from the backend response
      if (decoded is Map && decoded.containsKey('data')) {
        final data = decoded['data'];
        if (data is List) {
          // Ensure each item is a Map<String, dynamic>
          return data.map<Map<String, dynamic>>((item) {
            return Map<String, dynamic>.from(item);
          }).toList();
        }
        throw Exception(
            "Expected 'data' to be a List, but got: ${data.runtimeType}");
      }

      throw Exception(
          "Unexpected response format for all gap analysis: ${decoded.runtimeType}");
    } else {
      throw Exception(
          "Error fetching gap analysis: ${response.statusCode} ${response.body}");
    }
  }

  // Get charts for all jobs
  static Future<List<Map<String, dynamic>>> getCharts({
    required String userTestId,
  }) async {
    final url = Uri.parse("$baseUrl/generate-charts/all/$userTestId");

    final response = await _requestWithRetry(() => http.post(
          url,
          headers: {"Content-Type": "application/json"},
        ));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      // Extract the 'data' list from the backend response
      if (decoded is Map && decoded.containsKey('data')) {
        final data = decoded['data'];
        if (data is List) {
          // Ensure each item is a Map<String, dynamic>
          return data.map<Map<String, dynamic>>((item) {
            return Map<String, dynamic>.from(item);
          }).toList();
        }
        throw Exception(
            "Expected 'data' to be a List, but got: ${data.runtimeType}");
      }
      throw Exception(
          "Unexpected response format for all charts: ${decoded.runtimeType}");
    } else {
      throw Exception(
          "Error fetching charts: ${response.statusCode} ${response.body}");
    }
  }

// Retrieve Report
  static Future<Map<String, dynamic>> generateReport(
      String userTestId, String jobIndex) async {
    final url = Uri.parse("$baseUrl/report-retrieval/$userTestId/$jobIndex");

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to load report: ${response.statusCode}");
    }
  }

  // Generate Career Roadmap
  static Future<Map<String, dynamic>> generateCareerRoadmap(
      String userTestId, String jobIndex) async {
    final url =
        Uri.parse("$baseUrl/career-roadmap-generation/$userTestId/$jobIndex");

    final response = await http.post(url);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to load career roadmap: ${response.statusCode}");
    }
  }
}
