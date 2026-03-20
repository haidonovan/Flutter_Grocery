import 'package:flutter/material.dart';

class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({
    required WidgetBuilder builder,
    Duration duration = const Duration(milliseconds: 520),
    super.settings,
  }) : super(
         transitionDuration: duration,
         reverseTransitionDuration: const Duration(milliseconds: 380),
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final curved = CurvedAnimation(
             parent: animation,
             curve: Curves.easeInOutCubic,
             reverseCurve: Curves.easeInOutCubic,
           );

           return FadeTransition(
             opacity: Tween<double>(begin: 0, end: 1).animate(curved),
             child: SlideTransition(
               position: Tween<Offset>(
                 begin: const Offset(0.08, 0),
                 end: Offset.zero,
               ).animate(curved),
               child: child,
             ),
           );
         },
       );
}
