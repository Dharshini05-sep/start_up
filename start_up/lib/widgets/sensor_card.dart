import 'package:flutter/material.dart';

enum SensorType {
  temperature,
  humidity,
}

class SensorCard extends StatelessWidget {
  final SensorType type;
  final double? value;
  final bool isConnected;

  const SensorCard({
    super.key,
    required this.type,
    required this.value,
    this.isConnected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTemp = type == SensorType.temperature;

    final String label = isTemp ? 'Temperature' : 'Humidity';
    final String unit = isTemp ? '°C' : '%';
    final IconData icon = isTemp ? Icons.thermostat_rounded : Icons.water_drop_rounded;

    final Color primaryColor = isTemp
        ? (isConnected ? Colors.orange.shade700 : Colors.grey.shade600)
        : (isConnected ? Colors.blue.shade700 : Colors.grey.shade600);

    final Color cardBg = isTemp
        ? (isConnected ? Colors.orange.shade50 : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3))
        : (isConnected ? Colors.blue.shade50 : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3));

    final String displayValue = value != null ? value!.toStringAsFixed(1) : '--';

    return Expanded(
      child: Card(
        elevation: 0,
        color: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isConnected ? primaryColor.withValues(alpha: 0.3) : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isConnected ? primaryColor.withValues(alpha: 0.15) : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    displayValue,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isConnected ? primaryColor : Colors.grey.shade800,
                      fontSize: 32,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
