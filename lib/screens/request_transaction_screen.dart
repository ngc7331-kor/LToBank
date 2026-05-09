import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bank_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';

class RequestTransactionScreen extends StatefulWidget {
  final BankTransaction? initialTransaction;
  const RequestTransactionScreen({super.key, this.initialTransaction});

  @override
  State<RequestTransactionScreen> createState() => _RequestTransactionScreenState();
}

class _RequestTransactionScreenState extends State<RequestTransactionScreen> {
  late final TextEditingController _amountController;
  late final TextEditingController _dateController;
  final db = DatabaseService();
  final auth = AuthService();
  
  DateTime _selectedDate = DateTime.now();
  String _selectedType = '입금';
  String _selectedTarget = 'cw';
  bool _isLoading = false;

  bool get _isEditMode => widget.initialTransaction != null;

  @override
  void initState() {
    super.initState();
    final initTx = widget.initialTransaction;
    
    _amountController = TextEditingController(text: initTx?.amount.toString() ?? '');
    _dateController = TextEditingController(text: initTx?.date ?? DateTime.now().toString().split(' ')[0]);
    
    if (initTx != null) {
      _selectedType = initTx.type;
      _selectedTarget = initTx.name;
      try {
        _selectedDate = DateTime.parse(initTx.date);
      } catch (e) {
        _selectedDate = DateTime.now();
      }
    }
  }

  void _submitRequest() async {
    final amountText = _amountController.text.replaceAll(',', '');
    final amount = int.tryParse(amountText) ?? 0;
    
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('올바른 금액을 입력해주세요.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final tx = BankTransaction(
      id: _isEditMode ? widget.initialTransaction!.id : '',
      date: _dateController.text,
      name: _selectedTarget,
      type: _selectedType,
      amount: amount,
      balance: 0,
      recorder: auth.userEmail ?? '알 수 없음',
      status: 'pending',
    );

    try {
      if (_isEditMode) {
        await db.updatePendingTransaction(tx.id, tx);
      } else {
        await db.requestTransaction(tx);
      }
      
      // [요청/수정] 관리자(태오)에게 FCM 푸시 발송
      try {
        final amountStr = amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
        final nameStr = _selectedTarget == 'cw' ? '채원' : '도권';
        final actionStr = _isEditMode ? '수정' : '요청';
        await FCMService().sendPushMessage(
          targetRoleOrName: 'admin',
          title: '거래 승인 $actionStr',
          body: '$nameStr이가 $_selectedType ${amountStr}원을 거래 $actionStr하였습니다.',
        );
      } catch (e) {
        print('Push notification error: $e');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditMode ? '🎉 거래 수정이 완료되었습니다!' : '🎉 거래 요청이 완료되었습니다! 아빠의 승인을 기다려주세요.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 작업 중 오류 발생: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isEditMode ? '거래 수정' : '거래 등록', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel('거래 일자'),
            const SizedBox(height: 12),
            _buildDateInput(),
            const SizedBox(height: 32),
            _buildSectionLabel('거래 종류'),
            const SizedBox(height: 12),
            _buildSegmentedControl(_selectedType, ['입금', '출금'], (val) {
              setState(() => _selectedType = val);
            }),
            const SizedBox(height: 32),
            _buildSectionLabel('대상 전용 계좌'),
            const SizedBox(height: 12),
            _buildSegmentedControl(_selectedTarget, ['cw', 'dk'], (val) {
              setState(() => _selectedTarget = val);
            }),
            const SizedBox(height: 32),
            _buildAmountInput(),
            const SizedBox(height: 48),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateInput() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2101),
        );
        if (picked != null) {
          setState(() {
            _selectedDate = picked;
            _dateController.text = picked.toString().split(' ')[0];
          });
        }
      },
      child: TextField(
        controller: _dateController,
        enabled: false, // 터치로 캘린더 띄우기 위해 비활성화 (필요시 직접 입력 가능하게 변경 가능)
        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.calendar_today_rounded, color: Color(0xFF6366F1), size: 20),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.notoSansKr(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Colors.blueGrey[600],
      ),
    );
  }

  Widget _buildSegmentedControl(String selected, List<String> options, Function(String) onChanged) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: options.map((opt) {
          final isSel = selected == opt;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSel ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSel ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ] : [],
                ),
                child: Center(
                  child: Text(
                    opt == 'cw' ? '채원' : (opt == 'dk' ? '도권' : opt),
                    style: GoogleFonts.notoSansKr(
                      fontSize: 15,
                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                      color: isSel ? const Color(0xFF0F172A) : Colors.blueGrey[300],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('금액 입력'),
        const SizedBox(height: 12),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: GoogleFonts.outfit(color: const Color(0xFFE2E8F0)),
            suffixText: '원',
            suffixStyle: GoogleFonts.notoSansKr(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: _isLoading 
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text('거래 요청하기', style: GoogleFonts.notoSansKr(fontSize: 18, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
