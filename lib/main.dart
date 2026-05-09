import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart' hide Interval;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
      ),
      home: const InchCalculator(),
    );
  }
}

class InchCalculator extends StatefulWidget {
  const InchCalculator({super.key});

  @override
  State<InchCalculator> createState() => _InchCalculatorState();
}

class _InchCalculatorState extends State<InchCalculator>
    with TickerProviderStateMixin {
  late TextEditingController _equationController;
  late FocusNode _focusNode;

  String result = "0";
  List<Map<String, String>> history = [];
  bool isBase8Mode = true;

  late AnimationController _displayController;
  late Animation<double> _displayOpacity;
  late AnimationController _pageController;

  @override
  void initState() {
    super.initState();
    _equationController = TextEditingController(text: "0");
    _focusNode = FocusNode();

    loadHistory();

    _displayController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _displayOpacity = Tween<double>(begin: 1.0, end: 0.7).animate(
      CurvedAnimation(parent: _displayController, curve: Curves.easeInOut),
    );

    _pageController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pageController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _equationController.dispose();
    _focusNode.dispose();
    _displayController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList("history");

    if (data != null) {
      history = data
          .map((e) => Map<String, String>.from(jsonDecode(e)))
          .toList();
      setState(() {});
    }
  }

  Future<void> saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList(
      "history",
      history.map((e) => jsonEncode(e)).toList(),
    );
  }

  Future<void> clearHistory() async {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear History?"),
        content: const Text("Are you sure you want to delete all history?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove("history");
              if (mounted) {
                history.clear();
                setState(() {});
                Navigator.pop(ctx);
                Navigator.pop(context);
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String processEquationForEvaluation(String eq, bool isBase8) {
    if (!isBase8) return eq;
    return eq.replaceAllMapped(RegExp(r'(\d+)\.(\d+)'), (match) {
      double whole = double.parse(match.group(1)!);
      String fracStr = match.group(2)!;
      double frac = double.parse("0.$fracStr");
      double standardDecimal = whole + (frac * 10 / 8);
      return standardDecimal.toString();
    });
  }

  String formatResult(double value, bool isBase8) {
    if (!isBase8) {
      String str = value.toStringAsFixed(6);
      return str.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }

    int intPart = value.truncate();
    double fracPart = (value - intPart).abs();

    double base8Frac = (fracPart * 8) / 10;
    double finalVal = intPart.abs() + base8Frac;
    if (value < 0) finalVal = -finalVal;

    String str = finalVal.toStringAsFixed(6);
    return str.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  void _insertTextAtCursor(String textToInsert) {
    final text = _equationController.text;
    final selection = _equationController.selection;

    int start = selection.start != -1 ? selection.start : text.length;
    int end = selection.end != -1 ? selection.end : text.length;

    if (text == "0" && !['+', '-', '×', '÷', '%', '²'].contains(textToInsert)) {
      _equationController.value = TextEditingValue(
        text: textToInsert,
        selection: TextSelection.collapsed(offset: textToInsert.length),
      );
    } else {
      final newText = text.replaceRange(start, end, textToInsert);
      _equationController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + textToInsert.length),
      );
    }
  }

  void _handleBackspace() {
    final text = _equationController.text;
    final selection = _equationController.selection;

    int start = selection.start != -1 ? selection.start : text.length;
    int end = selection.end != -1 ? selection.end : text.length;

    if (start != end) {
      final newText = text.replaceRange(start, end, "");
      _equationController.value = TextEditingValue(
        text: newText.isEmpty ? "0" : newText,
        selection: TextSelection.collapsed(offset: newText.isEmpty ? 1 : start),
      );
    } else if (start > 0) {
      final newText = text.replaceRange(start - 1, start, "");
      _equationController.value = TextEditingValue(
        text: newText.isEmpty ? "0" : newText,
        selection: TextSelection.collapsed(offset: newText.isEmpty ? 1 : start - 1),
      );
    }
  }

  void onButtonTap(String text) async {
    _displayController.forward().then((_) {
      _displayController.reverse();
    });

    _focusNode.requestFocus();

    setState(() {
      if (text == "C") {
        _equationController.value = const TextEditingValue(
          text: "0",
          selection: TextSelection.collapsed(offset: 1),
        );
        result = "0";
      } else if (text == "⌫") {
        _handleBackspace();
      } else if (text == "=") {
        try {
          String expText = _equationController.text;
          expText = expText.replaceAllMapped(
              RegExp(r'(\d)([\(√])'), (m) => '${m[1]}*${m[2]}');
          expText = expText.replaceAllMapped(
              RegExp(r'([\)%²])([\d\(√])'), (m) => '${m[1]}*${m[2]}');

          int openBrackets = expText.split('(').length - 1;
          int closeBrackets = expText.split(')').length - 1;
          if (openBrackets > closeBrackets) {
            expText += ')' * (openBrackets - closeBrackets);
          }
          expText = expText
              .replaceAll('×', '*')
              .replaceAll('÷', '/')
              .replaceAll('%', '/100')
              .replaceAll('²', '^2')
              .replaceAll('√', 'sqrt');

          expText = processEquationForEvaluation(expText, isBase8Mode);

          Parser p = Parser();
          Expression exp = p.parse(expText);
          ContextModel cm = ContextModel();

          double eval = exp.evaluate(EvaluationType.REAL, cm);
          result = formatResult(eval, isBase8Mode);

          history.insert(0, {
            "equation": _equationController.text,
            "result": result,
            "mode": isBase8Mode ? "8-Parts" : "10-Parts"
          });
          saveHistory();
        } catch (e) {
          result = "Error";
        }
      } else if (text == "x²") {
        _insertTextAtCursor("²");
      } else if (text == "√") {
        _insertTextAtCursor("√(");
      } else {
        _insertTextAtCursor(text);
      }
    });
  }

  void openHistory() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      elevation: 5.0,
      backgroundColor: Colors.white.withValues(alpha: 0.95),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              ListTile(
                title: const Text(
                  "Calculation History",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  onPressed: clearHistory,
                ),
              ),
              Expanded(
                child: history.isEmpty
                    ? Center(
                  child: Text(
                    "No history yet",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[500],
                    ),
                  ),
                )
                    : ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    if (index >= history.length) {
                      return const SizedBox.shrink();
                    }

                    final item = history[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Dismissible(
                        key: Key(
                            "${item["equation"]}_${item["result"]}_$index"),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.red[400],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete,
                              color: Colors.white),
                        ),
                        onDismissed: (direction) async {
                          if (index < history.length) {
                            history.removeAt(index);
                            await saveHistory();
                            setState(() {});
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12.0),
                              color: Colors.white.withValues(alpha: 0.9),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withValues(alpha: 0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]),
                          child: ListTile(
                            title: Text(
                              item["equation"] ?? "",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              "${item["result"]} (${item["mode"]})",
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text(
          "Apna Calculator",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          TextButton.icon(
            onPressed: () {
              setState(() {
                isBase8Mode = !isBase8Mode;
              });
            },
            icon: Icon(
              isBase8Mode ? Icons.straighten : Icons.calculate,
              color: isBase8Mode ? const Color(0xFF6366F1) : Colors.black87,
              size: 20,
            ),
            label: Text(
              isBase8Mode ? "8 Parts" : "10 Parts",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isBase8Mode ? const Color(0xFF6366F1) : Colors.black87,
              ),
            ),
            style: TextButton.styleFrom(
                backgroundColor: isBase8Mode
                    ? const Color(0xFF6366F1).withValues(alpha: 0.1)
                    : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                )),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.history_rounded, size: 26),
              onPressed: openHistory,
              tooltip: "View history",
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            FadeTransition(
              opacity: Tween<double>(begin: 0, end: 1).animate(
                CurvedAnimation(parent: _pageController, curve: Curves.easeOut),
              ),
              child: SlideTransition(
                position:
                Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
                    .animate(
                  CurvedAnimation(
                      parent: _pageController, curve: Curves.easeOut),
                ),
                child: Container(
                  width: double.infinity,
                  margin:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.95),
                        Colors.white.withValues(alpha: 0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AnimatedBuilder(
                        animation: _displayOpacity,
                        builder: (context, child) {
                          return TextField(
                            controller: _equationController,
                            focusNode: _focusNode,
                            readOnly: true,
                            showCursor: true,
                            autofocus: true,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 30,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      AnimatedBuilder(
                        animation: _displayOpacity,
                        builder: (context, child) {
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF3476e5).withValues(alpha: 0.8),
                                  const Color(0xF6575Cb3).withValues(alpha: 0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            child: Text(
                              result,
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -1,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildButtonRow([
                      ('C', false, true, false),
                      ('(', true, false, false),
                      (')', true, false, false),
                      ('⌫', false, true, false),
                    ], 0),
                    _buildButtonRow([
                      ('x²', true, false, false),
                      ('√', true, false, false),
                      ('%', true, false, false),
                      ('÷', true, false, false),
                    ], 1),
                    _buildButtonRow([
                      ('7', false, false, false),
                      ('8', false, false, false),
                      ('9', false, false, false),
                      ('×', true, false, false),
                    ], 2),
                    _buildButtonRow([
                      ('4', false, false, false),
                      ('5', false, false, false),
                      ('6', false, false, false),
                      ('-', true, false, false),
                    ], 3),
                    _buildButtonRow([
                      ('1', false, false, false),
                      ('2', false, false, false),
                      ('3', false, false, false),
                      ('+', true, false, false),
                    ], 4),
                    _buildButtonRow([
                      ('0', false, false, false),
                      ('.', false, false, false),
                      ('=', false, false, true),
                    ], 5, isLast: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonRow(
      List<(String text, bool isOp, bool isClear, bool isEq)> buttons,
      int rowIndex, {
        bool isLast = false,
      }) {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0.5, 0), end: Offset.zero)
          .animate(
        CurvedAnimation(
          parent: _pageController,
          curve: Interval(
            0.1 + (rowIndex * 0.1),
            0.4 + (rowIndex * 0.1),
            curve: Curves.easeOut,
          ),
        ),
      ),
      child: Row(
        children: buttons.map((btn) {
          final (text, isOp, isClear, isEq) = btn;
          return Expanded(
            flex: isLast && isEq ? 2 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 6.0,
              ),
              child: CustomAnimatedButton(
                text: text,
                backgroundColor: isOp
                    ? const Color(0xFFFF9500)
                    : isClear
                    ? const Color(0xFFEF4444)
                    : isEq
                    ? const Color(0xFF10B981)
                    : Colors.white,
                textColor: isOp || isClear || isEq
                    ? Colors.white
                    : const Color(0xFF1F2937),
                onPressed: () => onButtonTap(text),
                isOperator: isOp,
                isClear: isClear,
                isEquals: isEq,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class CustomAnimatedButton extends StatefulWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onPressed;
  final bool isOperator;
  final bool isClear;
  final bool isEquals;

  const CustomAnimatedButton({
    super.key,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    required this.onPressed,
    this.isOperator = false,
    this.isClear = false,
    this.isEquals = false,
  });

  @override
  State<CustomAnimatedButton> createState() => _CustomAnimatedButtonState();
}

class _CustomAnimatedButtonState extends State<CustomAnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scale;
  late Animation<double> _elevation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _elevation = Tween<double>(begin: 6, end: 14).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _animationController.reverse();
  }

  void _onTapCancel() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTapDown: _onTapDown,
      onTapUp: (details) {
        _onTapUp(details);
        widget.onPressed();
      },
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: Container(
              decoration: BoxDecoration(
                gradient: widget.isEquals
                    ? const LinearGradient(
                  colors: [
                    Color(0xFF10B981),
                    Color(0xFF059669),
                  ],
                )
                    : widget.isClear
                    ? const LinearGradient(
                  colors: [
                    Color(0xFFEF4444),
                    Color(0xFFDC2626),
                  ],
                )
                    : widget.isOperator
                    ? const LinearGradient(
                  colors: [
                    Color(0xFFFF9500),
                    Color(0xFFEA580C),
                  ],
                )
                    : null,
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: widget.backgroundColor.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: Offset(0, _elevation.value),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: Text(
                    widget.text,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: widget.textColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}