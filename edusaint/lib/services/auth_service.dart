import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = "https://byte.edusaint.in/api/v1/auth";

  // ================= STUDENT OTP BASE =================
  static const String studentOtpBase =
      "https://byte.edusaint.in/api/v1/auth/student";

  // -------------------- LOGIN --------------------
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final url = Uri.parse("$baseUrl/login");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      print("LOGIN STATUS: ${response.statusCode}");
      print("LOGIN RESPONSE: ${response.body}");

      final decoded = _safeDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (decoded["data"] != null) {
          return {"success": true, "data": decoded["data"]};
        } else {
          return {"success": true, "data": decoded};
        }
      } else {
        return {
          "success": false,
          "message": decoded["message"] ?? "Login failed. Try again.",
        };
      }
    } catch (e) {
      return {"success": false, "message": "Network Error: $e"};
    }
  }

  // -------------------- SIGNUP --------------------
  static Future<Map<String, dynamic>> signup(
    String email,
    String password,
  ) async {
    final url = Uri.parse("$baseUrl/register");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      print("SIGNUP STATUS: ${response.statusCode}");
      print("SIGNUP RESPONSE: ${response.body}");

      final decoded = _safeDecode(response.body);

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 202) {
        return {"success": true, "data": decoded};
      } else {
        return {
          "success": false,
          "message": decoded["message"] ?? "Signup failed. Try again.",
        };
      }
    } catch (e) {
      return {"success": false, "message": "Network Error: $e"};
    }
  }

  // ==================== FORGOT PASSWORD FLOW ====================

  // -------------------- SEND OTP --------------------
  static Future<Map<String, dynamic>> sendOtp(String email) async {
    final url = Uri.parse("$baseUrl/forgot-password");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );

      final decoded = _safeDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {"success": true, "data": decoded};
      } else {
        return {
          "success": false,
          "message": decoded["message"] ?? "Failed to send OTP",
        };
      }
    } catch (e) {
      return {"success": false, "message": "Network Error: $e"};
    }
  }

  // -------------------- VERIFY OTP --------------------
  static Future<Map<String, dynamic>> verifyOtp(
    String email,
    String otp,
  ) async {
    final url = Uri.parse("$baseUrl/verify-otp");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "otp": otp}),
      );

      final decoded = _safeDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {"success": true, "data": decoded};
      } else {
        return {
          "success": false,
          "message": decoded["message"] ?? "Invalid OTP",
        };
      }
    } catch (e) {
      return {"success": false, "message": "Network Error: $e"};
    }
  }

  // -------------------- RESET PASSWORD --------------------
  static Future<Map<String, dynamic>> resetPassword(
    String email,
    String newPassword,
  ) async {
    final url = Uri.parse("$baseUrl/reset-password");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": newPassword}),
      );

      final decoded = _safeDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {"success": true, "data": decoded};
      } else {
        return {
          "success": false,
          "message": decoded["message"] ?? "Password reset failed",
        };
      }
    } catch (e) {
      return {"success": false, "message": "Network Error: $e"};
    }
  }

  // ==================== NEW: STUDENT OTP LOGIN ====================

  // -------------------- SEND LOGIN OTP --------------------
  static Future<Map<String, dynamic>> sendLoginOtp(String email) async {
    final url = Uri.parse("$baseUrl/forgot-password");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );

      final decoded = _safeDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {"success": true, "data": decoded};
      } else {
        return {
          "success": false,
          "message": decoded["message"] ?? "Failed to send OTP",
        };
      }
    } catch (e) {
      return {"success": false, "message": "Network Error: $e"};
    }
  }

  // -------------------- VERIFY LOGIN OTP --------------------
  static Future<Map<String, dynamic>> verifyLoginOtp(
    String email,
    String otp,
  ) async {
    final url = Uri.parse("$studentOtpBase/login-otp");

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "email": email,
          // ya "code" if backend expects
        }),
      );

      print("LOGIN OTP VERIFY RESPONSE: ${response.body}");

      final decoded = _safeDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {"success": true, "data": decoded};
      } else {
        return {
          "success": false,
          "message": decoded["message"] ?? "Invalid OTP",
        };
      }
    } catch (e) {
      return {"success": false, "message": "Network Error: $e"};
    }
  }

  // -------------------- SAFE JSON DECODER --------------------
  static dynamic _safeDecode(String response) {
    try {
      return jsonDecode(response);
    } catch (_) {
      return {"message": response};
    }
  }
}
