module ControlRegs (
	clk,
	rst,
	IN_ce,
	IN_we,
	IN_wm,
	IN_addr,
	IN_data,
	OUT_data,
	IN_comValid,
	IN_branch,
	IN_wbValid,
	IN_ifValid,
	IN_comBranch,
	OUT_irqAddr,
	IN_irqTaken,
	IN_irqSrc,
	IN_irqFlags,
	IN_irqMemAddr,
	OUT_GPIO_oe,
	OUT_GPIO,
	IN_GPIO,
	OUT_SPI_clk,
	OUT_SPI_mosi,
	IN_SPI_miso,
	OUT_AGU_mapping,
	OUT_IO_busy
);
	parameter NUM_UOPS = 2;
	parameter NUM_WBS = 3;
	input wire clk;
	input wire rst;
	input wire IN_ce;
	input wire IN_we;
	input wire [3:0] IN_wm;
	input wire [6:0] IN_addr;
	input wire [31:0] IN_data;
	output reg [31:0] OUT_data;
	input wire [NUM_UOPS - 1:0] IN_comValid;
	input wire [51:0] IN_branch;
	input wire [NUM_WBS - 1:0] IN_wbValid;
	input wire [NUM_UOPS - 1:0] IN_ifValid;
	input wire IN_comBranch;
	output wire [31:0] OUT_irqAddr;
	input wire IN_irqTaken;
	input wire [31:0] IN_irqSrc;
	input wire [1:0] IN_irqFlags;
	input wire [11:0] IN_irqMemAddr;
	output reg [15:0] OUT_GPIO_oe;
	output reg [15:0] OUT_GPIO;
	input wire [15:0] IN_GPIO;
	output reg OUT_SPI_clk;
	output reg OUT_SPI_mosi;
	input wire IN_SPI_miso;
	output wire [183:0] OUT_AGU_mapping;
	output wire OUT_IO_busy;
	integer i;
	reg ceReg;
	reg weReg;
	reg [3:0] wmReg;
	reg [6:0] addrReg;
	reg [31:0] dataReg;
	reg [63:0] cRegs64 [5:0];
	reg [7:0] gpioCnt;
	reg [31:0] cRegs [15:0];
	always @(*) begin
		OUT_GPIO_oe = cRegs[5][15:0];
		OUT_GPIO = cRegs[5][31:16];
	end
	assign OUT_irqAddr = cRegs[0];
	assign OUT_AGU_mapping[0+:23] = cRegs[8][31:9];
	assign OUT_AGU_mapping[23+:23] = cRegs[9][31:9];
	assign OUT_AGU_mapping[46+:23] = cRegs[10][31:9];
	assign OUT_AGU_mapping[69+:23] = cRegs[11][31:9];
	assign OUT_AGU_mapping[92+:23] = cRegs[12][31:9];
	assign OUT_AGU_mapping[115+:23] = cRegs[13][31:9];
	assign OUT_AGU_mapping[138+:23] = cRegs[14][31:9];
	assign OUT_AGU_mapping[161+:23] = cRegs[15][31:9];
	reg [5:0] spiCnt;
	assign OUT_IO_busy = (spiCnt != 0) || (gpioCnt != 0);
	always @(posedge clk)
		if (rst) begin
			gpioCnt <= 0;
			ceReg <= 1;
			for (i = 0; i < 6; i = i + 1)
				cRegs64[i] <= 0;
			for (i = 0; i < 8; i = i + 1)
				cRegs[i] <= 0;
			for (i = 0; i < 8; i = i + 1)
				cRegs[i + 8] <= i << 9;
			OUT_SPI_clk <= 0;
			spiCnt <= 0;
		end
		else begin
			if (OUT_SPI_clk == 1) begin
				OUT_SPI_clk <= 0;
				OUT_SPI_mosi <= cRegs[4][31];
			end
			else if (spiCnt != 0) begin
				OUT_SPI_clk <= 1;
				spiCnt <= spiCnt - 1;
				cRegs[4] <= {cRegs[4][30:0], IN_SPI_miso};
			end
			if (!ceReg)
				if (!weReg) begin
					if (addrReg[5])
						;
					else begin
						if (wmReg[0])
							cRegs[addrReg[3:0]][7:0] <= dataReg[7:0];
						if (wmReg[1])
							cRegs[addrReg[3:0]][15:8] <= dataReg[15:8];
						if (wmReg[2])
							cRegs[addrReg[3:0]][23:16] <= dataReg[23:16];
						if (wmReg[3])
							cRegs[addrReg[3:0]][31:24] <= dataReg[31:24];
						if (addrReg[3:0] == 4'd5)
							gpioCnt <= cRegs[6][7:0];
						if (addrReg[3:0] == 4'd4) begin
							case (wmReg)
								4'b1111: spiCnt <= 32;
								4'b1100: spiCnt <= 16;
								4'b1000: spiCnt <= 8;
								default:
									;
							endcase
							OUT_SPI_mosi <= dataReg[31];
						end
					end
				end
				else if (addrReg[5]) begin
					if (addrReg[0])
						OUT_data <= cRegs64[addrReg[3:1]][63:32];
					else
						OUT_data <= cRegs64[addrReg[3:1]][31:0];
				end
				else if (addrReg[3:0] == 4'd7)
					OUT_data <= {16'bxxxxxxxxxxxxxxxx, IN_GPIO};
				else
					OUT_data <= cRegs[addrReg[3:0]];
			if (gpioCnt == 0)
				cRegs[5][31:24] <= (cRegs[5][31:24] | cRegs[6][15:8]) & ~cRegs[6][23:16];
			else
				gpioCnt <= gpioCnt - 1;
			if (IN_irqTaken) begin
				cRegs[1] <= IN_irqSrc;
				cRegs[2] <= {4'b0000, IN_irqMemAddr, 14'b00000000000000, IN_irqFlags[1:0]};
			end
			ceReg <= IN_ce;
			weReg <= IN_we;
			wmReg <= IN_wm;
			addrReg <= IN_addr;
			dataReg <= IN_data;
			cRegs64[0] <= cRegs64[0] + 1;
			for (i = 0; i < NUM_UOPS; i = i + 1)
				begin
					if (IN_ifValid[i])
						cRegs64[1] = cRegs64[1] + 1;
					if (IN_comValid[i])
						cRegs64[3] = cRegs64[3] + 1;
				end
			for (i = 0; i < NUM_WBS; i = i + 1)
				if (IN_wbValid[i])
					cRegs64[2] = cRegs64[2] + 1;
			if (IN_branch[51])
				cRegs64[4] <= cRegs64[4] + 1;
			if (IN_comBranch)
				cRegs64[5] <= cRegs64[5] + 1;
		end
endmodule
