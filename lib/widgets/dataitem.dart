import 'package:flutter/material.dart';

class DataItem extends StatelessWidget {
  final Map<String, dynamic> data;
  final String dataKey;

  const DataItem({Key? key, required this.data, required this.dataKey, required Icon icon}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${dataKey.toUpperCase()}: ${data[dataKey] ?? 'N/A'}',
          style: TextStyle(fontSize: 16, color: Colors.black),
        ),
      ],
    );
  }
}

