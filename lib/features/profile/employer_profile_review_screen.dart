import 'package:flutter/material.dart';

class EmployerProfileReviewScreen extends StatelessWidget {
  const EmployerProfileReviewScreen({super.key, required this.data});

  final Map<String, dynamic> data;

  String _display(String? v) => (v == null || v.trim().isEmpty) ? '—' : v.trim();

  @override
  Widget build(BuildContext context) {
    final logo = data['logoUrl'] as String?;
    return Scaffold(
      appBar: AppBar(title: const Text('Review employer profile'), backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 0.5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: logo != null && logo.isNotEmpty
                ? SizedBox(
                    width: 96,
                    height: 96,
                    child: ClipOval(
                      child: Container(
                        color: Colors.transparent,
                        alignment: Alignment.center,
                        child: Image.network(
                          logo,
                          fit: BoxFit.contain,
                          width: 96,
                          height: 96,
                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 36),
                        ),
                      ),
                    ),
                  )
                : const ClipOval(child: SizedBox(width: 96, height: 96, child: Icon(Icons.business, size: 40))),
          ),
          const SizedBox(height: 16),
          ListTile(leading: const Icon(Icons.business), title: const Text('Company'), subtitle: Text(_display(data['companyName'] as String?))),
          ListTile(leading: const Icon(Icons.person), title: const Text('Contact'), subtitle: Text(_display(data['contactName'] as String?))),
          ListTile(leading: const Icon(Icons.phone), title: const Text('Phone'), subtitle: Text(_display(data['phone'] as String?))),
          ListTile(leading: const Icon(Icons.home), title: const Text('Address'), subtitle: Text(_display(data['address'] as String?))),
          ListTile(leading: const Icon(Icons.web), title: const Text('Website'), subtitle: Text(_display(data['website'] as String?))),
          ListTile(leading: const Icon(Icons.description), title: const Text('Description'), subtitle: Text(_display(data['description'] as String?))),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Confirm & Submit'),
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Back to edit')),
        ]),
      ),
    );
  }
}
