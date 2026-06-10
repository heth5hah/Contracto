void main() {
  final desc = "Return refund - Order #95FC753A";
  final match = RegExp(r'(?i)Order #([A-F0-9]{8})').firstMatch(desc);
  print(match?.group(1));
}
