[[include repo=source path=Wiki/MarkDown/Header.md]]

[TOC]

# Introduction

The FUI Audio DAC is an open-hardware and -firmware project that implements a USB-input fully-digital class-D audio amplifier.  A Microchip PIC-based remote control is also included.

In overview, the generic Windows USB~audio driver is used to stream 48~kSps~stereo audio to the amplifier.  The generic Windows~HID driver is used to interface a volume control knob and various buttons to the computer.  These buttons are implemented on a remote control, which is implemented by means of an [off-the-shelf 433~MHz ASK module](http://www.communica.co.za/Catalog/Details/P1929638763).  Intended functions include *volume up*, *volume down*, *play/pause*, *next track*, *previous track* and *stop* controls.

Volume control is implemented as a combination of bus voltage control and audio stream gain control.

The block diagram below provides a system overview.

<center markdown>![System Block Diagram](https://sourceforge.net/p/fui-audio-dac/source/ci/master/tree/InkScape/Block%20Diagrams/USB_Amp_Block.svg?format=raw)</center>

# Firmware

All processing is done on FPGA, including the USB-physical, USB-SIE, HID interface, clock-recovery, bus voltage regulation, noise-shaping and PWM output.  An overview of the firmware is provided in the block diagram below.

<center markdown>![Firmware Block Diagram](https://sourceforge.net/p/fui-audio-dac/source/ci/master/tree/InkScape/Block%20Diagrams/USB_Amp_FPGA_Block.svg?format=raw)</center>

The FPGA used for this project is a [BeMicro Max 10](https://www.arrow.com/en/products/bemicromax10/arrow-development-tools).

# USB Vendor ID and Product ID

At present, the project uses the Test ID (1209 | 0001) provided by [PID Codes](http://pid.codes/1209/0001).  It is not unique and may therefore not be used outside test environments.

[[include repo=source path=Wiki/MarkDown/Footer.md]]

