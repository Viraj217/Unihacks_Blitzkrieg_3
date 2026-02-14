import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class TimelineEvent {
  String id;
  String title;
  String date;
  String? imagePath;
  
  TimelineEvent({
    required this.id,
    required this.title,
    required this.date,
    this.imagePath,
  });
}

class TimelinePage extends StatefulWidget {
  const TimelinePage({Key? key}) : super(key: key);

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  final List<TimelineEvent> _events = [
    TimelineEvent(
      id: '1',
      title: 'Sanjay Gandhi National Park',
      date: '12-12-12',
    ),
    TimelineEvent(
      id: '2',
      title: 'Sanjay Gandhi National Park',
      date: '12-12-12',
    ),
    TimelineEvent(
      id: '3',
      title: 'Sanjay Gandhi National Park',
      date: '12-12-12',
    ),
    TimelineEvent(
      id: '4',
      title: 'Sanjay Gandhi National Park',
      date: '12-12-12',
    ),
  ];

  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2D1B4E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D1B4E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Timeline',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _events.length,
        itemBuilder: (context, index) {
          return _buildTimelineItem(_events[index], index);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewEvent,
        backgroundColor: const Color(0xFF6B4C9A),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTimelineItem(TimelineEvent event, int index) {
    final bool isLeft = index % 2 == 0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLeft) ...[
            _buildEventCard(event, isLeft),
            const SizedBox(width: 16),
            _buildTimelineLine(index),
          ] else ...[
            _buildTimelineLine(index),
            const SizedBox(width: 16),
            _buildEventCard(event, isLeft),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineLine(int index) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF4A3468),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF6B4C9A), width: 2),
          ),
        ),
        if (index < _events.length - 1)
          Container(
            width: 2,
            height: 80,
            color: const Color(0xFF6B4C9A),
          ),
      ],
    );
  }

  Widget _buildEventCard(TimelineEvent event, bool isLeft) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _showEventOptions(event),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFD4C5E8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.date,
                          style: const TextStyle(
                            color: Color(0xFF2D1B4E),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          event.title,
                          style: const TextStyle(
                            color: Color(0xFF2D1B4E),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Color(0xFF2D1B4E)),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editEvent(event);
                      } else if (value == 'delete') {
                        _deleteEvent(event);
                      } else if (value == 'media') {
                        _addMedia(event);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'media',
                        child: Row(
                          children: [
                            Icon(Icons.image, size: 20),
                            SizedBox(width: 8),
                            Text('Add Media'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (event.imagePath != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(event.imagePath!),
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showEventOptions(TimelineEvent event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF3D2A5C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white),
              title: const Text('Edit Event', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _editEvent(event);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image, color: Colors.white),
              title: const Text('Add Media', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _addMedia(event);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Event', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteEvent(event);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addNewEvent() {
    final titleController = TextEditingController();
    final dateController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF3D2A5C),
        title: const Text('Add New Event', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white70),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: dateController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Date (DD-MM-YY)',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white70),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              if (titleController.text.isNotEmpty && dateController.text.isNotEmpty) {
                setState(() {
                  _events.add(TimelineEvent(
                    id: DateTime.now().toString(),
                    title: titleController.text,
                    date: dateController.text,
                  ));
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _editEvent(TimelineEvent event) {
    final titleController = TextEditingController(text: event.title);
    final dateController = TextEditingController(text: event.date);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF3D2A5C),
        title: const Text('Edit Event', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white70),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: dateController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Date (DD-MM-YY)',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white70),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              if (titleController.text.isNotEmpty && dateController.text.isNotEmpty) {
                setState(() {
                  event.title = titleController.text;
                  event.date = dateController.text;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteEvent(TimelineEvent event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF3D2A5C),
        title: const Text('Delete Event', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this event?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _events.remove(event);
              });
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _addMedia(TimelineEvent event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF3D2A5C),
        title: const Text('Add Media', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Choose media source',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera, event);
            },
            child: const Text('Camera', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery, event);
            },
            child: const Text('Gallery', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, TimelineEvent event) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          event.imagePath = image.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }
}