import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const SplitwiseLiteApp());
}

class SplitwiseLiteApp extends StatelessWidget {
  const SplitwiseLiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seed = Colors.teal;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Splitwise Lite',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        appBarTheme: const AppBarTheme(centerTitle: true),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

/* ===========================
   MODELS
   =========================== */

class Member {
  final String id;
  final String name;
  final int createdAt;
  bool isDeleted;

  Member({
    required this.id,
    required this.name,
    required this.createdAt,
    this.isDeleted = false,
  });

  factory Member.fromJson(Map<String, dynamic> j) => Member(
    id: j['id'],
    name: j['name'],
    createdAt: j['createdAt'] ?? 0,
    isDeleted: j['isDeleted'] ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt,
    'isDeleted': isDeleted,
  };
}

class Expense {
  final String id;
  final String payerId; // кто платил
  final List<String> participantIds; // кто участвует
  final double amount;
  final String description;
  final int createdAt;
  bool isDeleted;

  Expense({
    required this.id,
    required this.payerId,
    required this.participantIds,
    required this.amount,
    required this.description,
    required this.createdAt,
    this.isDeleted = false,
  });

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
    id: j['id'],
    payerId: j['payerId'],
    participantIds: (j['participantIds'] as List)
        .map((e) => e as String)
        .toList(),
    amount: (j['amount'] as num).toDouble(),
    description: j['description'] ?? '',
    createdAt: j['createdAt'] ?? 0,
    isDeleted: j['isDeleted'] ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'payerId': payerId,
    'participantIds': participantIds,
    'amount': amount,
    'description': description,
    'createdAt': createdAt,
    'isDeleted': isDeleted,
  };
}

/* ===========================
   STORAGE + APP STATE
   =========================== */

class AppData {
  List<Member> members;
  List<Expense> expenses;
  String currency;

  AppData({
    required this.members,
    required this.expenses,
    required this.currency,
  });

  factory AppData.empty() => AppData(members: [], expenses: [], currency: '');

  Map<String, dynamic> toJson() => {
    'members': members.map((m) => m.toJson()).toList(),
    'expenses': expenses.map((e) => e.toJson()).toList(),
    'currency': currency,
  };

  factory AppData.fromJson(Map<String, dynamic> j) => AppData(
    members: (j['members'] as List).map((e) => Member.fromJson(e)).toList(),
    expenses: (j['expenses'] as List).map((e) => Expense.fromJson(e)).toList(),
    currency: j['currency'] ?? '',
  );
}

class AppRepository {
  static const _key = 'splitwise_lite_appdata_v1';

  static Future<AppData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_key);
    if (str == null) return AppData.empty();
    try {
      return AppData.fromJson(jsonDecode(str));
    } catch (_) {
      return AppData.empty();
    }
  }

  static Future<void> save(AppData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/* ===========================
   HOME (Navigation + Screens)
   =========================== */

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

enum TabItem { members, expenses, summary }

class _HomePageState extends State<HomePage> {
  AppData data = AppData.empty();
  TabItem current = TabItem.members;
  bool hideInactive = false;

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  Future<void> _initLoad() async {
    final loaded = await AppRepository.load();
    setState(() {
      data = loaded;
    });
    if (data.currency.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _askCurrency();
      });
    }
  }

  Future<void> _persist() async => AppRepository.save(data);

  Future<void> _askCurrency() async {
    final c = TextEditingController(text: 'USD');
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Валюта по умолчанию'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(
            labelText: 'Например: USD, EUR, RUB',
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              final v = c.text.trim().toUpperCase();
              if (v.isEmpty) return;
              setState(() => data.currency = v);
              _persist();
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _changeCurrency() {
    final c = TextEditingController(text: data.currency);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Изменить валюту'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(labelText: 'Валюта'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = c.text.trim().toUpperCase();
              if (v.isEmpty) return;
              setState(() => data.currency = v);
              _persist();
              Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтверждение'),
        content: const Text(
          'Удалить всех участников и все траты безвозвратно?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              await AppRepository.clear();
              setState(() => data = AppData.empty());
              Navigator.pop(ctx);
              _askCurrency();
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(switch (current) {
          TabItem.members => 'Участники',
          TabItem.expenses => 'Траты',
          TabItem.summary => 'Кто кому должен',
        }),
        actions: [
          IconButton(
            tooltip: 'Изменить валюту',
            onPressed: _changeCurrency,
            icon: const Icon(Icons.attach_money),
          ),
          IconButton(
            tooltip: 'Скрыть/показать неактивные',
            onPressed: () => setState(() => hideInactive = !hideInactive),
            icon: Icon(
              hideInactive
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Сбросить всё',
            onPressed: _confirmClearAll,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              data.currency.isEmpty ? '' : 'Валюта: ${data.currency}',
              style: TextStyle(
                color: color.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: current.index,
        onDestinationSelected: (i) =>
            setState(() => current = TabItem.values[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Участники',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Траты',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: 'Итоги',
          ),
        ],
      ),
      body: switch (current) {
        TabItem.members => MembersScreen(
          data: data,
          hideInactive: hideInactive,
          onChanged: () {
            setState(() {});
            _persist();
          },
        ),
        TabItem.expenses => ExpensesScreen(
          data: data,
          hideInactive: hideInactive,
          onChanged: () {
            setState(() {});
            _persist();
          },
        ),
        TabItem.summary => SummaryScreen(
          data: data,
          onChanged: () {
            setState(() {});
            _persist();
          },
        ),
      },
      floatingActionButton: switch (current) {
        TabItem.members => AddMemberFAB(
          onAdd: (name) {
            final id = DateTime.now().millisecondsSinceEpoch.toString();
            data.members.add(
              Member(
                id: id,
                name: name.trim(),
                createdAt: DateTime.now().millisecondsSinceEpoch,
              ),
            );
            data.members.sort((a, b) {
              if (a.isDeleted == b.isDeleted) {
                return a.createdAt.compareTo(b.createdAt);
              }
              return a.isDeleted ? 1 : -1;
            });
            setState(() {});
            _persist();
          },
        ),
        TabItem.expenses => AddExpenseFAB(
          members: data.members.where((m) => !m.isDeleted).toList(),
          currency: data.currency.isEmpty ? 'USD' : data.currency,
          onAdd: (payerId, participants, amount, desc) {
            final id = DateTime.now().millisecondsSinceEpoch.toString();
            data.expenses.add(
              Expense(
                id: id,
                payerId: payerId,
                participantIds: participants,
                amount: amount,
                description: desc,
                createdAt: DateTime.now().millisecondsSinceEpoch,
              ),
            );
            data.expenses.sort((a, b) {
              if (a.isDeleted == b.isDeleted) {
                return a.createdAt.compareTo(b.createdAt);
              }
              return a.isDeleted ? 1 : -1;
            });
            setState(() {});
            _persist();
          },
        ),
        TabItem.summary => null,
      },
    );
  }
}

/* ===========================
   MEMBERS SCREEN
   =========================== */

class MembersScreen extends StatelessWidget {
  final AppData data;
  final bool hideInactive;
  final VoidCallback onChanged;

  const MembersScreen({
    super.key,
    required this.data,
    required this.hideInactive,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final list = data.members.toList()
      ..sort((a, b) {
        if (a.isDeleted == b.isDeleted) {
          return a.createdAt.compareTo(b.createdAt);
        }
        return a.isDeleted ? 1 : -1;
      });

    final view = hideInactive ? list.where((m) => !m.isDeleted) : list;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: list.isEmpty
          ? const _EmptyState(
              icon: Icons.group_add_outlined,
              title: 'Нет участников',
              subtitle: 'Нажмите + чтобы добавить первого участника',
            )
          : ListView(
              children: [
                const SizedBox(height: 4),
                ...view.map(
                  (m) => _MemberTile(
                    member: m,
                    onSoftDelete: () {
                      m.isDeleted = true;
                      onChanged();
                    },
                    onRestore: () {
                      m.isDeleted = false;
                      onChanged();
                    },
                    onHardDelete: () {
                      data.members.removeWhere((x) => x.id == m.id);
                      // Также удалим участие в тратах данного участника
                      for (final e in data.expenses) {
                        if (e.payerId == m.id ||
                            e.participantIds.contains(m.id)) {
                          e.isDeleted = true; // мягко пометим траты
                        }
                      }
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final Member member;
  final VoidCallback onSoftDelete;
  final VoidCallback onRestore;
  final VoidCallback onHardDelete;

  const _MemberTile({
    required this.member,
    required this.onSoftDelete,
    required this.onRestore,
    required this.onHardDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDel = member.isDeleted;

    final tile = Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: isDel ? Colors.grey.shade300 : Colors.teal.shade50,
          child: Text(
            member.name.isEmpty ? '?' : member.name[0].toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDel ? Colors.grey.shade700 : Colors.teal.shade800,
            ),
          ),
        ),
        title: Text(
          member.name,
          style: TextStyle(
            decoration: isDel
                ? TextDecoration.lineThrough
                : TextDecoration.none,
            color: isDel ? Colors.grey : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: isDel
            ? const Text('Неактивен', style: TextStyle(color: Colors.grey))
            : const Text('Активен'),
        trailing: Wrap(
          spacing: 6,
          children: [
            if (!isDel)
              IconButton(
                tooltip: 'Сделать неактивным',
                icon: const Icon(Icons.block_outlined),
                onPressed: onSoftDelete,
              ),
            if (isDel)
              IconButton(
                tooltip: 'Восстановить',
                icon: const Icon(Icons.undo_outlined),
                onPressed: onRestore,
              ),
            IconButton(
              tooltip: 'Удалить навсегда',
              icon: const Icon(Icons.delete_forever_outlined),
              onPressed: () => _confirm(context, onHardDelete),
            ),
          ],
        ),
      ),
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: isDel ? 0.55 : 1.0,
      child: tile,
    );
  }

  void _confirm(BuildContext ctx, VoidCallback onOk) {
    showDialog(
      context: ctx,
      builder: (d) => AlertDialog(
        title: const Text('Удалить участника навсегда?'),
        content: const Text(
          'Его имя будет убрано из списка. Траты с его участием станут неактивными.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(d);
              onOk();
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}

class AddMemberFAB extends StatefulWidget {
  final void Function(String name) onAdd;
  const AddMemberFAB({super.key, required this.onAdd});

  @override
  State<AddMemberFAB> createState() => _AddMemberFABState();
}

class _AddMemberFABState extends State<AddMemberFAB> {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      icon: const Icon(Icons.person_add_alt_1),
      label: const Text('Добавить'),
      onPressed: _showAddDialog,
    );
  }

  void _showAddDialog() {
    final c = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          top: 10,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Новый участник',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              decoration: const InputDecoration(labelText: 'Имя'),
              autofocus: true,
              onSubmitted: (_) => _submit(ctx, c),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Отмена'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _submit(ctx, c),
                    child: const Text('Добавить'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _submit(BuildContext ctx, TextEditingController c) {
    final name = c.text.trim();
    if (name.isEmpty) return;
    widget.onAdd(name);
    Navigator.pop(ctx);
  }
}

/* ===========================
   EXPENSES SCREEN
   =========================== */

class ExpensesScreen extends StatefulWidget {
  final AppData data;
  final bool hideInactive;
  final VoidCallback onChanged;

  const ExpensesScreen({
    super.key,
    required this.data,
    required this.hideInactive,
    required this.onChanged,
  });

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  @override
  Widget build(BuildContext context) {
    final list = widget.data.expenses.toList()
      ..sort((a, b) {
        if (a.isDeleted == b.isDeleted) {
          return a.createdAt.compareTo(b.createdAt);
        }
        return a.isDeleted ? 1 : -1;
      });

    final view = widget.hideInactive ? list.where((e) => !e.isDeleted) : list;

    if (widget.data.members.where((m) => !m.isDeleted).isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: _EmptyState(
          icon: Icons.person_search_outlined,
          title: 'Нет активных участников',
          subtitle: 'Добавьте хотя бы одного участника, чтобы вносить траты',
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: list.isEmpty
          ? const _EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Нет трат',
              subtitle: 'Нажмите + чтобы добавить первую трату',
            )
          : ListView(
              children: [
                const SizedBox(height: 4),
                ...view.map(
                  (e) => _ExpenseTile(
                    expense: e,
                    data: widget.data,
                    currency: widget.data.currency.isEmpty
                        ? 'USD'
                        : widget.data.currency,
                    onSoftDelete: () {
                      e.isDeleted = true;
                      widget.onChanged();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Трата помечена как неактивная'),
                          action: SnackBarAction(
                            label: 'Отменить',
                            onPressed: () {
                              e.isDeleted = false;
                              widget.onChanged();
                            },
                          ),
                        ),
                      );
                    },
                    onRestore: () {
                      e.isDeleted = false;
                      widget.onChanged();
                    },
                    onHardDelete: () {
                      widget.data.expenses.removeWhere((x) => x.id == e.id);
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final Expense expense;
  final AppData data;
  final String currency;
  final VoidCallback onSoftDelete;
  final VoidCallback onRestore;
  final VoidCallback onHardDelete;

  const _ExpenseTile({
    required this.expense,
    required this.data,
    required this.currency,
    required this.onSoftDelete,
    required this.onRestore,
    required this.onHardDelete,
  });

  String _nameById(String id) => data.members
      .firstWhere(
        (m) => m.id == id,
        orElse: () => Member(id: id, name: '???', createdAt: 0),
      )
      .name;

  @override
  Widget build(BuildContext context) {
    final isDel = expense.isDeleted;
    final payer = _nameById(expense.payerId);
    final parts = expense.participantIds.map(_nameById).toList();

    final tile = Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isDel ? Colors.grey.shade300 : Colors.teal.shade50,
          child: Text(
            payer.isNotEmpty ? payer[0].toUpperCase() : '?',
            style: TextStyle(
              color: isDel ? Colors.grey.shade700 : Colors.teal.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          '${expense.amount.toStringAsFixed(2)} $currency',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDel ? Colors.grey : Colors.black87,
            decoration: isDel
                ? TextDecoration.lineThrough
                : TextDecoration.none,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              expense.description.isEmpty
                  ? 'Без описания'
                  : expense.description,
              style: TextStyle(
                color: isDel ? Colors.grey : Colors.black54,
                decoration: isDel
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: -8,
              children: [
                Chip(
                  label: Text('Плательщик: $payer'),
                  backgroundColor: isDel
                      ? Colors.grey.shade200
                      : Colors.teal.shade50,
                ),
                ...parts.map(
                  (p) => Chip(
                    label: Text(p),
                    backgroundColor: isDel
                        ? Colors.grey.shade200
                        : Colors.blue.shade50,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Wrap(
          spacing: 6,
          children: [
            if (!isDel)
              IconButton(
                tooltip: 'Сделать неактивным',
                icon: const Icon(Icons.block_outlined),
                onPressed: onSoftDelete,
              ),
            if (isDel)
              IconButton(
                tooltip: 'Восстановить',
                icon: const Icon(Icons.undo_outlined),
                onPressed: onRestore,
              ),
            IconButton(
              tooltip: 'Удалить навсегда',
              icon: const Icon(Icons.delete_forever_outlined),
              onPressed: () => _confirm(context, onHardDelete),
            ),
          ],
        ),
      ),
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: isDel ? 0.55 : 1.0,
      child: tile,
    );
  }

  void _confirm(BuildContext ctx, VoidCallback onOk) {
    showDialog(
      context: ctx,
      builder: (d) => AlertDialog(
        title: const Text('Удалить трату навсегда?'),
        content: const Text('Восстановить будет невозможно.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(d);
              onOk();
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}

class AddExpenseFAB extends StatefulWidget {
  final List<Member> members; // только активные
  final String currency;
  final void Function(
    String payerId,
    List<String> participantIds,
    double amount,
    String description,
  )
  onAdd;

  const AddExpenseFAB({
    super.key,
    required this.members,
    required this.currency,
    required this.onAdd,
  });

  @override
  State<AddExpenseFAB> createState() => _AddExpenseFABState();
}

class _AddExpenseFABState extends State<AddExpenseFAB> {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      icon: const Icon(Icons.add),
      label: const Text('Добавить трату'),
      onPressed: _open,
    );
  }

  void _open() {
    if (widget.members.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _AddExpenseSheet(
        members: widget.members,
        currency: widget.currency,
        onSubmit: (payer, parts, amount, desc) {
          widget.onAdd(payer, parts, amount, desc);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

class _AddExpenseSheet extends StatefulWidget {
  final List<Member> members;
  final String currency;
  final void Function(
    String payerId,
    List<String> participantIds,
    double amount,
    String description,
  )
  onSubmit;

  const _AddExpenseSheet({
    required this.members,
    required this.currency,
    required this.onSubmit,
  });

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  String? payerId;
  final Set<String> participants = {};
  final amountCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.members.isNotEmpty) {
      payerId = widget.members.first.id;
      participants.addAll(widget.members.map((m) => m.id)); // по умолчанию все
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.currency;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 10,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Новая трата',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            // Amount
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Сумма ($currency)',
                suffixIcon: const Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 10),

            // Description
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Описание (опционально)',
                suffixIcon: Icon(Icons.edit_note_outlined),
              ),
            ),
            const SizedBox(height: 10),

            // Payer
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Кто платил',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: widget.members
                  .map(
                    (m) => ChoiceChip(
                      label: Text(m.name),
                      selected: payerId == m.id,
                      onSelected: (_) => setState(() => payerId = m.id),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),

            // Participants
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Кто участвует (делят сумму)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: widget.members
                  .map(
                    (m) => FilterChip(
                      label: Text(m.name),
                      selected: participants.contains(m.id),
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            participants.add(m.id);
                          } else {
                            participants.remove(m.id);
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Добавить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
    if (amt <= 0 || payerId == null || participants.isEmpty) return;
    widget.onSubmit(payerId!, participants.toList(), amt, descCtrl.text.trim());
  }
}

/* ===========================
   SUMMARY SCREEN (DEBTS)
   =========================== */

class SummaryScreen extends StatelessWidget {
  final AppData data;
  final VoidCallback onChanged;

  const SummaryScreen({super.key, required this.data, required this.onChanged});

  Map<String, double> _computeBalances() {
    // Только активные участники/траты
    final activeMembers = {
      for (final m in data.members.where((m) => !m.isDeleted)) m.id: m,
    };
    final activeExpenses = data.expenses.where((e) => !e.isDeleted).toList();

    final balances = <String, double>{
      for (final id in activeMembers.keys) id: 0.0,
    };

    for (final e in activeExpenses) {
      // участники только активные
      final parts = e.participantIds
          .where((id) => activeMembers.containsKey(id))
          .toList();
      if (parts.isEmpty) continue;

      final payer = e.payerId;
      final share = e.amount / parts.length;

      // payer платил за всех
      if (balances.containsKey(payer)) {
        balances[payer] = (balances[payer] ?? 0) + e.amount;
      }

      // каждый участник должен свою долю
      for (final pid in parts) {
        if (balances.containsKey(pid)) {
          balances[pid] = (balances[pid] ?? 0) - share;
        }
      }
    }

    // Уберём почти нули
    balances.updateAll((key, value) {
      if (value.abs() < 0.005) return 0.0;
      return value;
    });

    return balances;
  }

  List<_Transfer> _settle(Map<String, double> balances) {
    final creditors = <_Entry>[];
    final debtors = <_Entry>[];

    balances.forEach((id, val) {
      if (val > 0.005) {
        creditors.add(_Entry(id, val));
      } else if (val < -0.005) {
        debtors.add(_Entry(id, -val));
      }
    });

    // Отсортируем для стабильности
    creditors.sort((a, b) => b.amount.compareTo(a.amount));
    debtors.sort((a, b) => b.amount.compareTo(a.amount));

    final res = <_Transfer>[];
    int i = 0, j = 0;
    while (i < debtors.length && j < creditors.length) {
      final d = debtors[i];
      final c = creditors[j];
      final t = d.amount < c.amount ? d.amount : c.amount;
      if (t <= 0) break;

      res.add(_Transfer(from: d.id, to: c.id, amount: t));

      debtors[i] = _Entry(d.id, d.amount - t);
      creditors[j] = _Entry(c.id, c.amount - t);

      if (debtors[i].amount < 0.005) i++;
      if (creditors[j].amount < 0.005) j++;
    }
    return res;
  }

  @override
  Widget build(BuildContext context) {
    final balances = _computeBalances();
    final transfers = _settle(balances);
    final currency = data.currency.isEmpty ? 'USD' : data.currency;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: transfers.isEmpty
          ? const _EmptyState(
              icon: Icons.check_circle_outline,
              title: 'Никто никому не должен',
              subtitle: 'Добавьте траты или участников',
            )
          : ListView(
              children: [
                const SizedBox(height: 6),
                ...transfers.map(
                  (t) => _TransferTile(
                    from: _nameById(t.from),
                    to: _nameById(t.to),
                    amount: t.amount,
                    currency: currency,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Балансы участников',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                ...balances.entries.map(
                  (e) => ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: e.value >= 0
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      child: Text(
                        _nameById(e.key).isNotEmpty
                            ? _nameById(e.key)[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: e.value >= 0
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(_nameById(e.key)),
                    trailing: Text(
                      '${e.value.toStringAsFixed(2)} $currency',
                      style: TextStyle(
                        color: e.value >= 0 ? Colors.green : Colors.redAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
    );
  }

  String _nameById(String id) {
    final idx = data.members.indexWhere((m) => m.id == id);
    if (idx == -1) return '???';
    return data.members[idx].name;
  }
}

class _Entry {
  final String id;
  final double amount;
  const _Entry(this.id, this.amount);
}

class _Transfer {
  final String from;
  final String to;
  final double amount;
  const _Transfer({required this.from, required this.to, required this.amount});
}

class _TransferTile extends StatelessWidget {
  final String from;
  final String to;
  final double amount;
  final String currency;

  const _TransferTile({
    required this.from,
    required this.to,
    required this.amount,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: const Icon(Icons.arrow_circle_right_outlined),
        title: Text('$from → $to'),
        trailing: Text(
          '${amount.toStringAsFixed(2)} $currency',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/* ===========================
   EMPTY STATE
   =========================== */

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: c.primary.withOpacity(0.25)),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
