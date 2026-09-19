`default_nettype none

module glyphs_rom(
    input  wire [5:0] c, input  wire [3:0] y, input  wire [2:0] x, output reg pixel
);
    reg [7:0] rb; 

    always @(*) begin
        case (c) 
            0:  case(y) 2:rb=8'h3C; 3,4,5:rb=8'h66; 6,7:rb=8'hFF; 8,9,10:rb=8'hC3; default:rb=0; endcase // A
            1:  case(y) 2,6,10:rb=8'hFC; 3,4,5,7,8,9:rb=8'hC6; default:rb=0; endcase // B
            2:  case(y) 2,10:rb=8'h7E; 3,9:rb=8'hC3; 4,5,6,7,8:rb=8'hC0; default:rb=0; endcase // C
            3:  case(y) 2,10:rb=8'hF8; 3,4,5,6,7,8,9:rb=8'hC6; default:rb=0; endcase // D
            4:  case(y) 2,6,10:rb=8'hFE; 3,4,5,7,8,9:rb=8'hC0; default:rb=0; endcase // E
            5:  case(y) 2,6:rb=8'hFE; 3,4,5,7,8,9,10:rb=8'hC0; default:rb=0; endcase // F
            6:  case(y) 2,10:rb=8'h7E; 3,4,5:rb=8'hC0; 6:rb=8'hCE; 7,8,9:rb=8'hC6; default:rb=0; endcase // G
            7:  case(y) 2,3,4,5,7,8,9,10:rb=8'hC6; 6:rb=8'hFE; default:rb=0; endcase // H
            8:  case(y) 2,10:rb=8'h7E; 3,4,5,6,7,8,9:rb=8'h18; default:rb=0; endcase // I
            9:  case(y) 2:rb=8'h3F; 3,4,5,6,7,8:rb=8'h0C; 9:rb=8'hCC; 10:rb=8'h78; default:rb=0; endcase // J
            10: case(y) 2,10:rb=8'hC6; 3,9:rb=8'hCC; 4,8:rb=8'hD8; 5,7:rb=8'hF0; 6:rb=8'hE0; default:rb=0; endcase // K
            11: case(y) 2,3,4,5,6,7,8,9:rb=8'hC0; 10:rb=8'hFE; default:rb=0; endcase // L
            12: case(y) 2:rb=8'hC3; 3:rb=8'hE7; 4:rb=8'hFF; 5:rb=8'hDB; 6,7,8,9,10:rb=8'hC3; default:rb=0; endcase // M
            13: case(y) 2,3:rb=8'hC6; 4:rb=8'hE6; 5:rb=8'hF6; 6:rb=8'hD6; 7:rb=8'hC6; 8:rb=8'hCE; 9,10:rb=8'hC6; default:rb=0; endcase // N
            14: case(y) 2,10:rb=8'h3C; 3,9:rb=8'h66; 4,5,6,7,8:rb=8'hC3; default:rb=0; endcase // O
            15: case(y) 2,6:rb=8'hFC; 3,4,5:rb=8'hC6; 7,8,9,10:rb=8'hC0; default:rb=0; endcase // P
            16: case(y) 2,10:rb=8'h3C; 3,9:rb=8'h66; 4,5,6,7:rb=8'hC3; 8:rb=8'hD3; 9:rb=8'h66; 11:rb=8'h0C; default:rb=0; endcase // Q
            17: case(y) 2,6:rb=8'hFC; 3,4,5:rb=8'hC6; 7,8,9:rb=8'hD8; 10:rb=8'hC6; default:rb=0; endcase // R
            18: case(y) 2:rb=8'h3E; 3:rb=8'h63; 4:rb=8'h60; 5:rb=8'h7C; 6,7:rb=8'h06; 8:rb=8'h63; 9:rb=8'h3E; default:rb=0; endcase // S
            19: case(y) 2:rb=8'hFF; 3,4,5,6,7,8,9,10:rb=8'h18; default:rb=0; endcase // T
            20: case(y) 2,3,4,5,6,7,8,9:rb=8'hC6; 10:rb=8'h7E; default:rb=0; endcase // U
            21: case(y) 2,3,4,5,6:rb=8'hC3; 7,8:rb=8'h66; 9:rb=8'h3C; 10:rb=8'h18; default:rb=0; endcase // V
            22: case(y) 2,3,4,5:rb=8'hC3; 6:rb=8'hDB; 7:rb=8'hFF; 8:rb=8'hE7; 9,10:rb=8'hC3; default:rb=0; endcase // W
            23: case(y) 2,10:rb=8'hC3; 3,9:rb=8'h66; 4,8:rb=8'h3C; 5,6,7:rb=8'h18; default:rb=0; endcase // X
            24: case(y) 2,3,4,5:rb=8'hC3; 6:rb=8'h7E; 7,8,9,10:rb=8'h18; default:rb=0; endcase // Y
            25: case(y) 2,10:rb=8'hFF; 3:rb=8'h0E; 4:rb=8'h0C; 5:rb=8'h18; 6:rb=8'h30; 7:rb=8'h60; 8:rb=8'hC0; 9:rb=8'hE0; default:rb=0; endcase // Z
            26: rb = 8'h00; // SPACE
            27: case(y) 2:rb=8'h30; 3:rb=8'h78; 4,5,6,7,8,9:rb=8'h18; 10:rb=8'h7E; default:rb=0; endcase // 1
            28: case(y) 2:rb=8'h3E; 3:rb=8'h63; 4:rb=8'h03; 5:rb=8'h06; 6:rb=8'h1C; 7:rb=8'h30; 8,9:rb=8'h60; 10:rb=8'hFF; default:rb=0; endcase // 2
            29: case(y) 2,10:rb=8'h7E; 3,4,5,7,8,9:rb=8'h06; 6:rb=8'h3E; default:rb=0; endcase // 3
            30: case(y) 2,3,4,5:rb=8'h66; 6:rb=8'h7E; 7,8,9,10:rb=8'h06; default:rb=0; endcase // 4
            31: case(y) 2:rb=8'h7E; 3,4:rb=8'h60; 5:rb=8'h7C; 6,7,8:rb=8'h06; 9:rb=8'h66; 10:rb=8'h3C; default:rb=0; endcase // 5
            32: case(y) 2:rb=8'h3E; 3,4:rb=8'h60; 5:rb=8'h7C; 6,7,8,9:rb=8'h66; 10:rb=8'h3C; default:rb=0; endcase // 6
            33: case(y) 2:rb=8'hFF; 3:rb=8'h06; 4:rb=8'h0C; 5:rb=8'h18; 6,7,8,9,10:rb=8'h18; default:rb=0; endcase // 7
            34: case(y) 2,6,10:rb=8'h7E; 3,4,5,7,8,9:rb=8'h66; default:rb=0; endcase // 8
            35: case(y) 2,6,10:rb=8'h7E; 3,4,5:rb=8'h66; 7,8,9:rb=8'h06; default:rb=0; endcase // 9
            36: case(y) 2,10:rb=8'h3C; 3,4,5,6,7,8,9:rb=8'h66; default:rb=0; endcase // 0
            37: case(y) 2,3,4,5,6,7:rb=8'h18; 9,10:rb=8'h18; default:rb=0; endcase // !
            38: rb = 8'h00; // TRAILING SPACE
            default: rb = 8'h00; 
        endcase
        pixel = rb[7-x];
    end
endmodule