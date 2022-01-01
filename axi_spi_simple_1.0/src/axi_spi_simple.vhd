-- MIT License
--
--Copyright (c) 2021 Douglas H. Summerville, Department of Electical and Computer Engineering, Binghamton University
--
--Permission is hereby granted, free of charge, to any person obtaining a copy
--of this software and associated documentation files (the "Software"), to deal
--in the Software without restriction, including without limitation the rights
--to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--copies of the Software, and to permit persons to whom the Software is
--furnished to do so, subject to the following conditions:

--The above copyright notice and this permission notice shall be included in all
--copies or substantial portions of the Software.

--THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--SOFTWARE.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_spi_simple is
	generic (
        ACTIVE_LOW_SS : boolean := true;
        GPIO_WIDTH: integer := 32;
        USE_GPIO: boolean:= false;
		SAXI_DATA_WIDTH	: integer	:= 32;
		SAXI_ADDR_WIDTH	: integer	:= 2
	);
	port (
        mosi: out std_logic;
        ss: out std_logic;
        ssn: out std_logic;
        sclk: out std_logic;
        miso: in std_logic;
        gpo: out std_logic_vector(GPIO_WIDTH-1 downto 0);
		saxi_aclk	: in std_logic;
		saxi_aresetn	: in std_logic;
		saxi_awaddr	: in std_logic_vector(31 downto 0);
		saxi_awprot	: in std_logic_vector(2 downto 0);
		saxi_awvalid	: in std_logic;
		saxi_awready	: out std_logic;
		saxi_wdata	: in std_logic_vector(SAXI_DATA_WIDTH-1 downto 0);
		saxi_wstrb	: in std_logic_vector((SAXI_DATA_WIDTH/8)-1 downto 0);
		saxi_wvalid	: in std_logic;
		saxi_wready	: out std_logic;
		saxi_bresp	: out std_logic_vector(1 downto 0);
		saxi_bvalid	: out std_logic;
		saxi_bready	: in std_logic;
		saxi_araddr	: in std_logic_vector(31 downto 0);
		saxi_arprot	: in std_logic_vector(2 downto 0);
		saxi_arvalid	: in std_logic;
		saxi_arready	: out std_logic;
		saxi_rdata	: out std_logic_vector(SAXI_DATA_WIDTH-1 downto 0);
		saxi_rresp	: out std_logic_vector(1 downto 0);
		saxi_rvalid	: out std_logic;
		saxi_rready	: in std_logic
	);
end axi_spi_simple;

architecture arch_imp of axi_spi_simple is
component axi4_lite_interface_v1_0 is
	generic (
	DATA_BUS_IS_64_BITS: integer range 0 to 1 := 0; --0:32b, 1:64b
	--Address space of subordinate, in bits
	ADDR_WIDTH	: integer range 1 to 12	:= 2;
	--whether the slave will use WSTRB
	USE_WRITE_STROBES : boolean := false;
	--subordinate has synchronous read output
	SUBORDINATE_SYNCHRONOUS_READ_PORT: boolean :=true
	);
	port (
	--_AXI SUBORDINATE SIGNALS
		--_AXI SUBORDINATE SIGNALS
	SAXI_ACLK	: in std_logic;
	SAXI_ARESETN	: in std_logic;
	SAXI_AWADDR	: in std_logic_vector(31 downto 0);
	SAXI_AWPROT	: in std_logic_vector(2 downto 0);
    SAXI_AWVALID	: in std_logic;
	SAXI_AWREADY	: out std_logic;
	SAXI_WDATA	: in std_logic_vector(32*(1+DATA_BUS_IS_64_BITS) -1 downto 0);
	SAXI_WSTRB	: in std_logic_vector((4*(1+DATA_BUS_IS_64_BITS))-1 downto 0);
	SAXI_WVALID	: in std_logic;
	SAXI_WREADY	: out std_logic;
	SAXI_BRESP	: out std_logic_vector(1 downto 0);
	SAXI_BVALID	: out std_logic;
	SAXI_BREADY	: in std_logic;
	SAXI_ARADDR	: in std_logic_vector(31 downto 0);
	SAXI_ARPROT	: in std_logic_vector(2 downto 0);
	SAXI_ARVALID	: in std_logic;
	SAXI_ARREADY	: out std_logic;
    SAXI_RDATA	: out std_logic_vector(31 downto 0);
	SAXI_RRESP	: out std_logic_vector(1 downto 0);
	SAXI_RVALID	: out std_logic;
	SAXI_RREADY	: in std_logic;
	--Subordinate Interface
	read_address: out std_logic_vector(ADDR_WIDTH-1 downto 0);
	write_address: out std_logic_vector(ADDR_WIDTH-1 downto 0);
	read_enable: out std_logic;
	write_enable: out std_logic;
	write_strobe: out std_logic_vector((4*(1+DATA_BUS_IS_64_BITS))-1 downto 0);
	read_data: in std_logic_vector(32*(1+DATA_BUS_IS_64_BITS) -1 downto 0);
	write_data: out std_logic_vector(32*(1+DATA_BUS_IS_64_BITS) -1 downto 0);
	clk: out std_logic;
	resetn: out std_logic
	);
	end component;

	-- component declaration
	component spi_peripheral is
		generic (
		GPIO_WIDTH: integer := 32;
        USE_GPIO: boolean:= false;
        ACTIVE_LOW_SS: boolean :=false
		);
		port (
		mosi: out std_logic;
        ss: out std_logic;
        ssn: out std_logic;
        sclk: out std_logic;
        miso: in std_logic;
        gpo: out std_logic_vector(GPIO_WIDTH-1 downto 0);
        write_strobe: in std_logic_vector(3 downto 0);
        read_address: in std_logic_vector(1 downto 0);
        write_address: in std_logic_vector(1 downto 0);
        write_enable: in std_logic;
        read_enable: in std_logic;
        read_data: out std_logic_vector(31 downto 0);
        write_data: in std_logic_vector(31 downto 0);
        clk: in std_logic;
        resetn: in std_logic
		);
	end component spi_peripheral;
   
    signal read_address:  std_logic_vector(1 downto 0);
    signal write_address:  std_logic_vector(1 downto 0);
    signal read_enable:  std_logic;
    signal write_enable:  std_logic;
    signal read_data:  std_logic_vector(31 downto 0);
    signal write_data:  std_logic_vector(31 downto 0);
    signal write_strobe: std_logic_vector(3 downto 0);

    signal clk: std_logic;
    signal resetn: std_logic;
    constant is_64b_data_bus: integer := (SAXI_DATA_WIDTH)/32-1; 
begin

U0: spi_peripheral
generic map(
    USE_GPIO => USE_GPIO,
    GPIO_WIDTH => GPIO_WIDTH,
    ACTIVE_LOW_SS => ACTIVE_LOW_SS
)
port map(
    mosi => mosi,
    miso => miso,
    ssn => ssn,
    ss => ss,
    sclk => sclk,
    gpo => gpo,
    read_address => read_address,
    write_address => write_address,
    read_data => read_data,
    write_data => write_data,
    write_enable => write_enable,
	read_enable => read_enable,
    write_strobe => write_strobe,
    clk => clk,
    resetn => resetn    
);


U1: axi4_lite_interface_v1_0 
generic map(
        DATA_BUS_IS_64_BITS => is_64b_data_bus,
        ADDR_WIDTH	=> 2,--subordinate has 4 registers
        USE_WRITE_STROBES => true,
        SUBORDINATE_SYNCHRONOUS_READ_PORT=> true
	)
	port map(
        SAXI_ACLK=>SAXI_ACLK,
        SAXI_ARESETN=>SAXI_ARESETN,
        SAXI_AWADDR=>SAXI_AWADDR,
        SAXI_AWPROT=>SAXI_AWPROT,
        SAXI_AWVALID=>SAXI_AWVALID,
        SAXI_AWREADY=>SAXI_AWREADY,
        SAXI_WDATA=>SAXI_WDATA,
        SAXI_WSTRB=>SAXI_WSTRB,
        SAXI_WVALID=>SAXI_WVALID,
        SAXI_WREADY=>SAXI_WREADY,
        SAXI_BRESP=>SAXI_BRESP,
        SAXI_BVALID=>SAXI_BVALID,
        SAXI_BREADY=>SAXI_BREADY,
        SAXI_ARADDR=>SAXI_ARADDR,
        SAXI_ARPROT=>SAXI_ARPROT,
        SAXI_ARVALID=>SAXI_ARVALID,
        SAXI_ARREADY=>SAXI_ARREADY,
        SAXI_RDATA=>SAXI_RDATA,
        SAXI_RRESP=>SAXI_RRESP,
        SAXI_RVALID=>SAXI_RVALID,
        SAXI_RREADY=>SAXI_RREADY,
        --Subordinate Interface
        read_address=>read_address,
        read_enable => read_enable,
        write_address=>write_address,
        write_enable=>write_enable,
        read_data=>read_data,
        write_data=>write_data,
        write_strobe=>write_strobe,
        clk=>clk,
        resetn=>resetn
	);

end arch_imp;
