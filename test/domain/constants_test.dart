import 'package:flutter_test/flutter_test.dart';
import 'package:merge_count/domain/constants.dart';

void main() {
  test('board geometry is 5x5 = 25 cells', () {
    expect(kGridSize, 5);
    expect(kCellCount, 25);
  });

  test('dropCap starts at 2 and steps up, clamped to 6', () {
    expect(dropCap(0), 2);
    expect(dropCap(5), 2);
    expect(dropCap(6), 3);
    expect(dropCap(30), 7 > 6 ? 6 : 7); // clamped
    expect(dropCap(1000), 6);
  });
}
