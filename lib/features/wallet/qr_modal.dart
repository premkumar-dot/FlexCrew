import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class QRModal extends StatelessWidget {
  final String? qrImage;
  final String? paymentUrl;

  const QRModal({super.key, this.qrImage, this.paymentUrl});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('PayNow (bank direct)'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (qrImage != null)
              Image.network(qrImage!, width: 220, height: 220, fit: BoxFit.contain)
            else
              const Text('No QR available'),
            const SizedBox(height: 12),
            if (paymentUrl != null)
              ElevatedButton(
                onPressed: () async {
                  final uri = Uri.parse(paymentUrl!);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open URL')));
                  }
                },
                child: const Text('Open Payment URL'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }
}
