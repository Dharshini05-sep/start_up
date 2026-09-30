class SensorReading {
  final double? temperature;
  final double? humidity;
  final DateTime? timestamp;
  final String source; // 'Bluetooth' or 'IP/Wi-Fi'
  final String connectionStatus; // 'Disconnected', 'Scanning', 'Connecting', 'Connected', 'Connection Error'
  final String? userEmail;

  const SensorReading({
    this.temperature,
    this.humidity,
    this.timestamp,
    required this.source,
    required this.connectionStatus,
    this.userEmail,
  });

  bool get hasValidData => temperature != null && humidity != null;

  String get temperatureDisplay =>
      temperature != null ? '${temperature!.toStringAsFixed(1)} °C' : '-- °C';

  String get humidityDisplay =>
      humidity != null ? '${humidity!.toStringAsFixed(1)} %' : '-- %';

  String get formattedTimestamp {
    if (timestamp == null) return 'Not Available';
    final t = timestamp!;
    final year = t.year.toString().padLeft(4, '0');
    final month = t.month.toString().padLeft(2, '0');
    final day = t.day.toString().padLeft(2, '0');
    final hour = t.hour.toString().padLeft(2, '0');
    final min = t.minute.toString().padLeft(2, '0');
    final sec = t.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$min:$sec';
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'timestamp': timestamp?.toIso8601String(),
      'source': source,
      'connectionStatus': connectionStatus,
      'userEmail': userEmail,
    };
  }

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    return SensorReading(
      temperature: (json['temperature'] as num?)?.toDouble(),
      humidity: (json['humidity'] as num?)?.toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
      source: json['source'] as String? ?? 'Bluetooth',
      connectionStatus: json['connectionStatus'] as String? ?? 'Disconnected',
      userEmail: json['userEmail'] as String?,
    );
  }

  factory SensorReading.disconnected({String source = 'Bluetooth'}) {
    return SensorReading(
      temperature: null,
      humidity: null,
      timestamp: null,
      source: source,
      connectionStatus: 'Disconnected',
    );
  }

  SensorReading copyWith({
    double? temperature,
    double? humidity,
    DateTime? timestamp,
    String? source,
    String? connectionStatus,
    String? userEmail,
  }) {
    return SensorReading(
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      userEmail: userEmail ?? this.userEmail,
    );
  }
}
