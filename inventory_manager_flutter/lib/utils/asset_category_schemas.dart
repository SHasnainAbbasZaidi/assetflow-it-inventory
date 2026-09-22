class AssetCategorySchemas {
  static const List<String> categories = [
    'PC/Laptop',
    'Laptop',
    'Desktop',
    'Monitor',
    'Display',
    'Printer',
    'Scanner',
    'Projector',
    'Server',
    'Network Device',
    'Mobile',
    'Tablet',
    'Keyboard',
    'Mouse',
    'Headphones',
    'Storage',
    'Software',
    'Peripheral',
    'Other',
  ];

  static const List<String> deviceTypes = [
    'Dell',
    'HP',
    'Lenovo',
    'Apple',
    'Asus',
    'Acer',
    'LG',
    'Samsung',
    'Sony',
    'Epson',
    'Canon',
    'Brother',
    'Cisco',
    'Ubiquiti',
    'Microsoft',
    'Logitech',
    'A4Tech',
    'Lexar',
    'Corsair',
    'XPG',
    'Aigo',
    'Other',
  ];

  static List<String> getBrandsForCategory(String category) {
    switch (category) {
      case 'PC/Laptop':
      case 'Laptop':
      case 'Desktop':
        return ['Dell', 'HP', 'Lenovo', 'Apple', 'Asus', 'Acer', 'Microsoft', 'MSI', 'Other'];
      case 'Mobile':
      case 'Tablet':
        return ['Apple', 'Samsung', 'Google', 'OnePlus', 'Motorola', 'Xiaomi', 'Sony', 'Other'];
      case 'Monitor':
      case 'Display':
        return ['Dell', 'HP', 'LG', 'Samsung', 'Asus', 'Acer', 'BenQ', 'AOC', 'Sony', 'Other'];
      case 'Printer':
      case 'Scanner':
        return ['HP', 'Epson', 'Canon', 'Brother', 'Lexmark', 'Xerox', 'Other'];
      case 'Server':
      case 'Network Device':
        return ['Dell', 'HP', 'Cisco', 'Ubiquiti', 'Netgear', 'TP-Link', 'Juniper', 'MikroTik', 'Other'];
      case 'Keyboard':
      case 'Mouse':
      case 'Headphones':
      case 'Peripheral':
        return ['Logitech', 'Microsoft', 'Corsair', 'Razer', 'Keychron', 'SteelSeries', 'HyperX', 'Sony', 'Other'];
      case 'Storage':
        return ['Samsung', 'Western Digital', 'Seagate', 'Crucial', 'Kingston', 'SanDisk', 'Lexar', 'Other'];
      case 'Software':
        return ['Microsoft', 'Adobe', 'Autodesk', 'JetBrains', 'Atlassian', 'Other'];
      default:
        return deviceTypes;
    }
  }

  static const Map<String, List<Map<String, String>>> schemas = {
    'PC/Laptop': [
      {
        'id': 'cpu',
        'label': 'Processor (CPU)',
        'placeholder': 'e.g. Intel Core i7'
      },
      {'id': 'ram', 'label': 'RAM (GB)', 'placeholder': 'e.g. 16'},
      {'id': 'storage', 'label': 'Storage', 'placeholder': 'e.g. 512GB SSD'},
      {
        'id': 'os',
        'label': 'Operating System',
        'placeholder': 'e.g. Windows 11 Pro'
      },
      {'id': 'mac', 'label': 'MAC Address', 'placeholder': '00:1A:2B:3C:4D:5E'},
    ],
    'Display': [
      {
        'id': 'resolution',
        'label': 'Resolution',
        'placeholder': 'e.g. 3840x2160'
      },
      {'id': 'size', 'label': 'Screen Size (Inches)', 'placeholder': 'e.g. 27'},
      {
        'id': 'refresh',
        'label': 'Refresh Rate (Hz)',
        'placeholder': 'e.g. 144'
      },
    ],
    'VR': [
      {
        'id': 'headset',
        'label': 'Headset Model',
        'placeholder': 'e.g. Meta Quest 3'
      },
      {
        'id': 'controllers',
        'label': 'Controllers Included?',
        'placeholder': 'Yes/No'
      },
    ],
    'Mobile': [
      {'id': 'os', 'label': 'Mobile OS', 'placeholder': 'e.g. iOS 17'},
      {'id': 'storage', 'label': 'Storage (GB)', 'placeholder': 'e.g. 256'},
      {'id': 'imei', 'label': 'IMEI Number', 'placeholder': 'Enter IMEI'},
    ],
    'Keyboard': [
      {
        'id': 'connection',
        'label': 'Connection Type',
        'placeholder': 'Wireless / Wired'
      },
      {'id': 'layout', 'label': 'Layout', 'placeholder': 'e.g. QWERTY US'},
    ],
    'Mouse': [
      {
        'id': 'connection',
        'label': 'Connection Type',
        'placeholder': 'Wireless / Wired'
      },
      {'id': 'dpi', 'label': 'DPI', 'placeholder': 'e.g. 4000'},
    ],
    'Headphones': [
      {
        'id': 'connection',
        'label': 'Connection Type',
        'placeholder': 'Wireless / Wired'
      },
      {'id': 'mic', 'label': 'Has Microphone?', 'placeholder': 'Yes / No'},
    ],
    'Storage': [
      {
        'id': 'type',
        'label': 'Storage Type',
        'placeholder': 'USB Drive / SSD / Memory Card'
      },
      {'id': 'capacity', 'label': 'Capacity', 'placeholder': 'e.g. 128GB'},
      {
        'id': 'interface',
        'label': 'Interface',
        'placeholder': 'USB 3.2 / NVMe / SD'
      },
      {'id': 'model', 'label': 'Model', 'placeholder': 'Model name'},
    ],
    'Software': [
      {
        'id': 'licenseKey',
        'label': 'License Key',
        'placeholder': 'XXXX-XXXX-XXXX-XXXX'
      },
      {'id': 'expiry', 'label': 'Expiry Date', 'placeholder': 'YYYY-MM-DD'},
    ],
    'Other': [
      {
        'id': 'notes',
        'label': 'Additional Notes',
        'placeholder': 'Any extra info...'
      },
    ],
  };
}
