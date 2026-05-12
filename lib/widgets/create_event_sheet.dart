import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import '../theme/app_theme.dart';
import 'point_notification_overlay.dart';

class CreateEventSheet extends StatefulWidget {
  const CreateEventSheet({super.key});

  @override
  State<CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends State<CreateEventSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  String _selectedCategory = 'Social';
  final List<Map<String, dynamic>> _categories = [
    {'id': 'Social', 'icon': Icons.people_outline_rounded, 'label': 'Sosyal'},
    {'id': 'Sports', 'icon': Icons.sports_basketball_rounded, 'label': 'Spor'},
    {'id': 'Study', 'icon': Icons.menu_book_rounded, 'label': 'Ders'},
    {'id': 'Food', 'icon': Icons.restaurant_rounded, 'label': 'Yemek'},
    {'id': 'Games', 'icon': Icons.sports_esports_rounded, 'label': 'Oyun'},
  ];
  bool _isLive = false;
  bool _isSubmitting = false;
  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  DateTime _endDate = DateTime.now().add(const Duration(hours: 2));
  TimeOfDay _endTime = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 2)));

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(bool isStart) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now().subtract(const Duration(days: 0)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      locale: const Locale('tr', 'TR'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.accent,
            onPrimary: Colors.black,
            surface: AppTheme.surface3,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: isStart ? _startTime : _endTime,
      );

      if (pickedTime != null) {
        setState(() {
          if (isStart) {
            _startDate = pickedDate;
            _startTime = pickedTime;
          } else {
            _endDate = pickedDate;
            _endTime = pickedTime;
          }
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final start = DateTime(_startDate.year, _startDate.month, _startDate.day, _startTime.hour, _startTime.minute);
    final end = DateTime(_endDate.year, _endDate.month, _endDate.day, _endTime.hour, _endTime.minute);

    if (end.isBefore(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitiş zamanı başlangıçtan önce olamaz!')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final provider = context.read<AppData>();
    final error = await provider.startEvent(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      location: _locationController.text.trim(),
      isLive: _isLive,
      startAt: start,
      endAt: end,
      category: _selectedCategory,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (error == null) {
        showPointOverlay(context, -1, 'Etkinlik Başlatma');
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Etkinlik başarıyla oluşturuldu! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ETKİNLİK BAŞLAT',
                    style: TextStyle(
                      fontFamily: 'Cormorant Garamond',
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppTheme.muted, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Etkinlik harika bir enerji kaynağıdır! (3+ Kişi = +2 Puan)',
                style: TextStyle(color: AppTheme.muted, fontSize: 13),
              ),
              const SizedBox(height: 32),
              _buildTextField(
                controller: _titleController,
                label: 'BAŞLIK',
                hint: 'Örn: Bahar Şenliği Konseri',
                validator: (v) => v!.isEmpty ? 'Gerekli' : null,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _locationController,
                label: 'MEKAN',
                hint: 'Örn: ODTÜ Devrim',
                validator: (v) => v!.isEmpty ? 'Gerekli' : null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildDateTimePicker(
                      label: 'BAŞLANGIÇ',
                      date: _startDate,
                      time: _startTime,
                      onTap: () => _pickDateTime(true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDateTimePicker(
                      label: 'BİTİŞ',
                      date: _endDate,
                      time: _endTime,
                      onTap: () => _pickDateTime(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const SizedBox(height: 20),
              const Text(
                'KATEGORİ',
                style: TextStyle(
                  fontFamily: 'Space Mono',
                  fontSize: 10,
                  letterSpacing: 2,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat['id'];
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedCategory = cat['id']);
                      },
                      child: Container(
                        width: 70,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.accent.withOpacity(0.1) : AppTheme.surface3,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppTheme.accent : AppTheme.border.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(cat['icon'] as IconData, size: 24, color: isSelected ? AppTheme.accent : AppTheme.muted),
                            const SizedBox(height: 4),
                            Text(
                              cat['label'],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? AppTheme.accent : AppTheme.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _descriptionController,
                label: 'AÇIKLAMA',
                hint: 'Etkinlik hakkında bilgi ver...',
                maxLines: 3,
                validator: (v) => v!.isEmpty ? 'Gerekli' : null,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'CANLI ETKİNLİK',
                  style: TextStyle(
                    fontFamily: 'Space Mono',
                    fontSize: 12,
                    letterSpacing: 1,
                    color: AppTheme.text,
                  ),
                ),
                subtitle: const Text(
                  'Şu an gerçekleşiyor mu?',
                  style: TextStyle(color: AppTheme.muted2, fontSize: 10),
                ),
                value: _isLive,
                activeColor: AppTheme.accent,
                onChanged: (v) => setState(() => _isLive = v),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : () {
                    HapticFeedback.lightImpact();
                    _submit();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                          'ETKİNLİĞİ OLUŞTUR',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimePicker({
    required String label,
    required DateTime date,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Space Mono',
            fontSize: 10,
            letterSpacing: 2,
            color: AppTheme.accent,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface3,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: AppTheme.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${date.day}/${date.month} ${time.format(context)}',
                    style: const TextStyle(color: AppTheme.text, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Space Mono',
            fontSize: 10,
            letterSpacing: 2,
            color: AppTheme.accent,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(color: AppTheme.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.muted.withOpacity(0.5)),
            filled: true,
            fillColor: AppTheme.surface3,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}
