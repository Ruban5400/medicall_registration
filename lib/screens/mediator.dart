// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
//
// import '../controller/main_controller.dart';
// import '../utils/widgets/qr_scanner.dart';
// import 'get_item_details.dart';
//
// class WelcomePage extends StatelessWidget {
//   const WelcomePage({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Text(
//               'Welcome to the App!',
//               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: () async{
//                 var result = await Provider.of<MainController>(context, listen: false)
//                     .scannBarCode(context);
//                 print('5400 0-0-0-0-0- >>> $result');
//
//                 // Navigator.pushReplacement(
//                 //   context,
//                 //   MaterialPageRoute(builder: (_) => const GetItemDetails()),
//                 //   // MaterialPageRoute(builder: (_) => const WelcomePage()),
//                 // );
//               },
//               child: const Text('Go to Next Page'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class NextPage extends StatelessWidget {
//   const NextPage({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Next Page")),
//       body: const Center(
//         child: Text(
//           'You are now on the next page!',
//           style: TextStyle(fontSize: 20),
//         ),
//       ),
//     );
//   }
// }
