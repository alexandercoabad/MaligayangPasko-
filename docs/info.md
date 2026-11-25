<!---
This file is used to generate your project datasheet.
-->

## How it works

A 640x480 @ 60 Hz VGA picture (25.175 MHz pixel clock, 2 bits per colour channel, TinyVGA Pmod
pinout) drawn with combinational logic from the pixel counters, no frame buffer. The design is
for the **micro tile** (`tiles: "micro"`: clk, rst_n, 8 inputs, 8 outputs, about 300 gates or 80
flip-flops); it is 38 flip-flops and about 230 gates.

The picture is a 40 x 30 grid of 16-pixel cells:

- **Tree**: three tiers of a fir tree (half-widths from a 16-row table, darker green on the
  edge cells), a brown trunk and a star on top that blinks yellow / white.
- **Lights**: every fourth cell inside the tree is a light whose colour cycles
  (red, yellow, white, cyan) with the frame count.
- **Snow**: small flakes fall in the night sky (each flake column has its own phase) and the
  ground is snow, with **PASKO** in red (3x5 cells a letter).
- Nothing is stored: the picture comes from the counters, a row table, a glyph table and a few
  XORs.

`ui_in[0]` (PAUSE) freezes the frame counter, and with it the snow, the lights and the star.
The outputs are registered, so the picture is one clock late relative to the sync pulses.

The earlier 1x1 version of this project (full scene, `MERRY CHRISTMAS!` and `MALIGAYANG PASKO!` in an
8x8 font, 523 lines of Verilog) does not fit a micro tile; this version keeps the tree, the lights,
the star, the snow and a short greeting.

## How to test

Connect a TinyVGA PMOD and a VGA monitor, apply a 25.175 MHz clock and release reset.
A snowy night with a Christmas tree and the word PASKO should appear.

## External hardware

TinyVGA PMOD (https://github.com/mole99/tiny-vga) and a VGA monitor.
