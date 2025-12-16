import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

part 'theme_state.dart';

class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit() : super(ThemeInitial());

  void changeTheme(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) {
      emit(ThemeStateLight());
    } else {
      emit(ThemeStateDark());
    }
  }
}
