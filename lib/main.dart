import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RSS Feed Reader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const RssFeedPage(),
    );
  }
}

class RssFeedPage extends StatefulWidget {
  const RssFeedPage({super.key});

  @override
  State<RssFeedPage> createState() => _RssFeedPageState();
}

class RssFeedItem {
  final String title;
  final String description;
  final String link;
  final String pubDate;

  RssFeedItem({
    required this.title,
    required this.description,
    required this.link,
    required this.pubDate,
  });
}

class _RssFeedPageState extends State<RssFeedPage> {
  // Hardcoded RSS URL - you can change this to any valid RSS feed
  // final String rssUrl = 'https://www.tagesschau.de/index~rss2.xml';
  final String rssUrl = 'https://www.heise.de/rss/heise-atom.xml';
  late Future<List<RssFeedItem>> futureItems;

  @override
  void initState() {
    super.initState();
    futureItems = fetchRssFeed();
  }

  Future<void> _openLink(String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No link available')),
      );
      return;
    }
    
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch URL')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<List<RssFeedItem>> fetchRssFeed() async {
    try {
      final response = await http.get(Uri.parse(rssUrl));

      if (response.statusCode == 200) {
        final document = xml.XmlDocument.parse(response.body);
        final items = <RssFeedItem>[];

        // Parse RSS items (RSS uses 'item', Atom uses 'entry')
        var itemElements = document.findAllElements('item');
        if (itemElements.isEmpty) {
          itemElements = document.findAllElements('entry');
        }

        for (var item in itemElements) {
          final title =
              item.findElements('title').firstOrNull?.innerText ?? 'No title';
          
          // For description, try 'description', 'summary', or 'content'
          var description = item
                  .findElements('description')
                  .firstOrNull
                  ?.innerText ?? '';
          if (description.isEmpty) {
            description = item
                    .findElements('summary')
                    .firstOrNull
                    ?.innerText ?? '';
          }
          if (description.isEmpty) {
            description = item
                    .findElements('content')
                    .firstOrNull
                    ?.innerText ?? 'No description';
          }
          description = description.replaceAll(RegExp(r'<[^>]*>'), '');
          
          // For link, handle both RSS and Atom formats
          var link = item.findElements('link').firstOrNull?.innerText ?? '';
          if (link.isEmpty) {
            // Atom feeds may have link as an attribute
            final linkElement = item.findElements('link').firstOrNull;
            if (linkElement != null) {
              link = linkElement.getAttribute('href') ?? '';
            }
          }
          
          // For date, try 'pubDate', 'published', or 'updated'
          var pubDate = item.findElements('pubDate').firstOrNull?.innerText ?? '';
          if (pubDate.isEmpty) {
            pubDate = item.findElements('published').firstOrNull?.innerText ?? '';
          }
          if (pubDate.isEmpty) {
            pubDate = item.findElements('updated').firstOrNull?.innerText ?? '';
          }

          items.add(RssFeedItem(
            title: title,
            description: description,
            link: link,
            pubDate: pubDate,
          ));
        }

        return items;
      } else {
        throw Exception('Failed to load RSS feed');
      }
    } catch (e) {
      throw Exception('Error fetching RSS feed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RSS Feed Reader'),
        elevation: 0,
      ),
      body: FutureBuilder<List<RssFeedItem>>(
        future: futureItems,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No items found'),
            );
          } else {
            final items = snapshot.data!;
            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return GestureDetector(
                  onTap: () => _openLink(item.link),
                  child: Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      title: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            item.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.pubDate,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                      isThreeLine: false,
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
