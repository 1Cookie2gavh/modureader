enum AppLayoutMode {
  auto,
  wide,
  narrow;

  bool usesWideLayout(double width) => switch (this) {
        auto => width > 600,
        wide => true,
        narrow => false,
      };
}
