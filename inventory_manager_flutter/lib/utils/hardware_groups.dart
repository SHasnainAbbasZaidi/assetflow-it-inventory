class HardwareGroups {
  static const names = ['Workstations', 'Peripherals', 'Devices', 'Components'];
  static const descriptions = {
    'Workstations': 'Assembled PCs, motherboards, laptops, mini PCs and all-in-one PCs',
    'Peripherals': 'Keyboards, mice, headphones, displays and accessories',
    'Devices': 'Printers, networking equipment, VR devices and webcams',
    'Components': 'RAM, SSDs, HDDs, GPUs and internal parts',
  };
  static String classify(String category, {bool workstation = false}) {
    if (workstation) return 'Workstations';
    final c = category.toLowerCase().replaceAll(RegExp(r'[-_/]'), ' ');
    if (RegExp(r'\b(motherboard|mainboard|laptop|desktop|computer|workstation|pc|aio)\b|all in one').hasMatch(c)) return 'Workstations';
    if (RegExp(r'\b(ram|ssd|hdd|gpu|cpu|processor|memory|storage|graphics|psu|power supply|cooler|internal|component)\b').hasMatch(c)) return 'Components';
    if (RegExp(r'\b(printer|scanner|network|networking|router|switch|firewall|access point|modem|vr|webcam|camera|projector|server|nas|tablet|mobile)\b').hasMatch(c)) return 'Devices';
    return 'Peripherals';
  }
}
