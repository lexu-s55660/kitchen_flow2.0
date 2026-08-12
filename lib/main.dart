import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String _webAppUrl =
    'https://script.google.com/macros/s/AKfycby0Vca_oiDXY42UGURAYPDXa3ZGE8wKpC0PCNjGwj3ui18XR6miRERe81G_M6GKYa8w/exec';

void main() {
  runApp(const KitchenFlowApp());
}

class KitchenFlowApp extends StatelessWidget {
  const KitchenFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KitchenFlow',
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        scaffoldBackgroundColor: const Color(0xFFF2F4F8),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class RecentEntry {
  final String document;
  final String recipient;
  final String ingredient;
  final String amount;
  final String total;

  RecentEntry({
    required this.document,
    required this.recipient,
    required this.ingredient,
    required this.amount,
    required this.total,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Контроллеры первого экрана
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _totalSumController = TextEditingController();
  TextEditingController? _ingredientController;

  // Контроллер второго экрана (Добавление нового ингредиента)
  final TextEditingController _newIngredientController =
      TextEditingController();

  String _ingredientValue = '';
  String? _selectedDocument;
  String? _selectedRecipient;
  bool _isLoading = false;
  bool _isAddingIngredient = false;
  bool _isLoadingDirectory = true;

  final List<RecentEntry> _recentHistory = [];
  List<String> _directoryList = [];

  final List<String> _documents = [
    'Накладная базар',
    'Накладная метро',
    'Списание персонала',
    'Порча',
    'Независимое списание',
    'Перемещение в заведения',
    'Перемещение Бар-Кухня/Кухня-Бар',
    'Инвентаризация',
  ];

  final List<String> _recipients = [
    'Бар',
    'Кухня',
    'Каракёй',
    'Заготовочный цех',
    'Щегол',
    'Сойка to-go',
    'Сойка cafe',
    'Сойка Grand',
  ];

  static const Map<String, String> _enToRuMap = {
    'q': 'й',
    'w': 'ц',
    'e': 'у',
    'r': 'к',
    't': 'е',
    'y': 'н',
    'u': 'г',
    'i': 'ш',
    'o': 'щ',
    'p': 'з',
    '[': 'х',
    ']': 'ъ',
    'a': 'ф',
    's': 'ы',
    'd': 'в',
    'f': 'а',
    'g': 'п',
    'h': 'р',
    'j': 'о',
    'k': 'л',
    'l': 'д',
    ';': 'ж',
    "'": 'э',
    'z': 'я',
    'x': 'ч',
    'c': 'с',
    'v': 'м',
    'b': 'и',
    'n': 'т',
    'm': 'ь',
    ',': 'б',
    '.': 'ю',
    '`': 'ё',
  };

  @override
  void initState() {
    super.initState();
    _fetchDirectory();
  }

  // Расчет суммы для ЛАВАША по 15 руб/шт
  void _autoCalculateTotalIfLavash() {
    final ingName = _ingredientValue.trim().toUpperCase();
    if (ingName.contains('ЛАВАШ')) {
      final double amount =
          double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
      if (amount > 0) {
        final double calculatedTotal = amount * 15;
        _totalSumController.text = calculatedTotal.toStringAsFixed(2);
      }
    }
  }

  Future<void> _fetchDirectory() async {
    try {
      final response = await http.get(Uri.parse(_webAppUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> ingredients = data['ingredients'] ?? [];
        final List<dynamic> dishes = data['dishes'] ?? [];

        final Set<String> combined = {};
        for (var item in ingredients) {
          if (item != null && item.toString().isNotEmpty) {
            combined.add(item.toString().trim());
          }
        }
        for (var item in dishes) {
          if (item != null && item.toString().isNotEmpty) {
            combined.add(item.toString().trim());
          }
        }

        setState(() {
          _directoryList = combined.toList();
          _isLoadingDirectory = false;
        });
      }
    } catch (_) {
      setState(() {
        _isLoadingDirectory = false;
      });
    }
  }

  String _convertEnToRu(String input) {
    final StringBuffer buffer = StringBuffer();
    final lower = input.toLowerCase();
    for (int i = 0; i < lower.length; i++) {
      final char = lower[i];
      buffer.write(_enToRuMap[char] ?? char);
    }
    return buffer.toString();
  }

  // Проверка типа перемещения
  bool get _isTransfer =>
      _selectedDocument == 'Перемещение в заведения' ||
      _selectedDocument == 'Перемещение Бар-Кухня/Кухня-Бар';

  // Динамический заголовок для получателя
  String get _recipientLabel =>
      _selectedDocument == 'Перемещение Бар-Кухня/Кухня-Бар'
      ? 'Кому (Бар-Кухня/Кухня-Бар) *'
      : 'Кому (Цех/Склад) *';

  bool get _isSumRequired =>
      _selectedDocument == 'Накладная базар' ||
      _selectedDocument == 'Накладная метро';

  double get _unitPrice {
    final double amount =
        double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
    final double total =
        double.tryParse(_totalSumController.text.replaceAll(',', '.')) ?? 0;
    if (amount > 0 && total > 0) {
      return total / amount;
    }
    return 0;
  }

  // Метод добавления нового ингредиента в Справочник
  Future<void> _addNewIngredient() async {
    final newIngName = _newIngredientController.text.trim();
    if (newIngName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите наименование ингредиента!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isAddingIngredient = true;
    });

    try {
      final payload = jsonEncode({
        'action': 'add_ingredient',
        'ingredient': newIngName,
      });

      await http.post(
        Uri.parse(_webAppUrl),
        headers: {'Content-Type': 'text/plain;charset=utf-8'},
        body: payload,
      );

      if (!mounted) return;

      if (!_directoryList.contains(newIngName)) {
        _directoryList.add(newIngName);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Ингредиент "$newIngName" успешно добавлен в справочник!',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      _newIngredientController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Ошибка добавления: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAddingIngredient = false;
        });
      }
    }
  }

  Future<void> _sendData() async {
    final ingredientText = _ingredientValue.trim();
    final amountText = _amountController.text.trim();
    final totalSumText = _totalSumController.text.trim();

    if (_selectedDocument == null ||
        (_isTransfer && _selectedRecipient == null) ||
        ingredientText.isEmpty ||
        amountText.isEmpty ||
        (_isSumRequired && totalSumText.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните все обязательные поля!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final payload = jsonEncode({
        'document': _selectedDocument,
        'recipient': _isTransfer ? _selectedRecipient : '',
        'ingredient': ingredientText,
        'amount': amountText,
        'unit': '',
        'total': _isSumRequired ? totalSumText : '',
      });

      await http.post(
        Uri.parse(_webAppUrl),
        headers: {'Content-Type': 'text/plain;charset=utf-8'},
        body: payload,
      );

      if (!mounted) return;

      _recentHistory.insert(
        0,
        RecentEntry(
          document: _selectedDocument!,
          recipient: _selectedRecipient ?? '',
          ingredient: ingredientText,
          amount: amountText,
          total: _isSumRequired ? totalSumText : '',
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Добавлено: $ingredientText ($amountText)'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      setState(() {
        _amountController.clear();
        _totalSumController.clear();
        _ingredientValue = '';
        _ingredientController?.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Ошибка отправки: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteLastEntry(RecentEntry entry) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final payload = jsonEncode({
        'action': 'delete_last',
        'document': entry.document,
        'recipient': entry.recipient,
        'ingredient': entry.ingredient,
        'amount': entry.amount,
        'total': entry.total,
      });

      await http.post(
        Uri.parse(_webAppUrl),
        headers: {'Content-Type': 'text/plain;charset=utf-8'},
        body: payload,
      );
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _recentHistory.remove(entry);
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ Удалено из таблицы: ${entry.ingredient}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'KitchenFlow',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.deepOrange,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              Tab(icon: Icon(Icons.edit_note), text: 'Ввод данных'),
              Tab(icon: Icon(Icons.add_box), text: 'Ингредиент'),
              Tab(icon: Icon(Icons.info_outline), text: 'О программе'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ================= ВКЛАДКА 1: Ввод данных =================
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _selectedDocument,
                            decoration: const InputDecoration(
                              labelText: 'Документ *',
                              prefixIcon: Icon(Icons.description),
                              border: OutlineInputBorder(),
                            ),
                            items: _documents.map((doc) {
                              return DropdownMenuItem(
                                value: doc,
                                child: Text(
                                  doc,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedDocument = val;
                              });
                            },
                          ),
                          if (_isTransfer) ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _selectedRecipient,
                              decoration: InputDecoration(
                                labelText: _recipientLabel,
                                prefixIcon: const Icon(Icons.store),
                                border: const OutlineInputBorder(),
                              ),
                              items: _recipients.map((rec) {
                                return DropdownMenuItem(
                                  value: rec,
                                  child: Text(
                                    rec,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedRecipient = val;
                                });
                              },
                            ),
                          ],
                          const SizedBox(height: 12),
                          Autocomplete<String>(
                            optionsBuilder:
                                (TextEditingValue textEditingValue) {
                                  final query = textEditingValue.text.trim();
                                  if (query.isEmpty) {
                                    return const Iterable<String>.empty();
                                  }

                                  final ruQuery = _convertEnToRu(query);

                                  return _directoryList.where((String option) {
                                    final lowerOption = option.toLowerCase();
                                    return lowerOption.contains(
                                          query.toLowerCase(),
                                        ) ||
                                        lowerOption.contains(
                                          ruQuery.toLowerCase(),
                                        );
                                  });
                                },
                            onSelected: (String selection) {
                              _ingredientValue = selection;
                              _autoCalculateTotalIfLavash();
                            },
                            fieldViewBuilder:
                                (
                                  context,
                                  controller,
                                  focusNode,
                                  onFieldSubmitted,
                                ) {
                                  _ingredientController = controller;
                                  return TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    onChanged: (val) {
                                      _ingredientValue = val;
                                      _autoCalculateTotalIfLavash();
                                    },
                                    decoration: InputDecoration(
                                      labelText:
                                          'Наименование (Ингредиент / Блюдо) *',
                                      prefixIcon: const Icon(
                                        Icons.restaurant_menu,
                                      ),
                                      border: const OutlineInputBorder(),
                                      suffixIcon: _isLoadingDirectory
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: Padding(
                                                padding: EdgeInsets.all(12.0),
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                            )
                                          : null,
                                    ),
                                  );
                                },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) {
                              _autoCalculateTotalIfLavash();
                              setState(() {});
                            },
                            decoration: const InputDecoration(
                              labelText: 'Количество *',
                              prefixIcon: Icon(Icons.scale),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text(
                                'Быстро: ',
                                style: TextStyle(color: Colors.grey),
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Wrap(
                                    spacing: 6,
                                    children:
                                        [
                                          '0,100 кг',
                                          '0,200 кг',
                                          '0,500 кг',
                                          '1 кг / шт',
                                        ].map((preset) {
                                          return ActionChip(
                                            label: Text(
                                              preset,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                            onPressed: () {
                                              final val = preset.split(' ')[0];
                                              setState(() {
                                                _amountController.text = val;
                                                _autoCalculateTotalIfLavash();
                                              });
                                            },
                                          );
                                        }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_isSumRequired) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _totalSumController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Общая сумма из накладной (₽) *',
                                prefixIcon: Icon(Icons.currency_ruble),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            if (_unitPrice > 0) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Себестоимость: ${_unitPrice.toStringAsFixed(2)} ₽ / ед.',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _isLoading ? null : _sendData,
                              icon: const Icon(Icons.send),
                              label: Text(
                                _isLoading ? 'ОТПРАВКА...' : 'ОТПРАВИТЬ',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'История текущей сессии',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_recentHistory.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          'Записи пока отсутствуют',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _recentHistory.length,
                      itemBuilder: (context, index) {
                        final entry = _recentHistory[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(
                              entry.ingredient.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${entry.document}${entry.recipient.isNotEmpty ? " -> ${entry.recipient}" : ""} | ${entry.amount} ед. ${entry.total.isNotEmpty ? "(${entry.total} ₽)" : ""}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: _isLoading
                                  ? null
                                  : () => _deleteLastEntry(entry),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            // ================= ВКЛАДКА 2: Добавить ингредиент =================
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Пополнение справочника',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Новый ингредиент автоматически запишется в столбец A листа "Справочник" и сразу появится во всплывающем списке.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _newIngredientController,
                        decoration: const InputDecoration(
                          labelText: 'Наименование нового ингредиента *',
                          prefixIcon: Icon(Icons.post_add),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _isAddingIngredient
                              ? null
                              : _addNewIngredient,
                          icon: const Icon(Icons.add_circle_outline),
                          label: Text(
                            _isAddingIngredient
                                ? 'СОХРАНЕНИЕ...'
                                : 'ДОБАВИТЬ В СПРАВОЧНИК',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ================= ВКЛАДКА 3: О программе =================
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.eco,
                          size: 64,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'KitchenFlow',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Версия 1.0.0',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Divider(height: 32, thickness: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.restaurant,
                          color: Colors.deepOrange,
                        ),
                        title: const Text('Организация'),
                        subtitle: const Text(
                          'Кафе «Розмарин»',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.person,
                          color: Colors.deepOrange,
                        ),
                        title: const Text('Автор проекта'),
                        subtitle: const Text(
                          'Рудометов А.С.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.check_circle_outline,
                          color: Colors.green,
                        ),
                        title: const Text('Назначение'),
                        subtitle: const Text(
                          'Учет списаний, приходов и перемещений ингредиентов.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
