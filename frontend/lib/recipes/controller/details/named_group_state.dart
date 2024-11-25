// import 'package:flutter/material.dart';
// import 'package:hooks_riverpod/hooks_riverpod.dart';

// class NamedGroupFormController<Item> {
//   NamedGroupFormController(this.nameController, this.data);

//   NamedGroupFormController<Item> copyWith(
//           {TextEditingController? nameController, List<Item>? data}) =>
//       NamedGroupFormController<Item>(
//           nameController: nameController ?? this.nameController,
//           data: data ?? this.data);

//   final nameController; // = TextEditingController();
//   final data; // = <Item>[];

//   int get length => data.length;
//   String get name => nameController.text;
//   set name(String name) => nameController.text = name;

//   // /// Add an element of type Item
//   // void add(Item item) {
//   //   data = [...data, item];
//   // }

//   // void insert(int index, Item item) {
//   //   final tmp = [...data];
//   //   tmp.insert(index, item);
//   //   data = tmp;
//   // }

//   // void removeAt(int index) {
//   //   Item item = data.elementAt(index);
//   //   data = data.where((x) => data.indexOf(x) != index).toList();
//   //   disposeItem(item);
//   // }

//   // /// How to clean up the elements
//   // @override
//   // void dispose() {
//   //   nameController.dispose();
//   //   disposeItems();
//   //   super.dispose();
//   // }

//   // // To be overriden by user
//   // void disposeItems();

//   // void disposeItem(Item item);
// }
