import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../customer/customer_model.dart';
import '../services/review_service.dart';

class WriteReviewScreen extends StatefulWidget {
  final String productId;
  final String productTitle;

  const WriteReviewScreen({
    super.key,
    required this.productId,
    required this.productTitle,
  });

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  int rating = 5;
  final TextEditingController controller = TextEditingController();
  bool submitting = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (submitting) return;

    final text = controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please write your review")),
      );
      return;
    }

    final customer = context.read<CustomerModel>().customer;
    final email = (customer?["email"] ?? "").toString().trim();
    final name = (customer?["firstName"] ?? customer?["name"] ?? "Customer").toString().trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login to submit a review")),
      );
      return;
    }

    setState(() => submitting = true);

    try {
      await ReviewService.submitReview(
        productId: widget.productId,
        rating: rating,
        body: text,
        reviewerName: name.isEmpty ? "Customer" : name,
        reviewerEmail: email,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Review submitted")),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (!mounted) return;
      setState(() => submitting = false);
    }
  }

  Widget star(int value) {
    final selected = rating >= value;
    return IconButton(
      onPressed: submitting ? null : () => setState(() => rating = value),
      icon: Icon(
        selected ? Icons.star : Icons.star_border,
        color: const Color(0xFFEA0180),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Write a Review"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.productTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text("Rating"),
            Row(
              children: [star(1), star(2), star(3), star(4), star(5)],
            ),
            const SizedBox(height: 8),
            const Text("Review"),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              enabled: !submitting,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "Share your experience...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA0180),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: submitting ? null : submit,
                child: Text(submitting ? "Submitting..." : "Submit Review"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

