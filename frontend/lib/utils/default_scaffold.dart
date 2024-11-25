// import 'package:flutter/material.dart';
// import 'package:zest/app/modules/recipe_search/views/recipe_search_view.dart';
// import 'package:zest/app/modules/root/views/drawer.dart';
// import 'package:zest/services/auth/auth_service.dart';

// Scaffold buildDefaultScaffold({
//   required BuildContext context,
//   required Widget body,
//   Widget? title,
//   List<Widget>? actions,
//   Widget? floatingActionButton,
// }) {
//   return Scaffold(
//     drawer: const DrawerWidget(),
//     appBar: AppBar(
//       title: title ?? const Text('Zest'),
//       centerTitle: true,
//       actions: actions ??
//           [
//             if (AuthenticationService.to.isAuthenticated)
//               IconButton(
//                 icon: const Icon(Icons.search),
//                 onPressed: () async {
//                   await showSearch(context: context, delegate: RecipeSearch());
//                 },
//               )
//           ],
//     ),
//     body: body,
//     floatingActionButton: floatingActionButton,
//   );
// }
