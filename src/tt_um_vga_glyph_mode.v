/*
 * Retro arcade space shooter for Tiny Tapeout VGA Playground
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
/* verilator lint_off WIDTH */
/* verilator lint_off UNUSED */
/* verilator lint_off UNDRIVEN */
/* verilator lint_off PINMISSING */
/* verilator lint_off CMPCONST */
/* verilator lint_off LATCH */
/* verilator lint_off BLKSEQ */
/* verilator lint_off DECLFILENAME */

module tt_um_vga_glyph_mode(
  input  wire [7:0] ui_in,    // Dedicated inputs (Gamepad PMOD on [6:4])
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // always 1 when the design is powered
  input  wire       clk,      // clock (25 MHz)
  input  wire       rst_n     // reset_n - low to reset
);

  // ---------------------------------------------------------------- tunables
  localparam START_HP     = 5;
  localparam LEVEL_FRAMES = 240;
  localparam FIRE_FRAMES  = 3;

  // ---------------------------------------------------------------- VGA
  wire hsync, vsync, video_active;
  wire [9:0] pix_x, pix_y;
  wire [1:0] R, G, B;
  reg  [5:0] rgb;

  assign uo_out  = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  assign uio_out = 8'd0;
  assign uio_oe  = 8'd0;
  assign {R, G, B} = video_active ? rgb : 6'd0;

  hvsync_generator hvsync_gen(
    .clk(clk), .reset(~rst_n),
    .mode(2'b00),
    .hsync(hsync), .vsync(vsync), .display_on(video_active),
    .hpos(pix_x), .vpos(pix_y)
  );

  wire frame_tick = (pix_x == 10'd0) && (pix_y == 10'd480);

  // ---------------------------------------------------------------- input
  reg [1:0]  s_d, s_c, s_l;
  reg        c_prev, l_prev;
  reg [23:0] sr, pad_raw;

  always @(posedge clk) begin
    if (~rst_n) begin
      s_d <= 0; s_c <= 0; s_l <= 0; c_prev <= 0; l_prev <= 0; sr <= 0; pad_raw <= 0;
    end else begin
      s_d <= {s_d[0], ui_in[6]};
      s_c <= {s_c[0], ui_in[5]};
      s_l <= {s_l[0], ui_in[4]};
      c_prev <= s_c[1];
      l_prev <= s_l[1];
      if (s_c[1] & ~c_prev) sr      <= {sr[22:0], s_d[1]};
      if (s_l[1] & ~l_prev) pad_raw <= sr;
    end
  end

  wire [11:0] pad    = (pad_raw[11:0] == 12'hFFF) ? pad_raw[23:12] : pad_raw[11:0];
  wire        pad_ok = (pad != 12'hFFF);

  wire left    = (pad_ok & pad[5]) | ui_in[0];
  wire right   = (pad_ok & pad[4]) | ui_in[1];
  wire up      = (pad_ok & pad[7]) | ui_in[2];
  wire down    = (pad_ok & pad[6]) | ui_in[3];
  wire restart = (pad_ok & pad[8]) | ui_in[7];

  wire _unused_ok = &{ena, uio_in};

  // ---------------------------------------------------------------- state
  reg [9:0]  px, py;
  reg [2:0]  hp, level;
  reg [5:0]  inv, spawn_t;
  reg [3:0]  fire_t;
  reg [8:0]  over_t;
  reg [9:0]  lvl_t, scroll;
  reg [15:0] lfsr;

  // Single bullet register
  reg        b_on;
  reg [9:0]  bx;
  reg [9:0]  by;

  // Single enemy register (Simplified)
  reg        e_on;
  reg [9:0]  ex;
  reg [9:0]  ey;

  wire game_over = (hp == 3'd0);
  wire game_rst  = ~rst_n | (game_over & (restart | over_t == 9'd300));

  always @(posedge clk)
    lfsr <= ~rst_n ? 16'hACE1 : {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

  wire [9:0] rx = (lfsr[9:0]  > 10'd623) ? lfsr[9:0]  - 10'd400 : lfsr[9:0];

  always @(posedge clk) begin
    if (game_rst) begin
      px <= 10'd312; py <= 10'd440;
      hp <= START_HP; level <= 0; inv <= 0;
      lvl_t <= 0; fire_t <= 0; spawn_t <= 6'd48; over_t <= 0; scroll <= 0;
      b_on <= 0; e_on <= 0;
    end else if (frame_tick) begin
      scroll <= scroll + 10'd1;

      if (game_over) over_t <= over_t + 9'd1;
      else begin
        // player movement
        if (left  && px > 10'd7)   px <= px - 10'd7;
        if (right && px < 10'd617) px <= px + 10'd7;
        if (up    && py > 10'd27)  py <= py - 10'd7;
        if (down  && py < 10'd457) py <= py + 10'd7;

        if (lvl_t == LEVEL_FRAMES - 1) begin
          lvl_t <= 0;
          if (level != 3'd7) level <= level + 3'd1;
        end else lvl_t <= lvl_t + 10'd1;

        if (inv != 0) inv <= inv - 6'd1;

        if (fire_t == FIRE_FRAMES - 1) fire_t <= 0;
        else fire_t <= fire_t + 1'd1;

        if (spawn_t == 0) spawn_t <= 6'd42;
        else spawn_t <= spawn_t - 1'd1;

        // bullet movement
        if (b_on) begin
          if (by < 10'd14) b_on <= 0;
          else             by <= by - 10'd14;
        end

        // Auto-fire
        if (fire_t == FIRE_FRAMES - 1 && !b_on) begin
          b_on <= 1;
          bx   <= px + 10'd6;
          by   <= py - 10'd12;
        end

        // enemy movement (Simplified to fly straight down)
        if (e_on) begin
          if (ey >= 10'd464 || ey + 10'd2 + level >= 10'd480) e_on <= 0;
          else ey <= ey + 10'd2 + level;
        end

        // Enemy spawn (Always spawns at the top now)
        if (spawn_t == 0) begin
          if (!e_on) begin
            e_on    <= 1;
            ex      <= rx;
            ey      <= 10'd0;
          end
        end

        // Collisions
        if (e_on) begin
          // Player hit
          if (px < ex + 10'd16 && ex < px + 10'd16 && py < ey + 10'd16 && ey < py + 10'd16) begin
            e_on <= 0;
            if (inv == 0) begin
              hp  <= hp - 3'd1;
              inv <= 6'd60;
            end
          end

          // Bullet hit
          if (b_on && bx < ex + 10'd16 && ex < bx + 10'd4 && by < ey + 10'd16 && ey < by + 10'd12) begin
            b_on <= 0;
            e_on <= 0;
          end
        end
      end
    end
  end

  // ---------------------------------------------------------------- per-line sprite flags
  wire [9:0] nl = (pix_y == 10'd524) ? 10'd0 : pix_y + 10'd1;
  reg e_line;
  reg [3:0] elr;
  reg b_line;
  reg p_line;
  reg [3:0] plr;

  always @(posedge clk)
    if (pix_x == 10'd700) begin
      e_line <= e_on && (nl - ey < 10'd16);
      elr    <= nl - ey;
      b_line <= b_on && (nl - by < 10'd12);
      p_line <= (nl - py < 10'd16);
      plr    <= nl - py;
    end

  // Simplified to only 2 sprites to save ROM space
  function [63:0] sprite(input s);
    case (s)
      1'b1: sprite = {8'b00111100, 8'b01111110, 8'b00100100, 8'b00111100, // enemy
                      8'b01111110, 8'b10111101, 8'b00111100, 8'b01100110};
      default: sprite = {8'b00011000, 8'b00011000, 8'b00111100, 8'b01111110, // player
                         8'b01111110, 8'b11111111, 8'b11011011, 8'b10000001};
    endcase
  endfunction

  wire [9:0] sy   = pix_y - scroll;
  wire       star = (pix_x[6:0] == {sy[5:3], sy[9:6]}) && sy[2:0] == 0 && pix_x[2];

  reg [9:0]  lx;
  reg [63:0] bm;

  always @* begin
    lx = 0; bm = 0;
    rgb = star ? 6'b01_01_01 : 6'b00_00_00;

    // Enemy rendering
    lx = pix_x - ex;
    if (e_line && lx < 10'd16) begin
      bm = sprite(1'b1);
      if (bm[~{elr[3:1], lx[3:1]}]) rgb = 6'b11_00_00;
    end

    // Bullet rendering
    if (b_line && (pix_x - bx) < 10'd4) rgb = 6'b11_11_00;

    // Player rendering
    lx = pix_x - px;
    bm = sprite(1'b0);
    if (!game_over && p_line && lx < 10'd16 && (inv == 0 || inv[2]) && bm[~{plr[3:1], lx[3:1]}])
      rgb = 6'b11_11_11;

    // Optimized HUD (Solid bars instead of loops)
    if (pix_y >= 8 && pix_y < 16) begin
      if (pix_x >= 8 && pix_x < (8 + {hp, 4'b0000})) rgb = 6'b11_00_00;
      if (pix_x >= 520 && pix_x < (520 + {level, 3'b000})) rgb = 6'b01_10_11;
    end

    // Minimal Game Over (Flashing Screen)
    if (game_over) begin
      if (scroll[4] && (pix_x < 8 || pix_x >= 632 || pix_y < 8 || pix_y >= 472)) rgb = 6'b11_00_00;
    end
  end

endmodule