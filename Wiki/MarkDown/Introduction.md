[[include repo=source path=Wiki/MarkDown/Header.md]]

[TOC]

# 1. Overview

The FUI Audio DAC is an open-hardware and -firmware project that implements a USB-input fully-digital class-D audio amplifier.  A Microchip PIC-based remote control is also included.

The generic Windows USB&nbsp;audio driver is used to stream 48&nbsp;kSps&nbsp;stereo audio to the amplifier.  The generic Windows&nbsp;HID driver is used to interface a volume control knob and various buttons to the computer.  These buttons are implemented on a remote control, which is implemented by means of an [off-the-shelf 433&nbsp;MHz ASK module](http://www.communica.co.za/Catalog/Details/P1929638763).  Intended functions include *volume up*, *volume down*, *play/pause*, *next track*, *previous track* and *stop* controls.

Volume control is implemented as a combination of bus voltage control and audio stream gain control.

The block diagram below provides a system overview.  The FPGA used for this project is an [Altera Max 10](https://www.altera.com/products/fpga/max-series/max-10/overview.html), which is on a [BeMicro Max 10](https://www.arrow.com/en/products/bemicromax10/arrow-development-tools) development kit.  The microprocessor used for the remote control is a [Microchip PIC16F676](http://www.microchip.com/wwwproducts/en/PIC16F676).

<center markdown>![System Block Diagram](https://sourceforge.net/p/fui-audio-dac/source/ci/master/tree/InkScape/Block%20Diagrams/USB_Amp_Block.svg?format=raw)</center>

# 2. Firmware

All processing is done on FPGA, including the USB-physical, USB-SIE, HID interface, clock-recovery, bus voltage regulation, noise-shaping and PWM output.  An overview of the firmware is provided in the block diagram below.

<center markdown>![Firmware Block Diagram](https://sourceforge.net/p/fui-audio-dac/source/ci/master/tree/InkScape/Block%20Diagrams/USB_Amp_FPGA_Block.svg?format=raw)</center>

# 3. USB Vendor ID and Product ID

At present, the project uses the Test ID provided by [PID Codes](http://pid.codes/1209/0001).  It is not unique and may therefore not be used outside test environments.

# 4. Development Software

The project is developed using:

- [TinyCAD](https://sourceforge.net/projects/tinycad/)
- [FreePCB](http://freepcb.com/) (or you can use [the fork](https://bitbucket.org/mplough/freepcb/wiki/Home))
- [MPLAB-X](http://www.microchip.com/mplab/mplab-x-ide), which comes with a free version of the [XC&nbsp;compiler](http://www.microchip.com/mplab/compilers)
- [Quartus Prime Lite](https://www.altera.com/products/design-software/fpga-design/quartus-prime/overview.html)

[[include repo=source path=Wiki/MarkDown/Footer.md]]

