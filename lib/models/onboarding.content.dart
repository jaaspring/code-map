class OnboardingContents {
  final String title;
  final String image;
  final String desc;

  OnboardingContents({
    required this.title,
    required this.image,
    required this.desc,
  });
}

List<OnboardingContents> contents = [
  OnboardingContents(
    title: "Prepare Yourself",
    image: "assets/images/robot_1.png",
    desc:
        "Ensure you're in a relaxed setting conducive to concentration for the assessment.",
  ),
  OnboardingContents(
    title: "Complete The Test",
    image: "assets/images/robot_2.png",
    desc:
        "Complete three parts of the assessment to discover the IT career path that best matches your skills and background.",
  ),
  OnboardingContents(
    title: "Discover Your IT Career Path",
    image: "assets/images/robot_3.png",
    desc:
        "View your personalized report to explore your IT strengths and discover where you fit best.",
  ),
];
