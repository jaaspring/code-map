// calls APIs, sends HTTP requests, and receives responses.

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
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

  // submit the initial test and return the generated userTestId (String)
  static Future<String> submitTest(UserResponses responses) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("User not authenticated");
    }
    final url = Uri.parse("$baseUrl/submit-test");

    final requestData = {
      'responses': responses.toJson(),
      'user_id': user.uid, // add user ID
    };

    final response = await _requestWithRetry(() => http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(requestData), // Send new structure
        ));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      print("Submit Success: $decoded");
      return decoded['id'] as String;
    } else {
      throw Exception("Submit Error: ${response.statusCode} ${response.body}");
    }
  }

  // generate questions
  static Future<List<Map<String, dynamic>>> generateQuestions({
    required String skillReflection,
    required String thesisFindings,
    required String careerGoals,
    required String userTestId,
    required int attemptNumber,
  }) async {
    final url = Uri.parse("$baseUrl/generate-questions");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(
          {"user_test_id": userTestId, "attempt_number": attemptNumber}),
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

  // retrieve generated follow-up questions
  static Future<List<Map<String, dynamic>>> getGeneratedQuestions({
    required String userTestId,
    required int attemptNumber,
  }) async {
    final url = Uri.parse("$baseUrl/get-generated-questions");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "user_test_id": userTestId,
        "attempt_number": attemptNumber,
      }),
    );

    print("Raw follow-up questions response body: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      if (decoded is Map && decoded.containsKey('questions')) {
        final rawQuestions = decoded['questions'];
        if (rawQuestions is List) {
          return rawQuestions
              .where((q) => q != null && q is Map)
              .map((q) => Map<String, dynamic>.from(q))
              .toList();
        }
      }

      if (decoded.containsKey('error')) throw Exception(decoded['error']);
      throw Exception("Unexpected response format");
    } else {
      throw Exception("Error retrieving follow-up questions: ${response.body}");
    }
  }

  // send follow-up answers to backend
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

  // get user profile and job match
  static Future<UserProfileMatchResponse?> getUserProfileMatch({
    required String userTestId,
    String? skillReflection,
  }) async {
    final url = Uri.parse("$baseUrl/user-profile-match");
    final body = {
      "user_test_id": userTestId,
      if (skillReflection != null) "skillReflection": skillReflection,
    };
    print("[DEBUG] Request body: $body");

    try {
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
    } catch (e) {
      print("[DEBUG] Exception: $e");
      return null;
    }
  }

  // get skill and knowledge gap analysis for all jobs
  static Future<List<Map<String, dynamic>>> getGapAnalysis({
    required String userTestId,
    required int attemptNumber,
  }) async {
    final url = Uri.parse("$baseUrl/gap-analysis/all/$userTestId");

    final response = await _requestWithRetry(() => http.post(
          url,
          headers: {"Content-Type": "application/json"},
        ));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      // DEBUG: print what we actually received
      print('Gap analysis raw response: $decoded');
      print('Gap analysis response type: ${decoded.runtimeType}');

      // handle both possible response formats
      List<dynamic> dataList;

      if (decoded is Map && decoded.containsKey('data')) {
        final data = decoded['data'];
        if (data is List) {
          dataList = data;
        } else {
          throw Exception("Expected 'data' to be a List");
        }
      } else if (decoded is List) {
        dataList = decoded;
      } else if (decoded is Map) {
        dataList = [decoded];
      } else {
        throw Exception("Unexpected response format: ${decoded.runtimeType}");
      }

      // convert to List<Map<String, dynamic>>
      return dataList.map<Map<String, dynamic>>((item) {
        return Map<String, dynamic>.from(item);
      }).toList();
    } else {
      throw Exception(
          "Error fetching gap analysis: ${response.statusCode} ${response.body}");
    }
  }

  // get charts for all jobs
  static Future<List<Map<String, dynamic>>> getCharts({
    required String userTestId,
    required int attemptNumber,
  }) async {
    final url = Uri.parse("$baseUrl/generate-charts/all/$userTestId");

    final response = await _requestWithRetry(() => http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({'attempt_number': attemptNumber}),
        ));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      print('=== DEBUG CHARTS RESPONSE ===');
      print('Response type: ${decoded.runtimeType}');
      print('Is Map? ${decoded is Map}');
      if (decoded is Map) {
        print('Map keys: ${decoded.keys.toList()}');
      }

      if (decoded is Map<String, dynamic>) {
        List<Map<String, dynamic>> chartsList = [];

        decoded.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            // add the chart data with its key
            chartsList.add({
              'chartName': key,
              ...value,
            });
          }
        });

        // if we got charts, return them
        if (chartsList.isNotEmpty) {
          return chartsList;
        }

        // if the map itself is the chart data
        // (single chart wrapped in map)
        return [decoded];
      }

      // if it's already a list, just return it
      if (decoded is List) {
        return decoded.map<Map<String, dynamic>>((item) {
          return Map<String, dynamic>.from(item);
        }).toList();
      }

      throw Exception(
          "Unexpected response format for all charts: ${decoded.runtimeType}");
    } else {
      throw Exception(
          "Error fetching charts: ${response.statusCode} ${response.body}");
    }
  }

// retrieve Report
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

  static Future<Map<String, dynamic>> getRecentUserTest(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/$userId/recent-test'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get recent test');
      }
    } catch (e) {
      print('Error getting recent test: $e');
      rethrow;
    }
  }

  // generate Career Roadmaps for all jobs
  static Future<Map<String, dynamic>> generateCareerRoadMaps(
      String userTestId) async {
    final url = Uri.parse("$baseUrl/career-roadmap-generation/all/$userTestId");

    final response = await http.post(url);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to load career roadmap: ${response.statusCode}");
    }
  }

  // retrieve Career Roadmap Report for this user and job index
  static Future<Map<String, dynamic>> getCareerRoadmap(
      String userTestId, String jobIndex) async {
    final url =
        Uri.parse("$baseUrl/career-roadmap-retrieval/$userTestId/$jobIndex");

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to load report: ${response.statusCode}");
    }
  }

  // get all recommended jobs for a user
  static Future<Map<String, dynamic>> getAllRecommendedJobs(
      String userTestId) async {
    final url = Uri.parse("$baseUrl/career-recommendations/$userTestId");

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(
          "Failed to load recommended jobs: ${response.statusCode}");
    }
  }
}
