import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(ExpenseSplitterApp());
}

class ExpenseSplitterApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final seed = Colors.teal;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Expense Splitter',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        brightness: Brightness.light,
        appBarTheme: AppBarTheme(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          color: Colors.white,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            elevation: 1,
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: seed,
          elevation: 4,
        ),
      ),
      home: ExpenseHomePage(),
    );
  }
}

class Expense {
  final String id;
  final String name;
  final double amount;
  final String description;
  bool isDeleted;
  final int createdAt;

  Expense({
    required this.id,
    required this.name,
    required this.amount,
    required this.description,
    this.isDeleted = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    'description': description,
    'isDeleted': isDeleted,
    'createdAt': createdAt,
  };

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'],
      name: json['name'],
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] ?? '',
      isDeleted: json['isDeleted'] ?? false,
      createdAt: json['createdAt'] ?? 0,
    );
  }
}

class ExpenseHomePage extends StatefulWidget {
  @override
  _ExpenseHomePageState createState() => _ExpenseHomePageState();
}

class _ExpenseHomePageState extends State<ExpenseHomePage> {
  final List<Expense> _expenses = [];
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _currency = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currency.isEmpty) _askCurrencyIfEmpty();
    });
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCurrency = prefs.getString('currency') ?? '';
    final jsonString = prefs.getString('expenses') ?? '';
    List<Expense> loaded = [];
    if (jsonString.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(jsonString);
        loaded = list.map((e) => Expense.fromJson(e)).toList();
      } catch (_) {
        loaded = [];
      }
    }
    setState(() {
      _currency = savedCurrency;
      _expenses.clear();
      _expenses.addAll(loaded);
      _sortExpenses();
    });
  }

  Future<void> _saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('currency', _currency);
    final encoded = jsonEncode(_expenses.map((e) => e.toJson()).toList());
    prefs.setString('expenses', encoded);
  }

  void _sortExpenses() {
    _expenses.sort((a, b) {
      if (a.isDeleted == b.isDeleted) return a.createdAt.compareTo(b.createdAt);
      return a.isDeleted ? 1 : -1;
    });
  }

  Future<void> _askCurrencyIfEmpty() async {
    if (_currency.isNotEmpty) return;
    final controller = TextEditingController(text: 'USD');
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Выберите валюту'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Валюта (например USD, EUR, RUB)',
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              final val = controller.text.trim().toUpperCase();
              if (val.isEmpty) return;
              setState(() {
                _currency = val;
              });
              _saveAll();
              Navigator.of(ctx).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _changeCurrency() {
    final controller = TextEditingController(text: _currency);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Изменить валюту'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Валюта (например USD, EUR)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = controller.text.trim().toUpperCase();
              if (val.isEmpty) return;
              setState(() => _currency = val);
              _saveAll();
              Navigator.of(ctx).pop();
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _addExpense() {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final desc = _descriptionController.text.trim();

    if (name.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите корректное имя и сумму')),
      );
      return;
    }
    final e = Expense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      amount: amount,
      description: desc,
      isDeleted: false,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    setState(() {
      _expenses.add(e);
      _sortExpenses();
      _nameController.clear();
      _amountController.clear();
      _descriptionController.clear();
    });
    _saveAll();
  }

  void _markDeletedAndMoveToBottom(int index) {
    final removed = _expenses.removeAt(index);
    final removedIndex = index;
    final removedCopy = Expense(
      id: removed.id,
      name: removed.name,
      amount: removed.amount,
      description: removed.description,
      isDeleted: true,
      createdAt: removed.createdAt,
    );

    setState(() {
      _expenses.add(removedCopy);
      _sortExpenses();
    });
    _saveAll();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Помечено как удалённое: ${removed.name} — ${removed.amount.toStringAsFixed(2)} $_currency',
        ),
        action: SnackBarAction(
          label: 'Отменить',
          onPressed: () {
            final pos = _expenses.indexWhere((x) => x.id == removedCopy.id);
            if (pos != -1) {
              setState(() {
                _expenses.removeAt(pos);
                _expenses.insert(
                  removedIndex,
                  Expense(
                    id: removed.id,
                    name: removed.name,
                    amount: removed.amount,
                    description: removed.description,
                    isDeleted: false,
                    createdAt: removed.createdAt,
                  ),
                );
                _sortExpenses();
              });
              _saveAll();
            }
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _confirmResetAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтверждение'),
        content: const Text('Все данные будут удалены. Вы уверены?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('expenses');
              await prefs.remove('currency');
              setState(() {
                _expenses.clear();
                _currency = '';
              });
              Navigator.of(ctx).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _askCurrencyIfEmpty();
              });
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  List<String> _calculateDebts() {
    final active = _expenses.where((e) => !e.isDeleted).toList();
    if (active.isEmpty) return [];

    final totals = <String, double>{};
    for (var e in active) {
      totals[e.name] = (totals[e.name] ?? 0) + e.amount;
    }

    final participants = totals.keys.length;
    if (participants == 0) return [];

    final total = totals.values.fold(0.0, (a, b) => a + b);
    final perPerson = total / participants;

    final balances = <String, double>{};
    totals.forEach((name, sum) {
      balances[name] = sum - perPerson;
    });

    final creditors = balances.entries
        .where((e) => e.value > 0.01)
        .map((e) => {'name': e.key, 'amount': e.value})
        .toList();
    final debtors = balances.entries
        .where((e) => e.value < -0.01)
        .map((e) => {'name': e.key, 'amount': -e.value})
        .toList();

    creditors.sort(
      (a, b) => (b['amount'] as double).compareTo(a['amount'] as double),
    );
    debtors.sort(
      (a, b) => (b['amount'] as double).compareTo(a['amount'] as double),
    );

    final result = <String>[];
    int i = 0, j = 0;
    while (i < debtors.length && j < creditors.length) {
      double debtAmt = debtors[i]['amount'] as double;
      double credAmt = creditors[j]['amount'] as double;
      final transfer = debtAmt < credAmt ? debtAmt : credAmt;

      final from = debtors[i]['name'] as String;
      final to = creditors[j]['name'] as String;
      result.add('$from → $to: ${transfer.toStringAsFixed(2)} $_currency');

      debtors[i]['amount'] = (debtors[i]['amount'] as double) - transfer;
      creditors[j]['amount'] = (creditors[j]['amount'] as double) - transfer;

      if ((debtors[i]['amount'] as double) < 0.01) i++;
      if ((creditors[j]['amount'] as double) < 0.01) j++;
    }

    return result;
  }

  void _showDebts() {
    final r = _calculateDebts();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Кто кому должен'),
        content: r.isEmpty
            ? const Text('Нет данных для расчёта')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: r.map((s) => Text(s)).toList(),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseTile(Expense e, int index) {
    final titleStyle = e.isDeleted
        ? const TextStyle(
            color: Colors.grey,
            decoration: TextDecoration.lineThrough,
          )
        : const TextStyle(fontWeight: FontWeight.w600);
    final subtitleStyle = e.isDeleted
        ? const TextStyle(
            color: Colors.grey,
            decoration: TextDecoration.lineThrough,
          )
        : const TextStyle(color: Colors.black54);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: e.isDeleted
              ? Colors.grey.shade300
              : Colors.teal.shade100,
          child: Text(
            e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
            style: TextStyle(
              color: e.isDeleted ? Colors.grey.shade600 : Colors.teal.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          '${e.name} — ${e.amount.toStringAsFixed(2)} $_currency',
          style: titleStyle,
        ),
        subtitle: Text(
          e.description.isEmpty ? '(без описания)' : e.description,
          style: subtitleStyle,
        ),
        trailing: e.isDeleted
            ? const Icon(Icons.remove_circle_outline, color: Colors.grey)
            : Chip(
                label: Text(
                  '${e.amount.toStringAsFixed(0).padLeft(0)} $_currency',
                ),
                backgroundColor: Colors.teal.shade50,
              ),
        onLongPress: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Удалить запись окончательно?'),
              content: const Text(
                'Эту запись можно будет восстановить только вручную.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _expenses.removeWhere((x) => x.id == e.id);
                    });
                    _saveAll();
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Удалить'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _sortExpenses();

    final activeCount = _expenses.where((e) => !e.isDeleted).length;
    final deletedCount = _expenses.where((e) => e.isDeleted).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Smart Split ${_currency.isNotEmpty ? "($_currency)" : ""}',
        ),
        actions: [
          IconButton(
            tooltip: 'Изменить валюту',
            icon: const Icon(Icons.attach_money),
            onPressed: _changeCurrency,
          ),
          IconButton(
            tooltip: 'Рассчитать',
            icon: const Icon(Icons.calculate),
            onPressed: _showDebts,
          ),
          IconButton(
            tooltip: 'Сбросить всё',
            icon: const Icon(Icons.delete_forever),
            onPressed: _confirmResetAll,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              // Card with input fields
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Имя',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Сумма',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Описание (опционально)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _addExpense,
                            icon: const Icon(Icons.add),
                            label: const Text('Добавить трату'),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _nameController.clear();
                                _amountController.clear();
                                _descriptionController.clear();
                              });
                            },
                            icon: const Icon(Icons.clear),
                            label: const Text('Очистить'),
                          ),
                          const Spacer(),
                          Text(
                            'Активных: $activeCount',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Удалённых: $deletedCount',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // List
              Expanded(
                child: _expenses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 56,
                              color: Colors.teal.shade100,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Список пуст',
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Добавьте первую трату через форму выше',
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _expenses.length,
                        itemBuilder: (ctx, index) {
                          final e = _expenses[index];
                          if (!e.isDeleted) {
                            return Dismissible(
                              key: ValueKey(e.id),
                              direction: DismissDirection.startToEnd,
                              onDismissed: (_) =>
                                  _markDeletedAndMoveToBottom(index),
                              background: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.only(left: 16),
                                alignment: Alignment.centerLeft,
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                              ),
                              child: _buildExpenseTile(e, index),
                            );
                          } else {
                            return Opacity(
                              opacity: 0.6,
                              child: _buildExpenseTile(e, index),
                            );
                          }
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
