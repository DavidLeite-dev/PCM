import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A professional page flip widget inspired by FlippingBook and Adobe Reader
/// Features smooth edge-dragging with real-time page following
class PageFlipWidget extends StatefulWidget {
  final Widget currentPage;
  final Widget? nextPage;
  final Widget? previousPage;
  final VoidCallback? onFlipNext;
  final VoidCallback? onFlipPrevious;
  final bool canFlipNext;
  final bool canFlipPrevious;
  final bool isLoading;

  const PageFlipWidget({
    super.key,
    required this.currentPage,
    this.nextPage,
    this.previousPage,
    this.onFlipNext,
    this.onFlipPrevious,
    this.canFlipNext = true,
    this.canFlipPrevious = true,
    this.isLoading = false,
  });

  @override
  State<PageFlipWidget> createState() => _PageFlipWidgetState();
}

class _PageFlipWidgetState extends State<PageFlipWidget>
    with SingleTickerProviderStateMixin {
  // Animation controller for auto-complete
  late AnimationController _animationController;

  // Drag state
  double _dragProgress = 0.0; // 0.0 = not flipping, 1.0 = completely flipped
  bool _isDragging = false;
  FlipDirection? _flipDirection;

  // Track completed flip to show destination page during loading
  FlipDirection? _completedFlipDirection;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _animationController.addListener(() {
      if (!_isDragging) {
        setState(() {
          _dragProgress = _animationController.value;
        });
      }
    });

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onFlipComplete();
      } else if (status == AnimationStatus.dismissed) {
        _onFlipCancelled();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PageFlipWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Clear completed flip state when widget updates (loading finished)
    if (_completedFlipDirection != null && !widget.isLoading) {
      setState(() {
        _completedFlipDirection = null;
      });
    }
  }

  void _onFlipComplete() {
    final direction = _flipDirection;
    setState(() {
      _dragProgress = 0.0;
      _flipDirection = null;
      // Keep track of completed flip to show destination page during loading
      _completedFlipDirection = direction;
    });

    // Trigger callback after state is clean
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (direction == FlipDirection.forward) {
        widget.onFlipNext?.call();
      } else if (direction == FlipDirection.backward) {
        widget.onFlipPrevious?.call();
      }
    });
  }

  void _onFlipCancelled() {
    setState(() {
      _dragProgress = 0.0;
      _flipDirection = null;
    });
  }

  void _handleHorizontalDragStart(DragStartDetails details) {
    // Disable swiping while loading
    if (widget.isLoading) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final xPos = details.localPosition.dx;

    // Define drag zones to avoid system gesture areas (typically first ~10-15% from edges)
    // Right 45% = flip forward, Left 45% = flip backward, Middle 10% = safe zone
    final rightZoneStart = screenWidth * 0.55; // Start at 55% from left
    final leftZoneEnd = screenWidth * 0.45; // End at 45% from left

    FlipDirection? detectedDirection;

    if (xPos >= rightZoneStart && widget.canFlipNext) {
      // Right zone - flip forward (55%-100%)
      detectedDirection = FlipDirection.forward;
    } else if (xPos <= leftZoneEnd && widget.canFlipPrevious) {
      // Left zone - flip backward (0%-45%)
      detectedDirection = FlipDirection.backward;
    } else {
      // Middle zone or can't flip - ignore (45%-55%)
      return;
    }

    setState(() {
      _isDragging = true;
      _flipDirection = detectedDirection;
      _dragProgress = 0.0;
    });

    _animationController.stop();
    _animationController.value = 0.0;
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    // Disable swiping while loading
    if (widget.isLoading) return;
    if (!_isDragging || _flipDirection == null) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final dx = details.delta.dx;

    setState(() {
      if (_flipDirection == FlipDirection.forward) {
        // Dragging left to flip forward
        _dragProgress = (_dragProgress - (dx / screenWidth)).clamp(0.0, 1.0);
      } else {
        // Dragging right to flip backward
        _dragProgress = (_dragProgress + (dx / screenWidth)).clamp(0.0, 1.0);
      }
    });
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    // Disable swiping while loading
    if (widget.isLoading) return;
    if (!_isDragging) return;

    setState(() {
      _isDragging = false;
    });

    final velocity = details.primaryVelocity ?? 0;
    final shouldComplete =
        _dragProgress > 0.5 || (_dragProgress > 0.2 && velocity.abs() > 500);

    if (shouldComplete) {
      _animationController.forward(from: _dragProgress);
    } else {
      _animationController.reverse(from: _dragProgress);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _handleHorizontalDragStart,
      onHorizontalDragUpdate: _handleHorizontalDragUpdate,
      onHorizontalDragEnd: _handleHorizontalDragEnd,
      child: _buildFlipView(),
    );
  }

  Widget _buildFlipView() {
    // If we just completed a flip, show the destination page during loading
    if (_completedFlipDirection != null) {
      if (_completedFlipDirection == FlipDirection.forward) {
        return widget.nextPage ?? widget.currentPage;
      } else {
        return widget.previousPage ?? widget.currentPage;
      }
    }

    if (_dragProgress == 0.0 || _flipDirection == null) {
      // Show current page normally
      return widget.currentPage;
    }

    // Show flip animation
    return Stack(
      children: [
        // Background page (destination)
        _buildBackgroundPage(),

        // Flipping page with 3D transform
        _buildFlippingPage(),
      ],
    );
  }

  Widget _buildBackgroundPage() {
    if (_flipDirection == FlipDirection.forward) {
      return widget.nextPage ?? widget.currentPage;
    } else {
      return widget.previousPage ?? widget.currentPage;
    }
  }

  Widget _buildFlippingPage() {
    final progress = _dragProgress;
    final angle = progress * math.pi;

    // Determine which page content to show
    Widget pageContent;
    if (progress < 0.5) {
      // First half: show current page
      pageContent = widget.currentPage;
    } else {
      // Second half: show destination page (flipped)
      pageContent = _flipDirection == FlipDirection.forward
          ? (widget.nextPage ?? widget.currentPage)
          : (widget.previousPage ?? widget.currentPage);
    }

    return Transform(
      alignment: _flipDirection == FlipDirection.forward
          ? Alignment.centerLeft
          : Alignment.centerRight,
      transform: _build3DTransform(angle),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5 * progress),
              blurRadius: 20.0 * progress,
              spreadRadius: 5.0 * progress,
            ),
          ],
        ),
        child: pageContent,
      ),
    );
  }

  Matrix4 _build3DTransform(double angle) {
    final flipMultiplier = _flipDirection == FlipDirection.forward ? 1.0 : -1.0;

    return Matrix4.identity()
      ..setEntry(3, 2, 0.001) // Perspective
      ..rotateY(angle * flipMultiplier);
  }
}

enum FlipDirection { forward, backward }
