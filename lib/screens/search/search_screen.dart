import 'package:flutter/material.dart';

import '../doctors/doctor_list_screen.dart';

/// Search from Home: the whole directory — doctors and physios — with the
/// keyboard already open.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const DoctorListScreen(type: null, autofocus: true, title: 'Search');
}
