import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../models/user_model.dart';
import 'storage_service.dart';

class AuthResult {
  final bool success;
  final String? errorMessage;
  final UserModel? user;
  final bool isAdmin;

  const AuthResult({
    required this.success,
    this.errorMessage,
    this.user,
    this.isAdmin = false,
  });

  factory AuthResult.failed(String message) {
    return AuthResult(success: false, errorMessage: message);
  }

  factory AuthResult.ok(UserModel user, {bool isAdmin = false}) {
    return AuthResult(success: true, user: user, isAdmin: isAdmin);
  }
}

class AuthService {
  // Centralized administrator credentials for development / testing
  static const String adminEmail = 'admin@example.com';
  static const String _adminPassword = '123456789';

  static final UserModel _adminUser = UserModel(
    firstName: 'System',
    lastName: 'Admin',
    email: adminEmail,
    accountType: 'Admin',
    passwordHash: '',
    salt: '',
    createdAt: DateTime(2025, 1, 1),
  );

  final IStorageService _storageService;
  UserModel? _currentUser;

  AuthService(this._storageService);

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.email.toLowerCase() == adminEmail.toLowerCase();
  bool get isGuardian => _currentUser?.accountType.toLowerCase() == 'guardian';

  /// Initialize session from stored state if available
  Future<void> initSession() async {
    _currentUser = await _storageService.loadSessionUser();
  }

  /// Securely hashes a password using SHA-256 with a cryptographic salt
  static String _hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }

  /// Generates a secure random 16-byte salt
  static String _generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  /// Sign Up a new Doctor or Guardian account
  Future<AuthResult> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String confirmPassword,
    required String accountType,
  }) async {
    final cleanFirstName = firstName.trim();
    final cleanLastName = lastName.trim();
    final cleanEmail = email.trim().toLowerCase();

    // Validation
    if (cleanFirstName.isEmpty) {
      return AuthResult.failed('First name cannot be empty.');
    }
    if (cleanLastName.isEmpty) {
      return AuthResult.failed('Last name cannot be empty.');
    }
    if (cleanEmail.isEmpty) {
      return AuthResult.failed('Email cannot be empty.');
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(cleanEmail)) {
      return AuthResult.failed('Please enter a valid email address.');
    }
    if (password.isEmpty) {
      return AuthResult.failed('Password cannot be empty.');
    }
    if (password.length < 6) {
      return AuthResult.failed('Password must be at least 6 characters.');
    }
    if (password != confirmPassword) {
      return AuthResult.failed('Passwords do not match.');
    }
    if (accountType != 'Doctor' && accountType != 'Guardian') {
      return AuthResult.failed('Please select a valid account type (Doctor or Guardian).');
    }
    if (cleanEmail == adminEmail.toLowerCase()) {
      return AuthResult.failed('This email is reserved for system administration.');
    }

    // Check existing
    final existingUser = await _storageService.findUserByEmail(cleanEmail);
    if (existingUser != null) {
      return AuthResult.failed('An account with this email already exists.');
    }

    // Create user with salted password hash
    final salt = _generateSalt();
    final passwordHash = _hashPassword(password, salt);

    final newUser = UserModel(
      firstName: cleanFirstName,
      lastName: cleanLastName,
      email: cleanEmail,
      accountType: accountType,
      passwordHash: passwordHash,
      salt: salt,
      createdAt: DateTime.now(),
    );

    final saved = await _storageService.saveUser(newUser);
    if (!saved) {
      return AuthResult.failed('Failed to save account details. Please try again.');
    }

    return AuthResult.ok(newUser);
  }

  /// Login handles both Admin and standard Doctor/Guardian logins
  Future<AuthResult> login({
    required String email,
    required String password,
    required String accountType,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    if (cleanEmail.isEmpty) {
      return AuthResult.failed('Please enter your email.');
    }
    if (password.isEmpty) {
      return AuthResult.failed('Please enter your password.');
    }

    // 1. Check Administrator credentials first
    if (cleanEmail == adminEmail.toLowerCase()) {
      if (password == _adminPassword) {
        _currentUser = _adminUser;
        await _storageService.saveSessionUser(_adminUser);
        return AuthResult.ok(_adminUser, isAdmin: true);
      } else {
        return AuthResult.failed('Invalid administrator password.');
      }
    }

    // 2. Standard User authentication
    final user = await _storageService.findUserByEmail(cleanEmail);
    if (user == null) {
      return AuthResult.failed('No account found with this email address.');
    }

    // Verify account type matches
    if (user.accountType.toLowerCase() != accountType.toLowerCase()) {
      return AuthResult.failed(
        'This account is registered as a ${user.accountType}. Please select "${user.accountType}" as Account Type.',
      );
    }

    // Verify salted password hash
    final computedHash = _hashPassword(password, user.salt);
    if (computedHash != user.passwordHash) {
      return AuthResult.failed('Invalid password. Please try again.');
    }

    _currentUser = user;
    await _storageService.saveSessionUser(user);
    return AuthResult.ok(user, isAdmin: false);
  }

  /// Log out current user session
  Future<void> logout() async {
    _currentUser = null;
    await _storageService.saveSessionUser(null);
  }
}
