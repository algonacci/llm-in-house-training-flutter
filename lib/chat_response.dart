import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatResponse {
  static const String baseUrl = 'http://192.168.162.247:5000';

  // Regular chat - returns complete response at once
  static Future<String> getChatResponseRegular(String content,
      {String model = 'llama3.2'}) async {
    try {
      const url = '$baseUrl/generate';
      final headers = {
        'Content-Type': 'application/json',
      };
      final body = json.encode({
        'messages': content,
        'model': model,
        'stream': false,
      });

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['message'] ?? 'No response';
        } else {
          return 'Error: ${data['error'] ?? 'Unknown error'}';
        }
      } else {
        return 'Error: HTTP ${response.statusCode}';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  // Streaming chat - yields words as they come
  static Stream<String> getChatResponseStreaming(String content,
      {String model = 'llama3.2'}) async* {
    try {
      const url = '$baseUrl/generate';
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      };
      final body = json.encode({
        'messages': content,
        'model': model,
        'stream': true,
      });

      var request = http.Request('POST', Uri.parse(url))
        ..headers.addAll(headers)
        ..body = body;

      var streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        await for (var line in streamedResponse.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6).trim();
            if (jsonStr.isNotEmpty) {
              try {
                final data = json.decode(jsonStr);
                if (data['error'] != null) {
                  yield '[Error: ${data['error']}]';
                  break;
                } else if (data['done'] == true) {
                  break;
                } else if (data['content'] != null) {
                  yield data['content'];
                }
              } catch (e) {
                // Skip malformed JSON
                continue;
              }
            }
          }
        }
      } else {
        yield 'Error: HTTP ${streamedResponse.statusCode}';
      }
    } catch (e) {
      yield 'Error: $e';
    }
  }

  // Get available models
  static Future<List<String>> getAvailableModels() async {
    try {
      const url = '$baseUrl/models';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data']['models'] != null) {
          return List<String>.from(data['data']['models']);
        }
      }
      return ['llama3.2']; // fallback
    } catch (e) {
      return ['llama3.2']; // fallback
    }
  }

  // Check API health
  static Future<bool> checkHealth() async {
    try {
      const url = baseUrl;
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
