import 'package:blinkit_series/repository/widgets/uihelper.dart';
import 'package:blinkit_series/repository/services/api_service.dart';
import 'package:flutter/material.dart';

class PrintScreen extends StatelessWidget {
  TextEditingController searchController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Color(0XFFFBF0CE),
        body: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    height: 190,
                    width: double.infinity,
                    color: Color(0XFFF7CB45),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 30,
                        ),
                        Row(
                          children: [
                            SizedBox(
                              width: 20,
                            ),
                            UiHelper.CustomText(
                                text: "SB Mart in",
                                color: Color(0XFF000000),
                                fontweight: FontWeight.bold,
                                fontsize: 15,
                                fontfamily: "bold"),
                          ],
                        ),
                        Row(
                          children: [
                            SizedBox(
                              width: 20,
                            ),
                            UiHelper.CustomText(
                                text: "16 minutes",
                                color: Color(0XFF000000),
                                fontweight: FontWeight.bold,
                                fontsize: 20,
                                fontfamily: "bold")
                          ],
                        ),
                        Row(
                          children: [
                            SizedBox(
                              width: 20,
                            ),
                            Expanded(
                              child: UiHelper.CustomText(
                                  text: "Select Delivery Address",
                                  color: Color(0XFF000000),
                                  fontweight: FontWeight.bold,
                                  fontsize: 14),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 20,
                    top: 40,
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                  Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child:
                          UiHelper.CustomTextField(controller: searchController))
                ],
              ),
              SizedBox(
                height: 30,
              ),
              UiHelper.CustomText(
                  text: "Print Store",
                  color: Colors.black,
                  fontweight: FontWeight.bold,
                  fontsize: 32),
              UiHelper.CustomText(
                  text: "SB Mart ensures secure prints at every stage",
                  color: Color(0XFF9C9C9C),
                  fontweight: FontWeight.bold,
                  fontsize: 14),
              SizedBox(
                height: 30,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Stack(children: [
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        color: Colors.white),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 20,
                        ),
                        Row(
                          children: [
                            SizedBox(
                              width: 20,
                            ),
                            UiHelper.CustomText(
                                text: "Documents",
                                color: Colors.black,
                                fontweight: FontWeight.bold,
                                fontsize: 14)
                          ],
                        ),
                        SizedBox(
                          height: 2,
                        ),
                        Row(
                          children: [
                            SizedBox(
                              width: 20,
                            ),
                            UiHelper.CustomImage(img: "star.png"),
                            SizedBox(
                              width: 7,
                            ),
                            UiHelper.CustomText(
                                text: "Price starting at rs 3/page",
                                color: Color(0XFF9C9C9C),
                                fontweight: FontWeight.normal,
                                fontsize: 15)
                          ],
                        ),
                        Row(
                          children: [
                            SizedBox(
                              width: 20,
                            ),
                            UiHelper.CustomImage(img: "star.png"),
                            SizedBox(
                              width: 7,
                            ),
                            UiHelper.CustomText(
                                text: "Paper quality: 70 GSM",
                                color: Color(0XFF9C9C9C),
                                fontweight: FontWeight.normal,
                                fontsize: 15)
                          ],
                        ),
                        Row(
                          children: [
                            SizedBox(
                              width: 20,
                            ),
                            UiHelper.CustomImage(img: "star.png"),
                            SizedBox(
                              width: 7,
                            ),
                            UiHelper.CustomText(
                                text: "Single side prints",
                                color: Color(0XFF9C9C9C),
                                fontweight: FontWeight.normal,
                                fontsize: 15)
                          ],
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        Row(
                          children: [
                            SizedBox(
                              width: 20,
                            ),
                            SizedBox(
                              height: 40,
                              width: 125,
                              child: ElevatedButton(
                                  onPressed: () => _showCustomOrderSheet(context),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0XFF27AF34),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(5))),
                                  child: const Text(
                                    "Upload Files",
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.white),
                                  )),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                  Positioned(
                    child: UiHelper.CustomImage(img: "document.png"),
                    right: 20,
                    bottom: 40,
                  )
                ]),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
    );
  }

  void _showCustomOrderSheet(BuildContext context) {
    final TextEditingController remarksController = TextEditingController();
    final TextEditingController addressController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Submit Print / Custom Order",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Order Remarks / Document Instructions",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: remarksController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: "Enter number of copies, color/BW, single/double sided, or specific instructions...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Delivery Address",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: addressController,
                    decoration: InputDecoration(
                      hintText: "Enter your full address for print delivery...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final remarks = remarksController.text.trim();
                              final address = addressController.text.trim();
                              if (remarks.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Please enter document/print instructions.")),
                                );
                                return;
                              }

                              setState(() => isSubmitting = true);
                              final res = await ApiService.submitCustomOrderRequest(
                                orderType: "Print / Document Order",
                                remarks: remarks,
                                address: address,
                              );
                              setState(() => isSubmitting = false);

                              if (ctx.mounted) Navigator.pop(ctx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res['message'] ?? "Custom order submitted successfully!"),
                                    backgroundColor: res['status'] == 'success' ? Colors.green : Colors.black,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0XFF27AF34),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Submit Request",
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
