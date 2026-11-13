# Field kit checklist

## Essential — laptop and networking

- [ ] Laptop and charger
- [ ] This prepared flash drive
- [ ] One known-good Cat5e/Cat6 Ethernet cable plus a spare if available
- [ ] USB-to-Ethernet adapter if the laptop has no Ethernet port
- [ ] Phone with WiFi for captive-portal testing
- [ ] Upstream internet router credentials or access, if needed

## Essential — power and controller

- [ ] Correct Q20 12 V / 1 A center-positive adapter
- [ ] Stable regulated 5 V / 1 A or greater USB charger for the ESP32
- [ ] Known-good ESP32 USB data cable plus a spare; many charge-only cables do not expose serial
- [ ] Correct 12 V supply for the coin acceptor
- [ ] Installed inline fuses and spare 1 A/3 A fuses matching the existing branch design
- [ ] Safe insulated enclosure/cover, strain relief, and terminals for any open-frame mains supply
- [ ] Power strip/extension appropriate for Philippine 220 V service

Never energize an exposed mains terminal. The USB cable never carries the coin acceptor's 12 V supply.

## Essential — technician tools and tests

- [ ] Multimeter with sound probes/leads
- [ ] Insulated Phillips and flat screwdrivers
- [ ] Wire cutter/stripper and crimper appropriate for the terminals
- [ ] Electrical tape and preferably heat-shrink tubing/ferrules
- [ ] Jumper leads or insulated test clips
- [ ] Labels/marker and cable ties
- [ ] Real ₱1, ₱5, ₱10, and ₱20 coins

Test at least coin stacking, the 30-second window, customer authorization, pause/resume, expiry, and the phone beep before leaving.

## Helpful recovery equipment

- [ ] 3.3 V logic USB-to-TTL serial adapter (CP2102/CH340 type)
- [ ] Small network cable tester
- [ ] Spare ESP32
- [ ] Soldering iron, solder, flux, and hot air only if board repair is genuinely required
- [ ] CH341 programmer and SOIC clip only for a separately planned flash-chip recovery

The CH341 is not needed for Firebase, normal Q20 configuration, or normal ESP32 USB flashing. Do not clip it to a powered board, and do not use 5 V logic on 3.3 V flash or UART circuitry.
