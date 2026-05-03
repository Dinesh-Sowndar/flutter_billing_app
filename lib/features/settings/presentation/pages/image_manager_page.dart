import 'dart:io';

import 'package:flutter/material.dart';
import 'package:billing_app/core/services/image_service.dart';
import 'package:billing_app/core/service_locator.dart';

class ImageManagerPage extends StatefulWidget {
  const ImageManagerPage({super.key});

  @override
  State<ImageManagerPage> createState() => _ImageManagerPageState();
}

class _ImageManagerPageState extends State<ImageManagerPage> {
  List<String> _images = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() => _loading = true);
    final images = await sl<ImageService>().listSavedImages();
    setState(() {
      _images = images;
      _loading = false;
    });
  }

  Future<void> _deleteImage(String path) async {
    final ok = await sl<ImageService>().deleteImage(path);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image supprimée')),
      );
      await _loadImages();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de supprimer l\'image')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des images'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _images.isEmpty
              ? Center(
                  child: Text('Aucune image trouvée',
                      style: TextStyle(color: Colors.grey[600])),
                )
              : RefreshIndicator(
                  onRefresh: _loadImages,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _images.length,
                    itemBuilder: (context, index) {
                      final path = _images[index];
                      return GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.file(File(path)),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: const Text('Fermer'),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed: () async {
                                          Navigator.of(context).pop();
                                          await _deleteImage(path);
                                        },
                                        child: const Text('Supprimer',
                                            style:
                                                TextStyle(color: Colors.red)),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child:
                                    Image.file(File(path), fit: BoxFit.cover),
                              ),
                            ),
                            Positioned(
                              right: 6,
                              top: 6,
                              child: GestureDetector(
                                onTap: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Confirmer'),
                                      content:
                                          const Text('Supprimer cette image ?'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.of(context)
                                                    .pop(false),
                                            child: const Text('Annuler')),
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            child: const Text('Supprimer',
                                                style: TextStyle(
                                                    color: Colors.red))),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) await _deleteImage(path);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(20)),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(Icons.delete,
                                      size: 18, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
