import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
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

  @override
  void initState() {
    super.initState();
    _savedMac = PrinterService.savedMac;
    _savedName = PrinterService.savedName;
    _scan();
  }

  Future<void> _scan() async {
    // Request Bluetooth permissions on Android 12+
    final status = await Permission.bluetoothConnect.request();
    if (status.isDenied) {
      Get.snackbar(
        'Permission Denied',
        'Bluetooth permission is required to find printers',
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

  void _selectPrinter(BluetoothInfo device) {
    PrinterService.savePrinter(device.macAdress, device.name);
    setState(() {
      _savedMac = device.macAdress;
      _savedName = device.name;
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
              child: Row(
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
                      });
                    },
                    child: const Text(
                      'Remove',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],

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
