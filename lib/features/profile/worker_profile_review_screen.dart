import 'package:flutter/material.dart';

class WorkerProfileReviewScreen extends StatelessWidget {
  const WorkerProfileReviewScreen({super.key, required this.data});

  final Map<String, dynamic> data;

  String _display(String? v) => (v == null || v.trim().isEmpty) ? '—' : v.trim();

  Widget _fileTile(BuildContext ctx, String label, String? url) {
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    final lower = url.toLowerCase();
    final isImage = lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.webp');
    return ListTile(
      leading: const Icon(Icons.insert_drive_file),
      title: Text(label),
      subtitle: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () {
        if (isImage) {
          showDialog(
            context: ctx,
            builder: (_) => Dialog(child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain))),
          );
        } else {
          showDialog(
            context: ctx,
            builder: (_) => AlertDialog(
              title: Text(label),
              content: SelectableText(url),
              actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))],
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = data['photoUrl'] as String? ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: avatarUrl.isNotEmpty
                ? CircleAvatar(radius: 48, backgroundImage: NetworkImage(avatarUrl))
                : const CircleAvatar(radius: 48, child: Icon(Icons.person, size: 48)),
          ),
          const SizedBox(height: 16),
          ListTile(leading: const Icon(Icons.person), title: const Text('Full name'), subtitle: Text(_display(data['name'] as String?))),
          ListTile(leading: const Icon(Icons.phone), title: const Text('Phone'), subtitle: Text(_display(data['phone'] as String?))),
          ListTile(leading: const Icon(Icons.chat), title: const Text('WhatsApp'), subtitle: Text(_display(data['whatsapp'] as String?))),
          ListTile(leading: const Icon(Icons.home), title: const Text('Address'), subtitle: Text(_display(data['address'] as String?))),
          ListTile(leading: const Icon(Icons.mail), title: const Text('Postal Code'), subtitle: Text(_display(data['postalCode'] as String?))),
          ListTile(leading: const Icon(Icons.badge), title: const Text('ID Number'), subtitle: Text(_display(data['idNumber'] as String?))),
          ListTile(leading: const Icon(Icons.calendar_today), title: const Text('DOB'), subtitle: Text(_display(data['dob'] as String?))),
          ListTile(leading: const Icon(Icons.wc), title: const Text('Gender'), subtitle: Text(_display(data['gender'] as String?))),
          ListTile(leading: const Icon(Icons.work), title: const Text('Skills'), subtitle: Text(_display(data['skills'] as String?))),
          ListTile(leading: const Icon(Icons.attach_money), title: const Text('Expected rate'), subtitle: Text(_display(data['expectedRate'] as String?))),
          const SizedBox(height: 12),
          const Text('Uploaded files', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          _fileTile(context, 'ID front', data['idFrontUrl'] as String?),
          _fileTile(context, 'ID back', data['idBackUrl'] as String?),
          _fileTile(context, 'Resume', data['resumeUrl'] as String?),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Confirm & Submit'),
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Back to edit'),
          ),
        ]),
      ),
    );
  }
}
