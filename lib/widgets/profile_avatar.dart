import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers.dart';
import '../theme/astra_theme.dart';

/// The user's face at the top of the home screen, with a camera badge.
///
/// Falls back to the first letter of their name, which is why the ring and the
/// badge are drawn the same either way: an empty avatar should look like a
/// deliberate placeholder rather than a photo that failed to load.
///
/// The picked image is downscaled to 512px before it is stored. A modern phone
/// camera produces several megabytes, all of it thrown away by a 96px circle,
/// and the decoded copy is held in memory for the life of the app.
class ProfileAvatar extends ConsumerStatefulWidget {
  const ProfileAvatar({super.key, required this.name, this.size = 96});

  final String name;
  final double size;

  @override
  ConsumerState<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends ConsumerState<ProfileAvatar> {
  bool _picking = false;

  Future<void> _pick() async {
    if (_picking) return;
    setState(() => _picking = true);

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 82,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      await ref.read(avatarProvider.notifier).set(bytes);
    } catch (error) {
      // A picker that is unavailable — no gallery, permission refused, a
      // desktop without a photo library — is not worth an error dialog over a
      // decorative photo. The avatar simply stays as it was.
      debugPrint('Mayow: could not pick a profile photo — $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open your photos.')),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = ref.watch(avatarProvider);
    final initial = widget.name.isEmpty ? '★' : widget.name[0].toUpperCase();
    final badge = widget.size * 0.3;

    return Semantics(
      button: true,
      label: photo == null ? 'Add a profile photo' : 'Change your profile photo',
      child: GestureDetector(
        onTap: _pick,
        child: SizedBox(
          width: widget.size + badge / 2,
          height: widget.size,
          child: Stack(
            children: [
              Container(
                width: widget.size,
                height: widget.size,
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AstraColors.cardRaised,
                  border: Border.all(
                    color: AstraColors.accent.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: photo == null
                    ? Text(
                        initial,
                        style: AstraTextStyles.display(
                          widget.size * 0.38,
                          color: AstraColors.accent,
                        ),
                      )
                    : Image.memory(
                        photo,
                        width: widget.size,
                        height: widget.size,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
              ),
              Positioned(
                right: 0,
                bottom: widget.size * 0.06,
                child: Container(
                  width: badge,
                  height: badge,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AstraColors.canvasRaised,
                    border: Border.all(color: AstraColors.line),
                  ),
                  child: _picking
                      ? SizedBox(
                          width: badge * 0.42,
                          height: badge * 0.42,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AstraColors.accent,
                          ),
                        )
                      : Icon(
                          Icons.photo_camera_rounded,
                          size: badge * 0.52,
                          color: AstraColors.accent,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
