/*
 * Retro arcade space shooter for Tiny Tapeout VGA Playground
 * SPDX-License-Identifier: Apache-2.0
 *
 * Arrow keys (Gamepad PMOD) or ui_in[0..3] : move    Start / ui_in[7] : restart
 * Auto-fire always on. Enemies come from every edge, more of them and faster over time.
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
  localparam NB           = 16;   // bullet slots; enough for continuous fire
  localparam NE           = 12;   // maximum simultaneous enemies
  localparam START_HP     = 5;
  localparam LEVEL_FRAMES = 240;  // frames per difficulty level (~4 s at 60 Hz)
  localparam FIRE_FRAMES  = 3;    // same rapid fire cadence as the original (~20 shots/sec)

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
    .hsync(hsync), .vsync(vsync), .display_on(video_active),
    .hpos(pix_x), .vpos(pix_y)
  );

  wire frame_tick = (pix_x == 10'd0) && (pix_y == 10'd480);  // once per frame

  // ---------------------------------------------------------------- input
  // Gamepad PMOD reader (arrow keys in the playground): ui_in[6]=data, [5]=clock, [4]=latch.
  // Bits are sampled on the rising clock edge, a latch pulse ends a report, HIGH = pressed.
  // Order: B Y Select Start Up Down Left Right A X L R.
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

  // controller 1 = low 12 bits for a 12-bit report, upper 12 for a 24-bit report
  wire [11:0] pad    = (pad_raw[11:0] == 12'hFFF) ? pad_raw[23:12] : pad_raw[11:0];
  wire        pad_ok = (pad != 12'hFFF);          // all ones = controller not connected

  wire left    = (pad_ok & pad[5]) | ui_in[0];
  wire right   = (pad_ok & pad[4]) | ui_in[1];
  wire up      = (pad_ok & pad[7]) | ui_in[2];
  wire down    = (pad_ok & pad[6]) | ui_in[3];
  wire restart = (pad_ok & pad[8]) | ui_in[7];

  wire _unused_ok = &{ena, uio_in};

  // ---------------------------------------------------------------- state
  reg [9:0]  px, py;                      // player top-left (16x16)
  reg [2:0]  hp, level;
  reg [3:0]  sp_idx;
  reg [3:0]  fb_idx;
  reg [5:0]  inv, spawn_t;                // invulnerability / spawn timers
  reg [3:0]  fire_t;
  reg [8:0]  over_t;
  reg [9:0]  lvl_t, scroll;
  reg [15:0] lfsr;

  reg [NB-1:0] b_on;                      // bullets (16x12)
  reg [9:0]    bx [0:NB-1];
  reg [9:0]    by [0:NB-1];

  reg [NE-1:0] e_on, e_armor;             // enemies (16x16)
  reg [9:0]    ex [0:NE-1];
  reg [9:0]    ey [0:NE-1];
  reg [1:0]    etype [0:NE-1];            // 0=soldier 1=shield trooper (2 hits) 2=invader 3=bird (homing)
  reg [1:0]    edir  [0:NE-1];            // 0=down 1=up 2=right 3=left

  wire game_over = (hp == 3'd0);
  wire game_rst  = ~rst_n | (game_over & (restart | over_t == 9'd300));

  always @(posedge clk)
    lfsr <= ~rst_n ? 16'hACE1 : {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

  // Active enemy count grows gradually: 2 -> 4 -> 6 -> 8 -> 10 -> 12.
  // sp_idx is wrapped explicitly, avoiding modulo/division hardware.
  wire [3:0] active_enemies = (level == 3'd0) ? 4'd2 :
                              (level == 3'd1) ? 4'd4 :
                              (level == 3'd2) ? 4'd6 :
                              (level == 3'd3) ? 4'd8 :
                              (level == 3'd4) ? 4'd10 : 4'd12;
  wire [3:0] slot = sp_idx;

  // speed by enemy type and level
  function [9:0] spd(input [1:0] t, input [2:0] l);
    case (t)
      2'd0:    spd = 10'd2 + l;          // soldier
      2'd1:    spd = 10'd2 + l + 1'd1;   // shield
      2'd2:    spd = 10'd3 + l;          // invader
      default: spd = 10'd3 + l + 1'd1;   // flying/homing target
    endcase
  endfunction

  // random spawn coordinates (fully on screen)
  wire [9:0] rx = (lfsr[9:0]  > 10'd623) ? lfsr[9:0]  - 10'd400 : lfsr[9:0];   // 0..623
  wire [9:0] ry = (lfsr[15:7] > 9'd463)  ? lfsr[15:7] - 9'd48   : lfsr[15:7];  // 0..463
  wire [1:0] sd = lfsr[13:12]; // 0=top, 1=bottom, 2=left, 3=right

  // Flying targets become more common as difficulty rises.
  // Level 0-1: no birds, level 2+: roughly 50% chance of a bird.
  wire [1:0] st = (level < 3'd2) ? lfsr[11:10] :
                  (lfsr[11] ? 2'd3 : lfsr[10:9]);

  // ---------------------------------------------------------------- game logic (once per frame)
  integer i, j;
  always @(posedge clk) begin
    if (game_rst) begin
      px <= 10'd312; py <= 10'd440;
      hp <= START_HP; level <= 0; inv <= 0; sp_idx <= 0; fb_idx <= 0;
      lvl_t <= 0; fire_t <= 0; spawn_t <= 6'd48; over_t <= 0; scroll <= 0;
      b_on <= 0; e_on <= 0; e_armor <= 0;
    end else if (frame_tick) begin
      scroll <= scroll + 10'd1;

      if (game_over) over_t <= over_t + 9'd1;
      else begin
        // player movement
        if (left  && px > 10'd7)   px <= px - 10'd7;
        if (right && px < 10'd617) px <= px + 10'd7;
        if (up    && py > 10'd27)  py <= py - 10'd7;
        if (down  && py < 10'd457) py <= py + 10'd7;

        // difficulty ramp
        if (lvl_t == LEVEL_FRAMES - 1) begin
          lvl_t <= 0;
          if (level != 3'd7) level <= level + 3'd1;
        end else lvl_t <= lvl_t + 10'd1;

        // timers
        if (inv != 0) inv <= inv - 6'd1;

        // Controlled auto-fire. The bullet pool still hard-caps the
        // number of bullets on screen, preventing an unlimited stream.
        if (fire_t == FIRE_FRAMES - 1)
          fire_t <= 0;
        else
          fire_t <= fire_t + 1'd1;

        // Spawn interval: 42 -> 36 -> 30 -> 24 -> 18 -> 12 -> 9 -> 7.
        // Difficulty increases both enemy count and pressure.
        if (spawn_t == 0) begin
          case (level)
            3'd0: spawn_t <= 6'd42;
            3'd1: spawn_t <= 6'd36;
            3'd2: spawn_t <= 6'd30;
            3'd3: spawn_t <= 6'd24;
            3'd4: spawn_t <= 6'd18;
            3'd5: spawn_t <= 6'd12;
            3'd6: spawn_t <= 6'd9;
            default: spawn_t <= 6'd7;
          endcase
        end else
          spawn_t <= spawn_t - 1'd1;

        // bullets: fly up, vanish at the top edge
        for (i = 0; i < NB; i = i + 1)
          if (b_on[i]) begin
            if (by[i] < 10'd14) b_on[i] <= 0;
            else               by[i] <= by[i] - 10'd14;
          end

        // Continuous auto-fire.
        // The cadence and bullet movement speed are unchanged from the
        // original: one shot every 3 frames, bullet speed = 14 px/frame.
        // A larger pool prevents the stream from stopping when older
        // bullets are still travelling upward.
        if (fire_t == FIRE_FRAMES - 1) begin
          if (fb_idx == NB-1)
            fb_idx <= 0;
          else
            fb_idx <= fb_idx + 1'd1;

          b_on[fb_idx] <= 1;
          bx[fb_idx]   <= px + 10'd6;
          by[fb_idx]   <= py - 10'd12;
        end

        // enemies: birds chase the player, everything else flies straight across
        for (j = 0; j < NE; j = j + 1)
          if (e_on[j]) begin
            if (etype[j] == 2'd3) begin
              if      (ex[j] + spd(2'd3, level) <= px) ex[j] <= ex[j] + spd(2'd3, level);
              else if (ex[j] >= px + spd(2'd3, level)) ex[j] <= ex[j] - spd(2'd3, level);
              if      (ey[j] + spd(2'd3, level) <= py) ey[j] <= ey[j] + spd(2'd3, level);
              else if (ey[j] >= py + spd(2'd3, level)) ey[j] <= ey[j] - spd(2'd3, level);
            end else
              case (edir[j])
                2'd0: begin
                  if (ey[j] >= 10'd464 || ey[j] + spd(etype[j], level) >= 10'd480)
                    e_on[j] <= 0;
                  else
                    ey[j] <= ey[j] + spd(etype[j], level);
                end
                2'd1: begin
                  if (ey[j] <= spd(etype[j], level))
                    e_on[j] <= 0;
                  else
                    ey[j] <= ey[j] - spd(etype[j], level);
                end
                2'd2: begin
                  if (ex[j] >= 10'd624 || ex[j] + spd(etype[j], level) >= 10'd640)
                    e_on[j] <= 0;
                  else
                    ex[j] <= ex[j] + spd(etype[j], level);
                end
                2'd3: begin
                  if (ex[j] <= spd(etype[j], level))
                    e_on[j] <= 0;
                  else
                    ex[j] <= ex[j] - spd(etype[j], level);
                end
              endcase
          end

        // Spawn from a random edge into the next active slot.
        // When the active enemy count grows, more slots become available.
        if (spawn_t == 0) begin
          if (sp_idx >= active_enemies - 1)
            sp_idx <= 0;
          else
            sp_idx <= sp_idx + 1'd1;

          if (!e_on[slot]) begin
            e_on[slot]    <= 1;
            e_armor[slot] <= (st == 2'd1);
            etype[slot]   <= st;
            edir[slot]    <= sd;
            ex[slot]      <= (sd == 2'd2) ? 10'd0 : (sd == 2'd3) ? 10'd624 : rx;
            ey[slot]      <= (sd == 2'd0) ? 10'd0 : (sd == 2'd1) ? 10'd464 : ry;
          end
        end

        // collisions
        // The invulnerability timer guarantees that only one player hit can
        // reduce HP during a recovery period.
        for (j = 0; j < NE; j = j + 1)
          if (e_on[j]) begin
            if (px < ex[j] + 10'd16 && ex[j] < px + 10'd16 &&
                py < ey[j] + 10'd16 && ey[j] < py + 10'd16) begin
              e_on[j] <= 0;
              if (inv == 0) begin
                hp  <= hp - 3'd1;
                inv <= 6'd60;
              end
            end

            // One bullet hit consumes one bullet. Shielded enemies first
            // lose armor, then require another hit.
            for (i = 0; i < NB; i = i + 1)
              if (b_on[i] &&
                  bx[i] < ex[j] + 10'd16 && ex[j] < bx[i] + 10'd4 &&
                  by[i] < ey[j] + 10'd16 && ey[j] < by[i] + 10'd12) begin
                b_on[i] <= 0;
                if (e_armor[j])
                  e_armor[j] <= 0;
                else
                  e_on[j] <= 0;
              end
          end
      end
    end
  end

  // ---------------------------------------------------------------- per-line sprite flags
  // Vertical tests are done once per scanline (in the blanking area), so the per-pixel
  // renderer only needs one horizontal compare per sprite. This is what keeps the FPS up.
  wire [9:0] nl = (pix_y == 10'd524) ? 10'd0 : pix_y + 10'd1;   // next visible line
  reg [NE-1:0] e_line;
  reg [3:0]    elr [0:NE-1];
  reg [NB-1:0] b_line;
  reg          p_line;
  reg [3:0]    plr;
  integer m;

  always @(posedge clk)
    if (pix_x == 10'd700) begin
      for (m = 0; m < NE; m = m + 1) begin
        e_line[m] <= e_on[m] && (nl - ey[m] < 10'd16);
        elr[m]    <= nl - ey[m];
      end
      for (m = 0; m < NB; m = m + 1) b_line[m] <= b_on[m] && (nl - by[m] < 10'd12);
      p_line <= (nl - py < 10'd16);
      plr    <= nl - py;
    end

  // ---------------------------------------------------------------- sprites (8x8 bitmaps drawn at 2x)
  function [63:0] sprite(input [2:0] s);
    case (s)
      3'd0: sprite = {8'b00111100, 8'b01111110, 8'b00100100, 8'b00111100,   // soldier
                      8'b01111110, 8'b10111101, 8'b00111100, 8'b01100110};
      3'd1: sprite = {8'b00011000, 8'b00111100, 8'b01111110, 8'b11111111,   // shield trooper
                      8'b11111111, 8'b01111110, 8'b00111100, 8'b00011000};
      3'd2: sprite = {8'b00100100, 8'b10100101, 8'b11111111, 8'b11011011,   // invader
                      8'b11111111, 8'b01111110, 8'b00100100, 8'b01000010};
      3'd3: sprite = {8'b10000001, 8'b11000011, 8'b01100110, 8'b00111100,   // bird, wings up
                      8'b00011000, 8'b00011000, 8'b00000000, 8'b00000000};
      3'd4: sprite = {8'b00000000, 8'b00011000, 8'b00111100, 8'b01111110,   // bird, wings down
                      8'b11111111, 8'b11000011, 8'b10000001, 8'b00000000};
      default: sprite = {8'b00011000, 8'b00011000, 8'b00111100, 8'b01111110, // player fighter
                         8'b01111110, 8'b11111111, 8'b11011011, 8'b10000001};
    endcase
  endfunction

  // "GAME OVER" text: 5x7 font, 4x scale, 32 px cell
  function [34:0] glyph(input [3:0] c);
    case (c)
      0:       glyph = 35'b01110_10001_10000_10111_10001_10001_01110; // G
      1:       glyph = 35'b01110_10001_10001_11111_10001_10001_10001; // A
      2:       glyph = 35'b10001_11011_10101_10101_10001_10001_10001; // M
      3, 7:    glyph = 35'b11111_10000_10000_11110_10000_10000_11111; // E
      5:       glyph = 35'b01110_10001_10001_10001_10001_10001_01110; // O
      6:       glyph = 35'b10001_10001_10001_10001_10001_01010_00100; // V
      8:       glyph = 35'b11110_10001_10001_11110_10100_10010_10001; // R
      default: glyph = 35'd0;                                         // space
    endcase
  endfunction

  // ---------------------------------------------------------------- rendering
  wire [9:0] sy   = pix_y - scroll;                 // scrolling starfield
  wire       star = (pix_x[6:0] == {sy[5:3], sy[9:6]}) && sy[2:0] == 0 && pix_x[2];

  integer r;
  reg [9:0]  lx, tx, ty;
  reg [2:0]  sel;
  reg [5:0]  gi;
  reg [34:0] g;
  reg [63:0] bm;

  always @* begin
    lx = 0; tx = 0; ty = 0; sel = 0; gi = 0; g = 0; bm = 0;
    rgb = star ? 6'b01_01_01 : 6'b00_00_00;

    // enemies
    for (r = 0; r < NE; r = r + 1) begin
      lx = pix_x - ex[r];
      if (e_line[r] && lx < 10'd16) begin
        sel = (etype[r] == 2'd3) ? (scroll[3] ? 3'd4 : 3'd3) : {1'b0, etype[r]};
        bm = sprite(sel);
        if (bm[~{elr[r][3:1], lx[3:1]}])
          rgb = (etype[r] == 2'd0) ? 6'b11_00_00 :
                (etype[r] == 2'd1) ? (e_armor[r] ? 6'b00_11_00 : 6'b00_10_00) :
                (etype[r] == 2'd2) ? 6'b11_00_11 : 6'b00_11_11;
      end
    end

    // bullets (yellow)
    for (r = 0; r < NB; r = r + 1)
      if (b_line[r] && (pix_x - bx[r]) < 10'd4) rgb = 6'b11_11_00;

    // player (blinks while recovering)
    lx = pix_x - px;
    bm = sprite(3'd5);
    if (!game_over && p_line && lx < 10'd16 && (inv == 0 || inv[2]) && bm[~{plr[3:1], lx[3:1]}])
      rgb = 6'b11_11_11;

    // HUD: health (red, left) and difficulty level (blue, right)
    if (pix_y >= 8 && pix_y < 16) begin
      for (r = 0; r < START_HP; r = r + 1)
        if (r < hp && pix_x >= 8 + 16*r && pix_x < 20 + 16*r) rgb = 6'b11_00_00;
      for (r = 0; r < 8; r = r + 1)
        if (r <= level && pix_x >= 520 + 12*r && pix_x < 528 + 12*r) rgb = 6'b01_10_11;
    end

    // game over: flashing red frame + text
    if (game_over) begin
      if (scroll[4] && (pix_x < 8 || pix_x >= 632 || pix_y < 8 || pix_y >= 472)) rgb = 6'b11_00_00;
      if (pix_x >= 176 && pix_x < 464 && pix_y >= 200 && pix_y < 228) begin
        tx = pix_x - 10'd176;
        ty = pix_y - 10'd200;
        g  = glyph(tx[8:5]);
        gi = 6'd34 - {3'b0, ty[4:2]} * 6'd5 - {3'b0, tx[4:2]};
        if (tx[4:2] < 3'd5 && g[gi]) rgb = 6'b11_11_11;
      end
    end
  end

endmodule