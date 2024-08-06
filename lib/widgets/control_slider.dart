// import 'package:flutter/material.dart';
//
// class ControlSlider extends StatelessWidget {
//   final String label;
//   final double value;
//   final double min;
//   final double max;
//   final ValueChanged<double> onChanged;
//
//   const ControlSlider({
//     Key? key,
//     required this.label,
//     required this.value,
//     required this.min,
//     required this.max,
//     required this.onChanged,
//   }) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Text(label),
//         Slider(
//           value: value,
//           min: min,
//           max: max,
//           onChanged: onChanged,
//         ),
//       ],
//     );
//   }
// }
import 'package:flutter/material.dart';

class ControlSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final String label;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd; // onChangeEnd 추가

  const ControlSlider({
    Key? key,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onChanged,
    this.onChangeEnd, // onChangeEnd 초기화
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd, // Slider에 onChangeEnd 추가
        ),
      ],
    );
  }
}
