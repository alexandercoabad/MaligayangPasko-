/*
 * Copyright (c) 2026 Alexander Co Abad
 * SPDX-License-Identifier: Apache-2.0
 *
 * Maligayang Pasko - a pixel-art Christmas tree on VGA, for the Tiny Tapeout
 * micro tile (clk, rst_n, ui_in, uo_out only).
 *
 * 640x480 at 60 Hz from a 25.175 MHz clock, 2 bits per colour on the TinyVGA
 * Pmod pinout.  The picture is a 40 x 30 grid of 16-pixel cells drawn with
 * combinational logic only, no frame buffer:
 *   - a star on top that blinks, a three-tier fir tree, colour-cycling lights,
 *     a trunk and a snow-covered ground
 *   - snow falling in the night sky
 *   - "PASKO" in red on the snow
 * The 16-pixel cells keep the logic inside the micro tile; the long greeting
 * of the 1x1 version (font ROM, banner) does not fit.
 */

`default_nettype none

module tt_um_XmasTree_MaligayangPasko (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  wire pause = ui_in[0];        // freeze the animation (snow, lights, star)

  // ---------------------------------------------------------------- timing
  // H: 640 visible, 16 front porch, 96 sync, 48 back porch = 800
  // V: 480 visible, 10 front porch,  2 sync, 33 back porch = 525
  reg [9:0] hc;
  reg [9:0] vc;
  reg [5:0] t;                  // frame counter

  wire h_end = (hc == 10'd799);
  wire v_end = (vc == 10'd524);

  always @(posedge clk) begin
    if (!rst_n) begin
      hc <= 10'd0;
      vc <= 10'd0;
      t  <= 6'd0;
    end else begin
      hc <= h_end ? 10'd0 : hc + 10'd1;
      if (h_end) begin
        vc <= v_end ? 10'd0 : vc + 10'd1;
        if (v_end && !pause) t <= t + 6'd1;
      end
    end
  end

  wire hs_n   = ~((hc[9:4] >= 6'd41) && (hc[9:4] < 6'd47));   // 656 .. 751
  wire vs_n   = ~(vc[9:1] == 9'd245);                         // 490, 491
  wire active = ~(hc[9] & (hc[8] | hc[7])) &                  // hc < 640
                ~(vc[9] | (&vc[8:5]));                        // vc < 480

  // ------------------------------------------------------------------ grid
  wire [5:0] cx = hc[9:4];      // cell column 0..39
  wire [4:0] cy = vc[8:4];      // cell row    0..29

  // distance from the centre line (between columns 19 and 20)
  wire [5:0] u  = cx - 6'd20;
  wire [5:0] dx = u[5] ? ~u : u;

  // rows: 4 star, 5..20 tree, 21..23 trunk, 24..29 snow
  reg [3:0] hw;                 // tree half-width (cells) of the row
  always @* begin
    case (cy)
      5'd5:  hw = 4'd0;   5'd6:  hw = 4'd1;   5'd7:  hw = 4'd2;   5'd8:  hw = 4'd3;
      5'd9:  hw = 4'd1;   5'd10: hw = 4'd2;   5'd11: hw = 4'd3;   5'd12: hw = 4'd4;
      5'd13: hw = 4'd5;   5'd14: hw = 4'd2;   5'd15: hw = 4'd3;   5'd16: hw = 4'd4;
      5'd17: hw = 4'd5;   5'd18: hw = 4'd6;   5'd19: hw = 4'd7;   5'd20: hw = 4'd8;
      default: hw = 4'd0;
    endcase
  end

  wire tree_row = (cy >= 5'd5) & (cy <= 5'd20);
  wire in_tree  = tree_row & (dx <= {2'b00, hw});
  wire edge_c   = in_tree & (dx == {2'b00, hw});
  wire middle   = (dx == 6'd0);
  wire star     = (cy == 5'd4) & middle;
  wire trunk    = (cy >= 5'd21) & (cy <= 5'd23) & middle;
  wire ground   = cy[4] & cy[3];

  // "PASKO", 3x5 cells a letter with one cell between letters, on rows 25..29 from column 10
  wire [5:0] o   = cx - 6'd10;
  wire [2:0] li  = o[4:2];                 // letter 0..4
  wire [1:0] lcol = o[1:0];                // 0..2 (3 is the gap)
  wire [2:0] lrow = cy[2:0];               // 1..5 are the glyph rows
  reg  [14:0] gl;                          // glyph, row 0 in the top 3 bits
  always @* begin
    case (li)
      3'd0:    gl = 15'b111_101_111_100_100;   // P
      3'd1:    gl = 15'b111_101_111_101_101;   // A
      3'd2:    gl = 15'b111_100_111_001_111;   // S
      3'd3:    gl = 15'b101_101_110_101_101;   // K
      default: gl = 15'b111_101_101_101_111;   // O
    endcase
  end
  reg [2:0] gr;
  always @* begin
    case (lrow)
      3'd1: gr = gl[14:12];  3'd2: gr = gl[11:9];  3'd3: gr = gl[8:6];
      3'd4: gr = gl[5:3];    3'd5: gr = gl[2:0];    default: gr = 3'b000;
    endcase
  end
  wire text = ground & (cx >= 6'd10) & (o < 6'd19) & (lcol != 2'd3) & gr[2'd2 - lcol];

  // lights on every fourth cell inside the tree, colour cycles with the frame count
  wire light = in_tree & ~edge_c & (cx[0] ^ cy[0]) & (cx[2] ^ cy[2]);
  wire [1:0] lc = {cx[1], cy[1]} ^ t[5:4];

  // falling snow: a 4x4 pixel flake in every fourth cell column, each column with its own phase
  wire [6:0] x8 = hc[9:3];
  wire [3:0] ph = x8[6:3] ^ {x8[4:3], x8[6:5]};
  wire flake = (x8[1:0] == 2'b01) & ~hc[2] & ~vc[2] & ((vc[6:3] + ph) == t[5:2]);

  // ----------------------------------------------------------------- colour
  reg [5:0] rgb;                // {R1 R0 G1 G0 B1 B0}
  always @* begin
    if      (star)   rgb = t[4] ? 6'b11_11_00 : 6'b11_11_11;
    else if (light)  rgb = (lc == 2'd0) ? 6'b11_00_00 :
                           (lc == 2'd1) ? 6'b11_11_00 :
                           (lc == 2'd2) ? 6'b11_11_11 : 6'b00_11_11;
    else if (edge_c) rgb = 6'b00_01_00;
    else if (in_tree) rgb = 6'b00_10_00;
    else if (trunk)  rgb = 6'b10_01_00;
    else if (text)   rgb = 6'b11_00_00;
    else if (ground) rgb = 6'b11_11_11;
    else if (flake)  rgb = 6'b11_11_11;
    else             rgb = 6'b00_00_01;
  end

  // ---------------------------------------------------------------- output
  // TinyVGA Pmod: uo[0]=R1 [1]=G1 [2]=B1 [3]=VS [4]=R0 [5]=G0 [6]=B0 [7]=HS
  reg [7:0] out;
  always @(posedge clk) begin
    out <= {hs_n, active ? {rgb[0], rgb[2], rgb[4]} : 3'b000,
            vs_n, active ? {rgb[1], rgb[3], rgb[5]} : 3'b000};
  end
  assign uo_out = out;

endmodule
