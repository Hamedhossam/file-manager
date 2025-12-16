part of 'theme_cubit.dart';

sealed class ThemeState extends Equatable {
  const ThemeState();

  @override
  List<Object> get props => [];
}

final class ThemeInitial extends ThemeState {}

final class ThemeStateDark extends ThemeState {}

final class ThemeStateLight extends ThemeState {}

final class ThemeStateChanged extends ThemeState {
  const ThemeStateChanged();
}
