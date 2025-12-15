import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'features/manager/cubit/file_manager_cubit.dart';
import 'features/manager/views/file_manager_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FileManagerCubit(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const FileManagerPage(),
      ),
    );
  }
}
