// calls APIs, sends HTTP requests, and receives responses.

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

  // submit the initial test and return the generated userTestId
  static Future<String> submitTest(UserResponses responses) async {
    final url = Uri.parse("$baseUrl/submit-test");
    final response = await _requestWithRetry(() => http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(responses.toJson()), // Send new structure
        ));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      print("Submit Success: $decoded");
      
      // Check for various possible key names
      final id = decoded['id'] ?? decoded['userTestId'] ?? decoded['user_test_id'];
      
      if (id != null) {
        return id.toString();
      } else {
        print("WARNING: No ID found in response: ${response.body}");
        return "N/A";
      }
    } else {
      throw Exception("Submit Error: ${response.statusCode} ${response.body}");
    }
  }

  // generate questions
  static Future<List<Map<String, dynamic>>> generateQuestions({
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
  }) async {
    final url = Uri.parse("$baseUrl/user-profile-match");
    final body = {
      "user_test_id": userTestId,
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
  }) async {
    // add cache-busting parameter to prevent stale data
    final url = Uri.parse("$baseUrl/gap-analysis/$userTestId")
        .replace(queryParameters: {
      '_t': DateTime.now().millisecondsSinceEpoch.toString(),
      'attempt_refresh': 'true' // explicit flag for backend
    });

    final response = await _requestWithRetry(() => http.post(
          url,
          headers: {
            "Content-Type": "application/json",
            "Cache-Control": "no-cache, no-store, must-revalidate",
            "Pragma": "no-cache",
          },
        ));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      print('=== GAP ANALYSIS DEBUG ===');
      print('Requested userTestId: $userTestId');
      print('Response status: ${response.statusCode}');
      print('Response body type: ${decoded.runtimeType}');
      print(
          'Response keys: ${decoded is Map ? decoded.keys.toList() : "Not a Map"}');

      // check if backend returned an error message
      if (decoded is Map && decoded.containsKey('error')) {
        final errorMsg = decoded['error'];
        print('BACKEND ERROR: $errorMsg');
        throw Exception("Backend gap analysis error: $errorMsg");
      }

      // Check if data is empty or has wrong structure
      if (decoded is Map &&
          decoded.containsKey('data') &&
          decoded['data'] == null) {
        print('WARNING: Backend returned null data field');
        return [];
      }

      print('=== END DEBUG ===');

      // handle both possible response formats
      List<dynamic> dataList;

      if (decoded is Map && decoded.containsKey('data')) {
        final data = decoded['data'];
        if (data is List) {
          dataList = data;
        } else if (data == null) {
          print('WARNING: data field is null, returning empty list');
          return [];
        } else {
          throw Exception(
              "Expected 'data' to be a List or null, got ${data.runtimeType}");
        }
      } else if (decoded is List) {
        dataList = decoded;
      } else if (decoded is Map) {
        // If it's a Map but not an error, treat as single item
        dataList = [decoded];
      } else {
        throw Exception("Unexpected response format: ${decoded.runtimeType}");
      }

      // validate data quality
      if (dataList.isEmpty) {
        print('WARNING: Gap analysis returned empty list');
        return [];
      }

      // convert and validate each item has job_index
      final result = dataList.map<Map<String, dynamic>>((item) {
        final map = Map<String, dynamic>.from(item);
        if (map['job_index'] == null) {
          print('WARNING: Gap item missing job_index: $map');
        }
        return map;
      }).toList();

      print('Successfully parsed ${result.length} gap entries');
      return result;
    } else {
      throw Exception(
          "Error fetching gap analysis: ${response.statusCode} ${response.body}");
    }
  }

  static Future<Map<String, dynamic>> getSingleGapAnalysis({
    required String userTestId,
    required String jobIndex,
    required int attemptNumber,
  }) async {
    try {
      print("DEBUG ApiService: Calling gap analysis endpoint");
      print(
          "DEBUG ApiService: URL: $baseUrl/gap-analysis/$userTestId/$jobIndex?attempt=$attemptNumber");

      final response = await http.get(
        Uri.parse(
            '$baseUrl/gap-analysis/$userTestId/$jobIndex?attempt=$attemptNumber'),
      );

      print("DEBUG ApiService: Response status: ${response.statusCode}");
      print("DEBUG ApiService: Response body: ${response.body}");

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print("DEBUG ApiService: Error response: ${response.body}");
        throw Exception(
            'Failed to fetch gap analysis for job: ${response.statusCode}');
      }
    } catch (e, s) {
      print("DEBUG ApiService: Exception: $e");
      print("DEBUG ApiService: Stack: $s");
      rethrow;
    }
  }

  // get charts for all jobs
  static Future<List<Map<String, dynamic>>> generateCharts({
    required String userTestId,
    required int attemptNumber,
  }) async {
    final url = Uri.parse("$baseUrl/generate-charts/$userTestId");

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

    print('DEBUG: Generating career roadmaps for: $userTestId');
    final response = await http.post(url);

    print('DEBUG: Generate roadmap status: ${response.statusCode}');
    print('DEBUG: Generate roadmap body: ${response.body}');

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded.containsKey('error')) {
        throw Exception("Backend error: ${decoded['error']}");
      }
      return decoded;
    } else {
      throw Exception(
          "Failed to generate career roadmaps: ${response.statusCode}");
    }
  }

// retrieve Career Roadmap Report for this user and job index
  static Future<Map<String, dynamic>> getCareerRoadmap(
      String userTestId, String jobIndex) async {
    final url =
        Uri.parse("$baseUrl/career-roadmap-retrieval/$userTestId/$jobIndex");

    print('DEBUG: Fetching roadmap for: $userTestId, job: $jobIndex');
    final response = await http.get(url);

    print('DEBUG: Get roadmap status: ${response.statusCode}');
    print('DEBUG: Get roadmap body: ${response.body}');

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      // Check for error from backend
      if (decoded.containsKey('error')) {
        throw Exception("Backend error: ${decoded['error']}");
      }
      return decoded;
    } else {
      throw Exception("Failed to load roadmap: ${response.statusCode}");
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
