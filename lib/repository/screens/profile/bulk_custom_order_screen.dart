import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blinkit_series/repository/services/api_service.dart';
import 'package:blinkit_series/repository/widgets/address_selection_bottom_sheet.dart';

class BulkCustomOrderScreen extends StatefulWidget {
  final VoidCallback? onBackTap;

  const BulkCustomOrderScreen({super.key, this.onBackTap});

  @override
  State<BulkCustomOrderScreen> createState() => _BulkCustomOrderScreenState();
}

class _BulkCustomOrderScreenState extends State<BulkCustomOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedOrderType = 'Bulk Quantity Order';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  File? _selectedImage;
  String? _base64Image;
  bool _isSubmitting = false;
  String _nearestStoreName = 'SB Mart Main Store';

  final List<Map<String, dynamic>> _orderTypes = [
    {
      'title': 'Bulk Quantity Order',
      'icon': Icons.inventory_2_outlined,
      'subtitle': 'Order items in large quantities for events, shops, or businesses',
    },
    {
      'title': 'Custom Item Request',
      'icon': Icons.shopping_bag_outlined,
      'subtitle': 'Request items not listed in our catalog',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadNearestStore();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('user_phone') ?? '';
    final name = prefs.getString('user_name') ?? '';
    final address = prefs.getString('user_selected_address') ?? '';

    if (mounted) {
      setState(() {
        _phoneController.text = phone;
        _nameController.text = name;
        _addressController.text = address;
      });
    }
  }

  Future<void> _loadNearestStore() async {
    try {
      final store = await ApiService.fetchSelectedStore();
      if (mounted && store != null && store['name'] != null) {
        setState(() {
          _nearestStoreName = store['name'].toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (picked != null) {
        final bytes = await File(picked.path).readAsBytes();
        setState(() {
          _selectedImage = File(picked.path);
          _base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not attach image: $e')),
        );
      }
    }
  }

  void _openAddressPicker() {
    AddressSelectionBottomSheet.show(
      context,
      onAddressSelected: (newAddr) async {
        if (mounted && newAddr.isNotEmpty) {
          setState(() {
            _addressController.text = newAddr;
          });
          await ApiService.saveUserSelectedAddress(newAddr);
          _loadNearestStore();
        }
      },
    );
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_remarksController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter details or list of items needed.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await ApiService.submitCustomOrderRequest(
        orderType: _selectedOrderType,
        remarks: _remarksController.text.trim(),
        address: _addressController.text.trim(),
        base64Image: _base64Image,
      );

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      if (result['status'] == 'success') {
        _showSuccessDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to submit order request.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission error: $e')),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0XFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0XFF0C831F), size: 56),
            ),
            const SizedBox(height: 16),
            const Text(
              "Request Submitted!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 8),
            Text(
              "We have received your custom/bulk order request. Our manager from $_nearestStoreName will call you shortly to confirm pricing & delivery details.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0XFF666666)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0XFF0C831F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text("Done", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
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
          onPressed: () {
            if (widget.onBackTap != null) {
              widget.onBackTap!();
            } else if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          "Bulk & Custom Orders",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Banner Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0XFFFFF8E1), Color(0XFFFFECB3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0XFFFFD54F), width: 0.8),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.inventory_2_rounded, color: Color(0XFFF57C00), size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Submit Bulk & Custom Orders",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "Order non-listed items or bulk quantities with fast door delivery.",
                            style: TextStyle(fontSize: 11.5, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 1. Order Type Selection Section
              const Text(
                "Select Order Type",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 10),

              Column(
                children: _orderTypes.map((type) {
                  final isSelected = _selectedOrderType == type['title'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedOrderType = type['title'];
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0XFFF0F9F1) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0XFF0C831F) : const Color(0XFFE0E0E0),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            type['icon'] as IconData,
                            color: isSelected ? const Color(0XFF0C831F) : Colors.black54,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  type['title'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? const Color(0XFF0C831F) : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  type['subtitle'],
                                  style: const TextStyle(fontSize: 11, color: Color(0XFF757575)),
                                ),
                              ],
                            ),
                          ),
                          Radio<String>(
                            value: type['title'],
                            groupValue: _selectedOrderType,
                            activeColor: const Color(0XFF0C831F),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedOrderType = val;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // 2. Order Details / Items Required Field
              const Text(
                "Item Details / Order Requirements",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _remarksController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "E.g. Need 50kg Basmati Rice bags, 10 packets of Fortune Sunflower Oil (1L)...",
                  hintStyle: const TextStyle(fontSize: 12.5, color: Color(0XFF9E9E9E)),
                  fillColor: Colors.white,
                  filled: true,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0XFFE0E0E0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0XFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0XFF0C831F), width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter item details or requirements.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // 3. Attach Reference Image (Optional)
              const Text(
                "Attach Reference Photo (Optional)",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 8),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0XFFE0E0E0)),
                ),
                child: _selectedImage != null
                    ? Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _selectedImage!,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              "Image Attached",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _selectedImage = null;
                                _base64Image = null;
                              });
                            },
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickImage(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt_outlined, size: 18, color: Color(0XFF0C831F)),
                              label: const Text("Take Photo", style: TextStyle(fontSize: 12, color: Color(0XFF0C831F))),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0XFF0C831F)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_outlined, size: 18, color: Color(0XFF0C831F)),
                              label: const Text("Choose Gallery", style: TextStyle(fontSize: 12, color: Color(0XFF0C831F))),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0XFF0C831F)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 16),

              // 4. Delivery Address Section with Choose Address option & Store indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Delivery Address",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  TextButton.icon(
                    onPressed: _openAddressPicker,
                    icon: const Icon(Icons.location_on_outlined, size: 16, color: Color(0XFF0C831F)),
                    label: const Text(
                      "Choose Address",
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0XFF0C831F)),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: "Enter full delivery address...",
                  hintStyle: const TextStyle(fontSize: 12.5, color: Color(0XFF9E9E9E)),
                  fillColor: Colors.white,
                  filled: true,
                  contentPadding: const EdgeInsets.all(12),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.edit_location_alt_outlined, color: Color(0XFF0C831F)),
                    onPressed: _openAddressPicker,
                    tooltip: "Choose Address",
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0XFFE0E0E0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0XFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0XFF0C831F), width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter delivery address.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 10),

              // Store Assignment Badge ("Delivery will be done by XXXX store")
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0XFFF0F4FE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0XFFC5D3F8)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storefront_rounded, color: Color(0XFF1565C0), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Delivery will be done by $_nearestStoreName store",
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0XFF1565C0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0XFF0C831F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  onPressed: _isSubmitting ? null : _submitOrder,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          "Submit Custom Order Request",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
