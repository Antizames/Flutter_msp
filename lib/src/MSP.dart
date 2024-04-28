import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'dart:typed_data';
import 'dart:convert';

class MSPCommunication {
  late SerialPort port;

  MSPCommunication(String portName) {
    port = SerialPort(portName);

    if (!port.isOpen) {
      bool opened = port.openReadWrite();
      if (!opened) {
        throw SerialPortError('Failed to open the port.');
      }
    }
  }
  Future<void> avaiblePorts() async{
    List<String> availablePort = SerialPort.availablePorts;
    print('Available Ports: $availablePort');
  }
  Future<void> sendMessageV1(int code, String data) async {
    try {
      Uint8List message = encodeMessageV1(code, data);
      port.write(message);
      await Future.delayed(Duration(seconds: 1));  // simulate some delay
      List<int> response = port.read(64);

      if (response.isNotEmpty) {
        print('Response Data: ${String.fromCharCodes(response)}');
      } else {
        print('No response received from the device.');
      }
    } finally {
      port.close();
    }
  }
  Future<void> sendMessageV2(int code, Uint8List data) async {
    try {
      Uint8List message = encodeMessageV2(code, data);
      port.write(message);
      await Future.delayed(Duration(seconds: 1));  // simulate some delay
      List<int> response = port.read(64);

      if (response.isNotEmpty) {
        print('Response Data: ${String.fromCharCodes(response)}');
      } else {
        print('No response received from the device.');
      }
    } finally {
      port.close();
    }
  }

  Uint8List encodeMessageV1(int code, dynamic data) {
    Uint8List dataBytes;
    if (data is String) {
      dataBytes = Uint8List.fromList(data.codeUnits);
    } else if (data is int) {
      dataBytes = Uint8List(4);
      dataBytes.buffer.asByteData().setInt32(0, data, Endian.little);
    } else {
      throw ArgumentError('Unsupported data type');
    }

    int dataLength = dataBytes.length;
    final bufferSize = dataLength + 6;  // Add length for start byte, message type, length, code, and checksum
    final buffer = Uint8List(bufferSize);

    buffer[0] = 36; // Start byte '$'
    buffer[1] = 77; // Message type 'M'
    buffer[2] = 60; // '<'
    buffer[3] = dataLength;
    buffer[4] = code;

    var checksum = buffer[3] ^ buffer[4];
    buffer.setRange(5, 5 + dataLength, dataBytes);
    for (int i = 5; i < 5 + dataLength; i++) {
      checksum ^= buffer[i];
    }

    buffer[bufferSize - 1] = checksum;  // Set the checksum at the end of the buffer.

    return buffer;
  }
  Uint8List encodeMessageV2(int code, dynamic data) {
    Uint8List dataBytes;
    if (data is String) {
      dataBytes = stringToBytes(data);
    } else if (data is List<int>) {
      dataBytes = intListToBytes(data);
    } else {
      throw ArgumentError("Unsupported data type");
    }

    int dataLength = dataBytes.length;
    int bufferSize = dataLength + 9;
    Uint8List bufferOut = Uint8List(bufferSize);
    bufferOut[0] = 36;  // Start byte '$'
    bufferOut[1] = 88;  // Message type 'M'
    bufferOut[2] = 60;  // '<'
    bufferOut[3] = 0;   // Flag byte initialized to 0
    bufferOut[4] = code & 0xFF;
    bufferOut[5] = (code >> 8) & 0xFF;
    bufferOut[6] = dataLength & 0xFF;
    bufferOut[7] = (dataLength >> 8) & 0xFF;
    bufferOut.setRange(8, 8 + dataLength, dataBytes);
    // Calculate CRC and add at the end
    bufferOut[bufferSize - 1] = crc8DvbS2(bufferOut.sublist(3, bufferSize - 1));
    return bufferOut;
  }
// Функция для конвертации строки в байты
  Uint8List stringToBytes(String str) {
    return Uint8List.fromList(utf8.encode(str));
  }

// Функция для конвертации списка чисел int в байты
  Uint8List intListToBytes(List<int> list) {
    return Uint8List.fromList(list);
  }
  int crc8DvbS2(List<int> input) {
    int crc = 0xFF;
    for (int data in input) {
      crc = crc8DvbS2Byte(crc, data);
    }
    return crc;
  }

  int crc8DvbS2Byte(int crc, int data) {
    crc ^= data;
    for (int i = 0; i < 8; i++) {
      if (crc & 0x80 != 0) {
        crc = (crc << 1) ^ 0xD5;
      } else {
        crc <<= 1;
      }
    }
    return crc & 0xFF;
  }
}