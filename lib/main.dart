import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:url_launcher/url_launcher.dart';
import 'package:html/parser.dart' as html_parser;

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
  final List<String> imageUrls;

  RssFeedItem({
    required this.title,
    required this.description,
    required this.link,
    required this.pubDate,
    this.imageUrls = const [],
  });
}

class _RssFeedPageState extends State<RssFeedPage> {
  // Hardcoded RSS URL - you can change this to any valid RSS feed
  final String rssUrl = 'https://www.tagesschau.de/index~rss2.xml';
  // final String rssUrl = 'https://www.heise.de/rss/heise-atom.xml';
  late Future<List<RssFeedItem>> futureItems;

  @override
  void initState() {
    super.initState();
    futureItems = fetchRssFeed();
  }

  Future<void> _openLink(String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No link available')));
      return;
    }

    // Ensure the URL starts with http or https
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid URL format')));
      return;
    }

    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Could not launch URL')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
          var descriptionHtml =
              item.findElements('description').firstOrNull?.innerText ?? '';
          if (descriptionHtml.isEmpty) {
            descriptionHtml =
                item.findElements('summary').firstOrNull?.innerText ?? '';
          }
          if (descriptionHtml.isEmpty) {
            descriptionHtml =
                item.findElements('content').firstOrNull?.innerText ??
                'No description';
          }
          
          // Extract image URLs from HTML - check both 'content' and 'content:encoded'
          final imageUrls = <String>[];
          var contentHtml =
              item.findElements('content').firstOrNull?.innerText ?? '';
          if (contentHtml.isEmpty) {
            contentHtml =
                item.findElements('content:encoded').firstOrNull?.innerText ?? '';
          }
          if (contentHtml.contains('<img')) {
            final htmlDoc = html_parser.parse(contentHtml);
            final imgElements = htmlDoc.querySelectorAll('img');
            for (var img in imgElements) {
              final src = img.attributes['src'];
              if (src != null && src.isNotEmpty) {
                imageUrls.add(src);
              }
            }
          }
          
          // Strip HTML tags for text description
          final description = descriptionHtml.replaceAll(RegExp(r'<[^>]*>'), '');

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
          var pubDate =
              item.findElements('pubDate').firstOrNull?.innerText ?? '';
          if (pubDate.isEmpty) {
            pubDate =
                item.findElements('published').firstOrNull?.innerText ?? '';
          }
          if (pubDate.isEmpty) {
            pubDate = item.findElements('updated').firstOrNull?.innerText ?? '';
          }

          items.add(
            RssFeedItem(
              title: title,
              description: description,
              link: link,
              pubDate: pubDate,
              imageUrls: imageUrls,
            ),
          );
        }

        return items;
      } else {
        throw Exception('Failed to load RSS feed');
      }
    } catch (e) {
      throw Exception('Error fetching RSS feed: $e');
    }
  }

  void _refreshData() {
    setState(() {
      futureItems = fetchRssFeed();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RSS Feed Reader'),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
        ],
      ),
      body: FutureBuilder<List<RssFeedItem>>(
        future: futureItems,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
            return const Center(child: Text('No items found'));
          } else {
            final items = snapshot.data!;
            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return GestureDetector(
                  onTap: () => _openLink(item.link),
                  child: Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.imageUrls.isNotEmpty)
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxHeight: 200,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item.imageUrls.first,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const SizedBox.shrink();
                                  },
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      height: 200,
                                      color: Colors.grey[800],
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  loadingProgress.expectedTotalBytes!
                                              : null,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          if (item.imageUrls.isNotEmpty) const SizedBox(height: 8),
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.description,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color.fromARGB(184, 255, 255, 255),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.pubDate,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
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
