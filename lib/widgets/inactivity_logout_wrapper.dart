import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

/// Signs the user out after a fixed period of input inactivity.
/// Resets the timer on any pointer interaction, keyboard input, or focus change.
class InactivityLogoutWrapper extends ConsumerStatefulWidget {
  static const Duration timeout = Duration(minutes: 20);

  final Widget child;

  const InactivityLogoutWrapper({super.key, required this.child});

  @override
  ConsumerState<InactivityLogoutWrapper> createState() =>
      _InactivityLogoutWrapperState();
}

class _InactivityLogoutWrapperState
    extends ConsumerState<InactivityLogoutWrapper> {
  Timer? _timer;
  bool _signingOut = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _resetTimer();
    // Listen to focus changes (indicates user is interacting with the app)
    _focusNode.addListener(_onActivity);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focusNode.removeListener(_onActivity);
    _focusNode.dispose();
    super.dispose();
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(InactivityLogoutWrapper.timeout, _handleTimeout);
  }

  Future<void> _handleTimeout() async {
    if (_signingOut || !mounted) return;
    _signingOut = true;
    try {
      await ref.read(authServiceProvider).signOut();
    } catch (_) {
      // Auth state stream drives navigation; swallow transient errors.
    } finally {
      _signingOut = false;
    }
  }

  void _onActivity([Object? _]) {
    if (_focusNode.hasFocus) {
      _resetTimer();
    }
  }

  void _onPointerEvent([Object? _]) => _resetTimer();

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (event) => _onActivity(),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerEvent,
        onPointerMove: _onPointerEvent,
        onPointerSignal: _onPointerEvent,
        child: widget.child,
      ),
    );
  }
}
