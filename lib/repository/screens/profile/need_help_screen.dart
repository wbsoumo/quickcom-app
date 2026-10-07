import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:blinkit_series/repository/services/api_service.dart';

class NeedHelpScreen extends StatefulWidget {
  const NeedHelpScreen({super.key});

  @override
  State<NeedHelpScreen> createState() => _NeedHelpScreenState();
}

class _NeedHelpScreenState extends State<NeedHelpScreen> {
  List<Map<String, dynamic>> _userTickets = [];
  bool _isLoadingTickets = true;

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    setState(() {
      _isLoadingTickets = true;
    });
    final tickets = await ApiService.getUserSupportTickets();
    if (mounted) {
      setState(() {
        _userTickets = tickets;
        _isLoadingTickets = false;
      });
    }
  }

  Future<void> _openWhatsAppLiveChat() async {
    const String whatsappPhone = "916294530380";
    const String message = "Hello SB Mart Quick Support! I need assistance with my order.";
    final Uri waUri = Uri.parse("https://wa.me/$whatsappPhone?text=${Uri.encodeComponent(message)}");

    try {
      if (await canLaunchUrl(waUri)) {
        await launchUrl(waUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(waUri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not open WhatsApp. Contact us directly at +91 62945 30380"),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _openRequestCallbackBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateTicketBottomSheet(
        onTicketCreated: () {
          _fetchTickets();
        },
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'pending':
        return Colors.orange.shade700;
      case 'in_progress':
        return Colors.blue.shade700;
      case 'resolved':
        return const Color(0XFF0C831F);
      case 'closed':
        return Colors.grey.shade700;
      default:
        return Colors.orange.shade700;
    }
  }

  String _formatStatusLabel(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'pending':
        return "Pending 🟡";
      case 'in_progress':
        return "In Progress 🔵";
      case 'resolved':
        return "Resolved 🟢";
      case 'closed':
        return "Closed ⚪";
      default:
        return "Pending 🟡";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0XFFF5F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Need Help & Support",
          style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchTickets,
        color: const Color(0XFF0C831F),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP SUPPORT OPTIONS CARD
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        "How can we help you today?",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "Choose an option below to connect with our support team.",
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),

                    // Option A: Live Chat on WhatsApp
                    InkWell(
                      onTap: _openWhatsAppLiveChat,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0XFF25D366).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.chat_bubble_rounded, color: Color(0XFF25D366), size: 22),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Chat with Live Support",
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    "Connect instantly via WhatsApp (+91 62945 30380)",
                                    style: TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.black38),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 64),

                    // Option B: Request Callback / Raise Ticket
                    InkWell(
                      onTap: _openRequestCallbackBottomSheet,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0XFF0C831F).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.headset_mic_rounded, color: Color(0XFF0C831F), size: 22),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Request Call Back",
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    "Select issue details and an executive will call you",
                                    style: TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.black38),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 2. BOTTOM SECTION - MY SUPPORT TICKETS LIST
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "My Support Tickets",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20, color: Color(0XFF0C831F)),
                    onPressed: _fetchTickets,
                    tooltip: "Refresh Tickets",
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_isLoadingTickets)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: Color(0XFF0C831F)),
                  ),
                )
              else if (_userTickets.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.confirmation_number_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        "No Support Tickets Yet",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "When you request a callback or raise a query, your tickets will appear here with live status updates.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _userTickets.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final tkt = _userTickets[index];
                    final String status = (tkt['status'] ?? 'pending').toString();
                    final Color statusColor = _getStatusColor(status);
                    final String statusText = _formatStatusLabel(status);

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                tkt['ticket_number'] ?? '#TKT-UNKNOWN',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0XFF0C831F),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: statusColor.withOpacity(0.4)),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  tkt['category'] ?? 'General Support',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                              ),
                              if (tkt['sub_category'] != null && tkt['sub_category'].toString().isNotEmpty) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.chevron_right, size: 14, color: Colors.black38),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    tkt['sub_category'],
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (tkt['store_name'] != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.storefront, size: 14, color: Colors.black45),
                                const SizedBox(width: 4),
                                Text(
                                  "Store: ${tkt['store_name']}",
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              ],
                            ),
                          ],
                          if (tkt['order_number'] != null || tkt['order_id'] != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.receipt_long, size: 14, color: Colors.black45),
                                const SizedBox(width: 4),
                                Text(
                                  "Order: #${tkt['order_number'] ?? tkt['order_id']}",
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              ],
                            ),
                          ],
                          if (tkt['description'] != null && tkt['description'].toString().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              tkt['description'],
                              style: const TextStyle(fontSize: 12, color: Colors.black87),
                            ),
                          ],
                          if (tkt['admin_remarks'] != null && tkt['admin_remarks'].toString().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0XFFFFF8E1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0XFFE0E0E0)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.support_agent_rounded, size: 16, color: Color(0XFF0C831F)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Executive Remarks:",
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          tkt['admin_remarks'],
                                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              tkt['created_at'] != null ? tkt['created_at'].toString().split('.').first : '',
                              style: const TextStyle(fontSize: 10, color: Colors.black45),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// CREATE TICKET BOTTOM SHEET FORM
class _CreateTicketBottomSheet extends StatefulWidget {
  final VoidCallback onTicketCreated;

  const _CreateTicketBottomSheet({required this.onTicketCreated});

  @override
  State<_CreateTicketBottomSheet> createState() => _CreateTicketBottomSheetState();
}

class _CreateTicketBottomSheetState extends State<_CreateTicketBottomSheet> {
  final List<String> _categories = [
    "Order Issue",
    "Payment & Refund",
    "Delivery Delay",
    "Product Quality",
    "App Technical Issue",
    "Other Query"
  ];

  final Map<String, List<String>> _subCategoriesMap = {
    "Order Issue": [
      "Missing Items in Order",
      "Wrong Item Delivered",
      "Damaged / Leaking Package",
      "Cancel Active Order",
      "Other Order Issue"
    ],
    "Payment & Refund": [
      "Money Deducted but Order Failed",
      "Refund Status Inquiry",
      "Double Charged for Order",
      "Wallet Balance Issue"
    ],
    "Delivery Delay": [
      "Delivery Rider Unreachable",
      "Extremely Delayed Order",
      "Rider Not Moving on Map"
    ],
    "Product Quality": [
      "Expired Product Delivered",
      "Bad Quality Fresh Produce",
      "Seal / Packaging Broken"
    ],
    "App Technical Issue": [
      "App Crashing or Freezing",
      "Coupon Code Not Applying",
      "Location Auto-Detect Error"
    ],
    "Other Query": [
      "General Support Inquiry",
      "Store Partnership / Feedback",
      "Other Support Request"
    ],
  };

  String? _selectedCategory;
  String? _selectedSubCategory;
  int? _selectedStoreId;
  String? _selectedStoreName;

  List<Map<String, dynamic>> _userOrders = [];
  bool _isLoadingOrders = false;
  Map<String, dynamic>? _selectedOrder;
  bool _showOrderSelectionList = false;

  final TextEditingController _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _stores = [];
  bool _isLoadingStores = false;

  @override
  void initState() {
    super.initState();
    _fetchUserOrders();
    _fetchStores();
  }

  Future<void> _fetchUserOrders() async {
    setState(() {
      _isLoadingOrders = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('user_phone') ?? '';
      if (phone.isNotEmpty) {
        final orders = await ApiService.getUserOrders(phone: phone);
        if (mounted) {
          setState(() {
            _userOrders = orders;
            _isLoadingOrders = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingOrders = false;
        });
      }
    }
  }

  Future<void> _fetchStores() async {
    setState(() {
      _isLoadingStores = true;
    });
    try {
      final allStores = await ApiService.fetchAllStores();
      final currentStore = await ApiService.fetchSelectedStore();

      if (mounted) {
        setState(() {
          if (allStores.isNotEmpty) {
            _stores = allStores;
          } else if (currentStore != null) {
            _stores = [currentStore];
          }

          if (_stores.isNotEmpty) {
            if (currentStore != null && _stores.any((s) => s['id'] == currentStore['id'])) {
              _selectedStoreId = currentStore['id'];
              _selectedStoreName = currentStore['name'];
            } else {
              _selectedStoreId = _stores.first['id'];
              _selectedStoreName = _stores.first['name'];
            }
          }
          _isLoadingStores = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingStores = false;
        });
      }
    }
  }

  Future<void> _submitTicket() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a main query category."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final res = await ApiService.createSupportTicket(
      category: _selectedCategory!,
      subCategory: _selectedSubCategory,
      description: _descriptionController.text.trim(),
      storeId: _selectedStoreId,
      orderId: _selectedOrder?['id'],
      orderNumber: _selectedOrder?['order_number']?.toString(),
    );

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });

    if (res['status'] == 'success') {
      final ticketData = res['ticket'] as Map<String, dynamic>?;
      final String tktNum = ticketData?['ticket_number'] ?? '#TKT-CREATED';

      Navigator.pop(context); // Close bottom sheet
      widget.onTicketCreated(); // Refresh tickets list

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Column(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0XFF0C831F), size: 54),
              SizedBox(height: 12),
              Text(
                "Ticket Raised Successfully!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0XFF0C831F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  tktNum,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0XFF0C831F)),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "An executive will review your request and call you shortly on your registered number.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0XFF0C831F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text("Okay, Got It", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? "Failed to create ticket. Please try again."),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subCategories = _selectedCategory != null ? (_subCategoriesMap[_selectedCategory] ?? []) : [];

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.headset_mic_rounded, color: Color(0XFF0C831F), size: 24),
                    SizedBox(width: 8),
                    Text(
                      "Request Callback / Raise Ticket",
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),

            // 1. SELECT STORE DROPDOWN
            const Text("Select Store", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _selectedStoreId,
                  hint: Text(_isLoadingStores ? "Loading stores..." : "Select store branch"),
                  items: _stores.map((st) {
                    return DropdownMenuItem<int>(
                      value: st['id'],
                      child: Text(st['name'] ?? 'Store', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final selected = _stores.firstWhere((st) => st['id'] == val, orElse: () => {});
                      setState(() {
                        _selectedStoreId = val;
                        _selectedStoreName = selected['name'];
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. MAIN CATEGORY DROPDOWN
            const Text("Select Main Query", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedCategory,
                  hint: const Text("Choose support category..."),
                  items: _categories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat,
                      child: Text(cat, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCategory = val;
                      _selectedSubCategory = null;
                      if (val == "Order Issue") {
                        _showOrderSelectionList = true;
                      } else {
                        _showOrderSelectionList = false;
                        _selectedOrder = null;
                      }
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. CONDITIONAL ORDER SELECTION (Shown if Category is "Order Issue")
            if (_selectedCategory == "Order Issue") ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Select Order", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                  if (_selectedOrder != null)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showOrderSelectionList = !_showOrderSelectionList;
                        });
                      },
                      child: Text(
                        _showOrderSelectionList ? "Hide List" : "Change Order",
                        style: const TextStyle(color: Color(0XFF0C831F), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              if (_selectedOrder != null && !_showOrderSelectionList)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0XFF0C831F).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0XFF0C831F).withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0XFF0C831F), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Order #${_selectedOrder!['order_number'] ?? _selectedOrder!['id']}",
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Amount: ₹${_selectedOrder!['grand_total'] ?? _selectedOrder!['mrp_total'] ?? ''}",
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              if (_showOrderSelectionList || _selectedOrder == null) ...[
                if (_isLoadingOrders)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(color: Color(0XFF0C831F))),
                  )
                else if (_userOrders.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: const Text(
                      "No past orders found to attach.",
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _userOrders.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final ord = _userOrders[i];
                        final isSelected = _selectedOrder?['id'] == ord['id'];

                        return ListTile(
                          dense: true,
                          selected: isSelected,
                          selectedTileColor: const Color(0XFF0C831F).withOpacity(0.1),
                          title: Text(
                            "Order #${ord['order_number'] ?? ord['id']}",
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "Date: ${ord['created_at'] != null ? ord['created_at'].toString().split('T').first : ''} • Total: ₹${ord['grand_total'] ?? ord['mrp_total'] ?? ''}",
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: isSelected ? const Icon(Icons.check, color: Color(0XFF0C831F)) : null,
                          onTap: () {
                            setState(() {
                              _selectedOrder = ord;
                              _showOrderSelectionList = false; // Hide order list cleanly after selection
                            });
                          },
                        );
                      },
                    ),
                  ),
              ],
              const SizedBox(height: 16),
            ],

            // 4. SUB-CATEGORY DROPDOWN
            if (subCategories.isNotEmpty) ...[
              const Text("Select Specific Issue", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedSubCategory,
                    hint: const Text("Choose sub-query details..."),
                    items: subCategories.map((sub) {
                      return DropdownMenuItem<String>(
                        value: sub,
                        child: Text(sub, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedSubCategory = val;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 5. DESCRIPTION TEXT FIELD
            const Text("Describe Your Issue / Query", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 6),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Enter extra details or instructions for our executive...",
                hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0XFF0C831F), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 6. SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0XFF0C831F),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        "Submit & Request Callback",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

