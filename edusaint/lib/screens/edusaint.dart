import 'package:flutter/material.dart';
import 'mainscaffold.dart';

class EdusaintView extends StatelessWidget {
  const EdusaintView({super.key});

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      selectedIndex: 2,

      // ✅ FIX: use body instead of bodyBuilder
      body: const _EdusaintBody(),
    );
  }
}

class _EdusaintBody extends StatelessWidget {
  const _EdusaintBody();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0A0A0F).withOpacity(0.92),
            const Color(0xFF1A2339).withOpacity(0.85),
            const Color(0xFFB7C6FF).withOpacity(0.65),
          ],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: width * 0.06,
            vertical: height * 0.02,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // TITLE
              Text(
                "Welcome to EduSaint",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: width * 0.075,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: height * 0.02),

              // DESCRIPTION
              Text(
                "Our app helps students from Classes 1–10 master subjects with short lessons, daily practice, and interactive activities.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: width * 0.043,
                  height: 1.4,
                ),
              ),

              SizedBox(height: height * 0.04),

              // OFFER TITLE
              Text(
                "What We Offer",
                style: TextStyle(
                  fontSize: width * 0.065,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              SizedBox(height: height * 0.02),

              // OFFER CARDS
              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: const [
                    _OfferCard("Bite Sized\nLessons"),
                    SizedBox(width: 12),
                    _OfferCard("Practice that\nBuilds Skill"),
                    SizedBox(width: 12),
                    _OfferCard("Daily\nProgress Tracking"),
                  ],
                ),
              ),

              SizedBox(height: height * 0.04),

              // PREMIUM TITLE
              Text(
                "Unlock Full Learning Experience",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: width * 0.065,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              SizedBox(height: height * 0.02),

              Text(
                "Premium learners complete more chapters and build stronger concepts with unlimited access.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: width * 0.043,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),

              SizedBox(height: height * 0.04),

              // PLANS
              Row(
                children: [
                  Expanded(
                    child: _PlanCard(
                      title: "Yearly",
                      trial: "14-day free trial",
                      price: "₹999/year",
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _PlanCard(
                      title: "Monthly",
                      trial: "7-day free trial",
                      price: "₹199/month",
                    ),
                  ),
                ],
              ),

              SizedBox(height: height * 0.03),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- OFFER CARD ----------------
class _OfferCard extends StatelessWidget {
  final String text;

  const _OfferCard(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF1F2234),
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------- PLAN CARD ----------------
class _PlanCard extends StatelessWidget {
  final String title;
  final String trial;
  final String price;

  const _PlanCard({
    required this.title,
    required this.trial,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9FB4FF), Color(0xFF728BFF)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(trial, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 6),
          Text(
            price,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () {}, child: const Text("Choose Plan")),
        ],
      ),
    );
  }
}
