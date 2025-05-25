import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class ResourcesPage extends StatefulWidget {
  const ResourcesPage({super.key});

  @override
  State<ResourcesPage> createState() => _ResourcesPageState();
}

class _ResourcesPageState extends State<ResourcesPage> {
  final List<YoutubePlayerController> _controllers = [];

  @override
  void initState() {
    super.initState();
    _initializeYoutubeControllers();
  }

  void _initializeYoutubeControllers() {
    final videoIds = [
      'KVpxP3ZZtAc', // Basic Self-Defense
      '9W_33GrFB8I', // Street Safety
      'h8uT6GiWe6Q', // Safety Devices
    ];

    for (final videoId in videoIds) {
      final controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          hideControls: false,
          hideThumbnail: false,
          enableCaption: true,
        ),
      );
      _controllers.add(controller);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $url');
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildEmergencyContact(
    String name,
    String number,
    String description,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
          ],
        ),
        trailing: TextButton(
          onPressed: () => launchUrl(Uri.parse('tel:$number')),
          style: TextButton.styleFrom(
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Colors.black),
            ),
          ),
          child: Text(
            number,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoResource(String title, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            child: YoutubePlayer(
              controller: _controllers[index],
              showVideoProgressIndicator: true,
              progressIndicatorColor: Colors.black,
              progressColors: const ProgressBarColors(
                playedColor: Colors.black,
                handleColor: Colors.black,
              ),
              onReady: () {
                print('Player is ready.');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsefulLink(String title, String description, String url) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black12),
      ),
      child: InkWell(
        onTap: () => _launchURL(url),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety Resources')),
      body: ListView(
        children: [
          _buildSectionTitle('Emergency Contacts'),
          _buildEmergencyContact(
            'Emergency Services',
            '911',
            'For immediate emergency assistance',
          ),
          _buildEmergencyContact(
            'National Emergency Hotline',
            '112',
            'Alternative emergency number',
          ),
          _buildEmergencyContact(
            'Women\'s Helpline',
            '1091',
            'National helpline for women in distress',
          ),

          _buildSectionTitle('Safety Tutorial Videos'),
          _buildVideoResource('Basic Self-Defense Techniques for Women', 0),
          _buildVideoResource('Street Safety Tips & Awareness', 1),
          _buildVideoResource('How to Use Personal Safety Devices', 2),

          _buildSectionTitle('Useful Links'),
          _buildUsefulLink(
            'Personal Safety Guidelines',
            'Comprehensive guide for personal safety and awareness',
            'https://www.wikihow.com/Be-Safe-While-Walking',
          ),
          _buildUsefulLink(
            'Safety Apps Directory',
            'List of recommended personal safety applications',
            'https://www.safety.com/personal-safety-apps/',
          ),
          _buildUsefulLink(
            'Local Safety Resources',
            'Find safety resources in your area',
            'https://www.safecity.in',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
