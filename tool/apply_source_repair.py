from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    target = Path(path)
    text = target.read_text(encoding="utf-8")
    if old in text:
        target.write_text(text.replace(old, new, 1), encoding="utf-8")
        return
    if new not in text:
        raise RuntimeError(f"Repair target not found: {path}")


def main() -> None:
    replace_once(
        "lib/screens/quote_input_screen.dart",
        "FilePicker.platform.pickFiles(",
        "FilePicker.pickFiles(",
    )

    replace_once(
        "lib/screens/comparison_screen.dart",
        """  Future<_CapturedComparison> _captureComparison() async {
    await WidgetsBinding.instance.endOfFrame;
    final renderObject = _captureKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary || renderObject.size.isEmpty) {
      throw StateError('比較画面のキャプチャ領域を取得できませんでした。');
    }
    final pixelRatio = MediaQuery.devicePixelRatioOf(
      context,
    ).clamp(1.0, 3.0).toDouble();
""",
        """  Future<_CapturedComparison> _captureComparison() async {
    final pixelRatio = MediaQuery.devicePixelRatioOf(
      context,
    ).clamp(1.0, 3.0).toDouble();
    await WidgetsBinding.instance.endOfFrame;
    final renderObject = _captureKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary || renderObject.size.isEmpty) {
      throw StateError('比較画面のキャプチャ領域を取得できませんでした。');
    }
""",
    )

    replace_once(
        "lib/screens/document_scanner_screen.dart",
        """  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final page = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, page);
      _retakeIndex = null;
    });
  }
""",
        """  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final page = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, page);
      _retakeIndex = null;
    });
  }
""",
    )
    replace_once(
        "lib/screens/document_scanner_screen.dart",
        "                  onReorder: _reorder,",
        "                  onReorderItem: _reorder,",
    )


if __name__ == "__main__":
    main()
