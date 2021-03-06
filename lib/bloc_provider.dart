import 'package:flutter/material.dart';
import 'package:stardewcompanion/bloc_base.dart';

class BlocProvider<T extends BlocBase> extends StatefulWidget {
  final Widget child;
  final T bloc;

  BlocProvider({Key key, @required this.bloc, @required this.child}): super(key: key);

  static T of<T extends BlocBase>(BuildContext context) {
    final BlocProvider<T> provider = context.findAncestorWidgetOfExactType<BlocProvider<T>>();
    return provider.bloc;
  }

  @override
  State<StatefulWidget> createState() => _BlocProviderState();
}
class _BlocProviderState extends State<BlocProvider>{

  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void dispose() {
    widget.bloc.dispose();
    super.dispose();
  }
}
