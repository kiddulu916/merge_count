enum Difficulty {
  easy(gridSize: 8, startingFill: 40, label: 'Easy'),
  medium(gridSize: 7, startingFill: 25, label: 'Medium'),
  hard(gridSize: 6, startingFill: 20, label: 'Hard'),
  legendary(gridSize: 6, startingFill: 15, label: 'Legendary');

  const Difficulty({
    required this.gridSize,
    required this.startingFill,
    required this.label,
  });

  final int gridSize;
  final int startingFill;
  final String label;

  int get cellCount => gridSize * gridSize;
}
