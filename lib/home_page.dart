import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class VideoCard extends StatelessWidget {
  const VideoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thumbnail
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(
            "https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg",
            fit: BoxFit.cover,
          ),
        ),

        // Video info
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Channel avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, color: Colors.white),
              ),

              SizedBox(width: 12),

              // Title + metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "This is a YouTube video title",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Channel Name â€¢ 1.2M views â€¢ 2 days ago",
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              Icon(Icons.more_vert, color: Colors.grey),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomePageState extends State<HomePage> {
  int num = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // youtube header container
          Container(
            height: 60, // header height,
            padding: EdgeInsets.symmetric(horizontal: 12),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // left side: hamberger + logo + text
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        // TODO: slide menu later
                        _scaffoldKey.currentState!.openDrawer();
                      },
                      icon: Icon(Icons.menu),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.play_arrow, color: Colors.red, size: 28),
                    SizedBox(width: 4),
                    Text(
                      "Youtube",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                // Right side : search + profile
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        // do something
                      },
                      icon: Icon(Icons.search),
                    ),
                    IconButton(
                      onPressed: () {
                        // do something
                      },
                      icon: Icon(Icons.mic),
                    ),
                    IconButton(
                      onPressed: () {
                        // do something
                      },
                      icon: Icon(Icons.notifications),
                    ),
                    SizedBox(width: 8),
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, size: 16, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: 100,
              itemBuilder: (context, index) {
                return const VideoCard();
              },
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            // top youtube section
            Container(
              height: 120,
              padding: EdgeInsets.all(16),
              alignment: Alignment.bottomLeft,
              child: Row(
                children: [
                  Icon(Icons.play_arrow, color: Colors.red, size: 32),
                  SizedBox(width: 8),
                  Text(
                    "YouTube",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            // menu items
            Divider(),
            ListTile(
              leading: Icon(Icons.home),
              title: Text("Home"),
              onTap: () {},
            ),

            ListTile(
              leading: Icon(Icons.flash_on),
              title: Text("Shorts"),
              onTap: () {},
            ),

            Divider(),

            ListTile(
              leading: Icon(Icons.subscriptions),
              title: Text("Subscriptions"),
              onTap: () {},
            ),

            Divider(),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text("You", style: TextStyle(fontWeight: FontWeight.bold)),
            ),

            ListTile(leading: Icon(Icons.history), title: Text("History")),

            ListTile(leading: Icon(Icons.download), title: Text("Downloads")),

            ListTile(leading: Icon(Icons.music_note), title: Text("Music")),

            ListTile(
              leading: Icon(Icons.sports_esports),
              title: Text("Gaming"),
            ),

            ListTile(
              leading: Icon(Icons.watch_later),
              title: Text("Watch Later"),
            ),

            ListTile(
              leading: Icon(Icons.expand_more),
              title: Text("Show more"),
            ),
          ],
        ),
      ),
      // menu will go here
    );
  }

  // Button
}
