import 'package:files_manager/core/theme/app_theme.dart';
import 'package:files_manager/features/manager/cubit/theme_cubit.dart';
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
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => EnhancedFileManagerCubit()),
        BlocProvider(create: (context) => ThemeCubit()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, state) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: state is ThemeStateLight
                ? AppTheme.lightTheme()
                : AppTheme.darkTheme(),
            home: const EnhancedFileManagerPage(),
          );
        },
      ),
    );
  }
}
