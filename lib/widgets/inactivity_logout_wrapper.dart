import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

/// Wraps the authenticated app shell and signs the user out after a fixed
/// period of input inactivity. Resets the timer on any pointer interaction
/// inside the subtree.
class InactivityLogoutWrapper extends ConsumerStatefulWidget {
  static const Duration timeout = Duration(minutes: 30);

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

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
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
      // Auth state stream still drives navigation; swallow transient errors.
    } finally {
      _signingOut = false;
    }
  }

  void _onActivity([Object? _]) => _resetTimer();

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onActivity,
      onPointerMove: _onActivity,
      onPointerSignal: _onActivity,
      child: widget.child,
    );
  }
}
