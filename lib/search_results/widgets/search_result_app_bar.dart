import 'package:flutter/material.dart';

class SearchResultAppBar extends StatefulWidget implements PreferredSizeWidget {
  const SearchResultAppBar({
    Key? key,
    required this.onChanged,
    required this.onSearchTypeChanged,
  }) : super(key: key);

  final void Function(String? s, String searchType) onChanged;
  final void Function(String) onSearchTypeChanged;

  @override
  State<SearchResultAppBar> createState() => _SearchResultAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(100);
}

class _SearchResultAppBarState extends State<SearchResultAppBar> {
  String _selectedSearchType = "song";

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: Colors.deepPurple,
        height: 60,
        padding: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              Expanded(
                child: TextField(
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search",
                    filled: true,
                    hintStyle: const TextStyle(color: Colors.grey),
                    fillColor: Colors.deepPurple.shade700,
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  onChanged: (value) {
                    widget.onChanged(value, _selectedSearchType);
                  },
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
        ),
      ),
        bottom: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: Container(
          color: Colors.deepPurple,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSearchTypeButton("song", "Song"),
              _buildSearchTypeButton("artist", "Artist"),
              //_buildSearchTypeButton("album", "Album"), // Assuming API doesn't directly support album search
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchTypeButton(String type, String label) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSearchType = type;
        });
        widget.onSearchTypeChanged(type);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Text(
          label,
          style: TextStyle(
            color: _selectedSearchType == type ? Colors.white : Colors.grey[300],
            fontWeight: _selectedSearchType == type ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
