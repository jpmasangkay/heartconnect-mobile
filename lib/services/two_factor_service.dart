import 'api_service.dart';

class TwoFactorService extends ApiService {
  /// Set up 2FA. [method] is 'totp' or 'email'.
  /// For TOTP, returns { secret, qrCodeUrl, method }.
  /// For email, returns { message, method }.
  Future<Map<String, dynamic>> setup(String method) async {
    final res = await dio.post('/auth/2fa/setup', data: {'method': method});
    return res.data as Map<String, dynamic>;
  }

  /// Verify a TOTP code during setup to enable 2FA.
  Future<void> verifySetup(String code) async {
    await dio.post('/auth/2fa/verify-setup', data: {'code': code});
  }

  /// Verify 2FA code during login.
  /// Returns { token, user } on success.
  Future<Map<String, dynamic>> verify(String tempToken, String code) async {
    final res = await dio.post('/auth/2fa/verify', data: {
      'tempToken': tempToken,
      'code': code,
    });
    return res.data as Map<String, dynamic>;
  }

  /// Disable 2FA. Requires password and (for TOTP) a current code.
  Future<void> disable(String password, {String? code}) async {
    await dio.post('/auth/2fa/disable', data: {
      'password': password,
      if (code != null) 'code': code,
    });
  }

  /// Send email code for email-based 2FA during login.
  Future<void> sendEmailCode(String tempToken) async {
    await dio.post('/auth/2fa/send-email-code', data: {
      'tempToken': tempToken,
    });
  }
}
