import 'dart:io' show File, Platform;
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/prism_surfaces.dart';

// --- Provider ---

final ticketAttachmentsProvider =
    FutureProvider.family<List<AttachmentModel>, String>((ref, ticketId) async {
  final dio = ref.read(apiClientProvider);
  final res = await dio.get<Map<String, dynamic>>('/tickets/$ticketId/attachments');
  final list = res.data!['data'] as List;
  return list.map((e) => AttachmentModel.fromJson(e as Map<String, dynamic>)).toList();
});

// --- Widget ---

class TicketAttachmentsSection extends ConsumerWidget {
  const TicketAttachmentsSection({super.key, required this.ticketId});

  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachmentsAsync = ref.watch(ticketAttachmentsProvider(ticketId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Attachments', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            _UploadButton(
              ticketId: ticketId,
              onUploaded: () => ref.invalidate(ticketAttachmentsProvider(ticketId)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        attachmentsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Failed to load attachments: $e'),
          data: (attachments) => attachments.isEmpty
              ? const Text('No attachments', style: TextStyle(color: Colors.grey))
              : _AttachmentGrid(
                  attachments: attachments,
                  ticketId: ticketId,
                  onDeleted: () => ref.invalidate(ticketAttachmentsProvider(ticketId)),
                ),
        ),
      ],
    );
  }
}

// --- Upload button ---

class _UploadButton extends ConsumerStatefulWidget {
  const _UploadButton({required this.ticketId, required this.onUploaded});
  final String ticketId;
  final VoidCallback onUploaded;

  @override
  ConsumerState<_UploadButton> createState() => _UploadButtonState();
}

class _UploadButtonState extends ConsumerState<_UploadButton> {
  bool _uploading = false;
  static const _maxAttachmentBytes = 10 * 1024 * 1024;

  Future<void> _upload() async {
    String? filePath;
    String? fileName;

    if (Platform.isAndroid) {
      // Android: camera or gallery via image_picker
      final source = await _pickSource();
      if (source == null) return;
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;
      filePath = picked.path;
      fileName = picked.name;
    } else {
      // Windows (and fallback): file picker
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf'],
      );
      if (result == null || result.files.isEmpty) return;
      filePath = result.files.first.path;
      fileName = result.files.first.name;
    }

    if (filePath == null || fileName == null) return;

    final fileSize = await File(filePath).length();
    if (fileSize > _maxAttachmentBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This file is larger than the 10 MB attachment limit.')),
        );
      }
      return;
    }

    setState(() => _uploading = true);
    try {
      final dio = ref.read(apiClientProvider);
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
          contentType: _attachmentContentType(fileName),
        ),
      });
      await dio.post(
        '/tickets/${widget.ticketId}/attachments',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      widget.onUploaded();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_uploadErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _uploadErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      final errorData = data is Map ? data['error'] : null;
      final code = errorData is Map ? errorData['code'] : null;
      return switch (code) {
        'UNSUPPORTED_ATTACHMENT_TYPE' => 'This file type is not supported. Choose an image, PDF, Office document, spreadsheet, or text file.',
        'ATTACHMENT_TOO_LARGE' => 'This file is larger than the attachment size limit.',
        'ATTACHMENT_REQUIRED' => 'Choose a file to upload.',
        _ => 'Upload was interrupted or could not be saved. Please try again.',
      };
    }
    return 'Upload was interrupted or could not be saved. Please try again.';
  }

  DioMediaType _attachmentContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    final mimeType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };
    return DioMediaType.parse(mimeType);
  }

  Future<ImageSource?> _pickSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PrismBackdrop(
        compact: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: PrismSurface(
              radius: 28,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _uploading ? null : _upload,
      icon: _uploading
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.attach_file, size: 18),
      label: const Text('Add'),
    );
  }
}

// --- Attachment grid ---

class _AttachmentGrid extends ConsumerWidget {
  const _AttachmentGrid({
    required this.attachments,
    required this.ticketId,
    required this.onDeleted,
  });

  final List<AttachmentModel> attachments;
  final String ticketId;
  final VoidCallback onDeleted;

  String _fileUrl(AttachmentModel a, String apiBase) {
    // Attachment bytes are authenticated and served from the API.
    return '$apiBase/tickets/$ticketId/attachments/${a.id}/file';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiBase = ref.watch(serverUrlProvider);
    final token = ref.watch(tokenProvider);
    final headers = token == null
        ? const <String, String>{}
        : <String, String>{'Authorization': 'Bearer $token'};

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: attachments.map((a) => _AttachmentTile(
            attachment: a,
            url: _fileUrl(a, apiBase),
            headers: headers,
            onDelete: () async {
              try {
                final dio = ref.read(apiClientProvider);
                await dio.delete('/tickets/$ticketId/attachments/${a.id}');
                onDeleted();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
                }
              }
            },
          )).toList(),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.attachment,
    required this.url,
    required this.headers,
    required this.onDelete,
  });

  final AttachmentModel attachment;
  final String url;
  final Map<String, String> headers;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: () => _showFullScreen(context),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: attachment.isImage
                      ? Image.network(
                          url,
                          headers: headers,
                          width: 120,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _FileIcon(attachment: attachment),
                        )
                      : _FileIcon(attachment: attachment),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            attachment.fileName,
            style: const TextStyle(fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showFullScreen(BuildContext context) {
    if (!attachment.isImage) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(
                url,
                headers: headers,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileIcon extends StatelessWidget {
  const _FileIcon({required this.attachment});
  final AttachmentModel attachment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 90,
      color: Colors.grey.shade200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.insert_drive_file, size: 32, color: Colors.grey),
          Text(
            attachment.fileName.split('.').last.toUpperCase(),
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
