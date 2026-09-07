import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../core/services/printer_service.dart';

class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  List<BluetoothInfo> _devices = [];
  bool _scanning = false;
  String? _savedMac;
  String? _savedName;
  PrinterProfile _savedProfile = PrinterProfile.gsV0;

  @override
  void initState() {
    super.initState();
    _savedMac = PrinterService.savedMac;
    _savedName = PrinterService.savedName;
    _savedProfile = PrinterService.savedProfile;
    _scan();
  }

  Future<void> _scan() async {
    final hasPermission = await PrinterService.ensureBluetoothPermissions();
    if (!hasPermission) {
      Get.snackbar(
        'Permission Denied',
        'Nearby devices permission is required to find printers',
      );
      return;
    }

    setState(() => _scanning = true);
    try {
      final devices = await PrinterService.getPairedDevices();
      setState(() => _devices = devices);
    } catch (e) {
      Get.snackbar('Error', 'Failed to scan for devices: $e');
    } finally {
      setState(() => _scanning = false);
    }
  }

  void _setProfile(PrinterProfile profile) {
    PrinterService.setProfile(profile);
    setState(() => _savedProfile = profile);
  }

  void _selectPrinter(BluetoothInfo device) {
    PrinterService.savePrinter(device.macAdress, device.name);
    setState(() {
      _savedMac = device.macAdress;
      _savedName = device.name;
      _savedProfile = PrinterService.savedProfile;
    });
    Get.snackbar(
      'Printer Saved',
      '${device.name} is now set as the receipt printer',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Printer Settings',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Get.back(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current printer
          if (_savedMac != null) ...[
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF2563EB).withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.print, color: Color(0xFF2563EB)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Active Printer',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            Text(
                              _savedName ?? _savedMac!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _savedMac!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          PrinterService.clearPrinter();
                          setState(() {
                            _savedMac = null;
                            _savedName = null;
                            _savedProfile = PrinterProfile.gsV0;
                          });
                        },
                        child: const Text(
                          'Remove',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Printer profile selector — always available, even before a
          // printer is paired/selected, so a teller can preset the profile
          // for a printer that isn't reachable yet.
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Printer Profile',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pick the mode matching your printer model. Wrong mode causes garbled or blank logo prints.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ProfileButton(
                      label: 'GS v 0',
                      sublabel: 'Standard',
                      selected: _savedProfile == PrinterProfile.gsV0,
                      onTap: () => _setProfile(PrinterProfile.gsV0),
                    ),
                    _ProfileButton(
                      label: 'ESC *',
                      sublabel: 'Goojprt / MTP-2 / PT-210',
                      selected: _savedProfile == PrinterProfile.escStar,
                      onTap: () => _setProfile(PrinterProfile.escStar),
                    ),
                    _ProfileButton(
                      label: 'MP58-04H',
                      sublabel: 'Extra feed before cut',
                      selected: _savedProfile == PrinterProfile.mp58,
                      onTap: () => _setProfile(PrinterProfile.mp58),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Paired Bluetooth Devices',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                TextButton.icon(
                  onPressed: _scanning ? null : _scan,
                  icon: _scanning
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 16),
                  label: Text(_scanning ? 'Scanning...' : 'Refresh'),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Device list
          Expanded(
            child: _scanning
                ? const Center(child: CircularProgressIndicator())
                : _devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bluetooth_disabled,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No paired devices found.\nPair your Bluetooth printer in device settings first.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _devices.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 16),
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      final isSelected = device.macAdress == _savedMac;
                      return ListTile(
                        leading: Icon(
                          Icons.print_outlined,
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : Colors.grey,
                        ),
                        title: Text(
                          device.name,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(device.macAdress),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle,
                                color: Color(0xFF2563EB),
                              )
                            : const Icon(
                                Icons.radio_button_unchecked,
                                color: Colors.grey,
                              ),
                        onTap: () => _selectPrinter(device),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;

  const _ProfileButton({
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF2563EB) : const Color(0xFFD1D5DB),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: 10,
                color: selected ? Colors.white70 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
