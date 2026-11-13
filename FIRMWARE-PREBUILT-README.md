# Firmware build notes

Firebase monitoring alone does not require flashing the ESP32. The complete AZ Tires rename changes the hidden controller SSID to `AZ-Tires-Controller`, so that one coordinated rename requires matching ESP32 firmware and Q20 configuration.

## ESP32 AZ Tires coin controller

Production controller binaries are deliberately omitted from the portable package because firmware compiled from `secrets.h` can contain controller WiFi and API credentials. The complete controller source and `secrets.example.h` are included. Build a new image only after entering the site-specific secrets locally.

Do not flash merely because the USB serial port is absent. First verify the USB data cable, port, CP210x driver, stable power, and bootloader entry procedure. Back up the current flash before the coordinated SSID rename.

## ESP32 power diagnostic

`firmware-prebuilt/esp32-power-diagnostic` is a non-network troubleshooting build. It replaces the Piso WiFi controller firmware and therefore must not be installed on a production unit unless the technician deliberately needs that diagnostic and has a current backup.

## ESP8266 temporary controller

The ESP8266 production binary is also omitted because it can embed site credentials. The compatible source remains included. The current production wiring and firmware target are ESP32 GPIO27.
