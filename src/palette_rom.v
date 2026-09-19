/*
 * Copyright (c) 2025 James Ross
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module palette_rom(
	input  wire [2:0] cid, // color id
	input  wire [1:0] pid, // palette
	output wire [5:0] color
);
	// color palette (RRGGBB)
	reg [5:0] palette[3:0][7:0];
	assign color = palette[pid][cid];
	initial begin
		palette[0][0] = 6'b000000; // green (default)
		palette[0][1] = 6'b000100;
		palette[0][2] = 6'b001000;
		palette[0][3] = 6'b001100;
		palette[0][4] = 6'b001101;
		palette[0][5] = 6'b011101;
		palette[0][6] = 6'b011110;
		palette[0][7] = 6'b101110;
		palette[1][0] = 6'b000000; // red
		palette[1][1] = 6'b010000;
		palette[1][2] = 6'b100000;
		palette[1][3] = 6'b110000;
		palette[1][4] = 6'b110001;
		palette[1][5] = 6'b110101;
		palette[1][6] = 6'b110110;
		palette[1][7] = 6'b111010;
		palette[2][0] = 6'b000000; // blue
		palette[2][1] = 6'b000001;
		palette[2][2] = 6'b000010;
		palette[2][3] = 6'b000011;
		palette[2][4] = 6'b000111;
		palette[2][5] = 6'b010111;
		palette[2][6] = 6'b011011;
		palette[2][7] = 6'b101011;
		palette[3][0] = 6'b000000; // pride
		palette[3][1] = 6'b110000;
		palette[3][2] = 6'b111000;
		palette[3][3] = 6'b111100;
		palette[3][4] = 6'b001000;
		palette[3][5] = 6'b000111;
		palette[3][6] = 6'b100010;
		palette[3][7] = 6'b110011;
	end
endmodule
