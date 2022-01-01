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

entity axi4_lite_interface_v1_0 is
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
    SAXI_RDATA	: out std_logic_vector(32*(1+DATA_BUS_IS_64_BITS) -1 downto 0);
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
end axi4_lite_interface_v1_0;

architecture arch_imp of axi4_lite_interface_v1_0 is

	signal awready	: std_logic;
	signal wready	: std_logic;
	signal bresp	: std_logic_vector(1 downto 0);
	signal bvalid	: std_logic;
	signal arready	: std_logic;
    signal rdata	: std_logic_vector(32*(1+DATA_BUS_IS_64_BITS)-1 downto 0);
	signal rresp	: std_logic_vector(1 downto 0);
	signal rvalid	: std_logic;
	signal sig_read_enable: std_logic;
    
    type subordinate_register_array is array( 0 to 2**ADDR_WIDTH -1) of std_logic_vector(32*(1+DATA_BUS_IS_64_BITS)-1 downto 0); 
	signal reg	: subordinate_register_array;

    constant REG_ADDR_lsb: integer := 2*(1+DATA_BUS_IS_64_BITS);
    constant REG_ADDR_msb: integer := REG_ADDR_lsb + ADDR_WIDTH-1; 
	signal read_addr_stall_reg: std_logic_vector(REG_ADDR_msb downto REG_ADDR_lsb);
    signal write_addr_stall_reg:std_logic_vector(REG_ADDR_msb downto REG_ADDR_lsb);
    signal write_data_stall_reg:std_logic_vector(32*(1+DATA_BUS_IS_64_BITS)-1 downto 0);
    signal write_strobe_stall_reg: std_logic_vector((4*(1+DATA_BUS_IS_64_BITS))-1 downto 0);
    signal write_channel_backpressure: std_logic;
    --convenience constants
    
    --local translation to register address
    alias local_read_addr: std_logic_vector(REG_ADDR_msb downto REG_ADDR_lsb) is SAXI_ARADDR(REG_ADDR_msb downto REG_ADDR_lsb);
    alias local_write_addr: std_logic_vector(REG_ADDR_msb downto REG_ADDR_lsb) is SAXI_AWADDR(REG_ADDR_msb downto REG_ADDR_lsb);
begin
	SAXI_AWREADY<= awready;
	SAXI_WREADY	<= wready;
	SAXI_BRESP	<= bresp;
	SAXI_BVALID	<= bvalid;
	SAXI_ARREADY<= arready;
	SAXI_RDATA	<= rdata;
	SAXI_RRESP	<= rresp;
	SAXI_RVALID	<= rvalid;
    read_enable <= sig_read_enable;
    --subordinate in the same clock domain
    clk <= SAXI_ACLK;
    resetn <= SAXI_ARESETN;

    --read address channel
    process(SAXI_ACLK) begin
        if rising_edge(SAXI_ACLK) then
            if SAXI_ARESETN = '0' then
                arready<='1';
            elsif arready='0' and SAXI_RREADY='1' then --exiting read stall
                arready <= '1';
            elsif rvalid='1' AND SAXI_RREADY='0' and SAXI_ARVALID='1' and arready='1' then
                --capture the read address and stop accepting new addresses 
                read_addr_stall_reg<=local_read_addr;
                arready<='0';
            end if;
        end if;
    end process;

    --subordinate read signals must be asynchronous out so the subordinate gets them in the current clock cycle
    process(arready,SAXI_RREADY,rvalid,read_addr_stall_reg,SAXI_ARVALID,local_read_addr) begin
        read_enable <= '0';
        read_address <= (others => '-');
        --start new transaction
        if arready='0' and SAXI_RREADY='1' and rvalid='1' then  --coming out of stall
            read_address <= read_addr_stall_reg;
            read_enable <= '1';
        --new read request and either channel is flowing or not being used 
        elsif arready='1'  and SAXI_ARVALID='1' and (SAXI_RREADY='1' OR rvalid='0') then
            read_address <= local_read_addr;
            read_enable <= '1';
        end if;  
    end process;
    
    --read data channel
    --if the peripheral has a synchronous output then timing requires we connect that directly to SAXI_RDAYA
    gen_read_port: if (SUBORDINATE_SYNCHRONOUS_READ_PORT) generate
        rdata<= read_data;
    end generate;
    --otherwise, we create an output regoster
    gen_read_port_else: if (NOT SUBORDINATE_SYNCHRONOUS_READ_PORT) generate
        process(SAXI_ACLK) begin
            if rising_edge(SAXI_ACLK) then
                if SAXI_ARESETN = '0' then
                    rdata<=(others => '0'); 
                elsif sig_read_enable='1' then
                    rdata<=read_data; 
                end if;
            end if;
        end process;
    end generate;

    process(SAXI_ACLK) begin
        if rising_edge(SAXI_ACLK) then
            if SAXI_ARESETN = '0' then
                rvalid<='0'; --required by spec
            else
                --complete handshake
                if rvalid='1' and SAXI_RREADY='1' then
                    rvalid<='0';
                end if;
                --start new transaction
                if arready='0' and SAXI_RREADY='1' and rvalid='1' then  --coming out of stall
                    rvalid <= '1';
                --new read request and either channel is flowing or not being used 
                elsif arready='1'  and SAXI_ARVALID='1' and (SAXI_RREADY='1' OR rvalid='0') then
                    rvalid <= '1';
                end if;  
            end if;
        end if;
    end process;

    


	bresp <= (others => '0');
	rresp<= (others => '0');

    --write address channel
    process(SAXI_ACLK) begin
    if rising_edge(SAXI_ACLK) then
        if SAXI_ARESETN = '0' then
            awready<='1';
        elsif awready='0' and (SAXI_WVALID='1' OR wready='0') and SAXI_BREADY='1' then 
            awready <= '1';
        elsif SAXI_AWVALID='1' and not ( SAXI_WVALID='1' and SAXI_BREADY='1') then
            --capture the read address and stop accepting new addresses 
            write_addr_stall_reg<=local_write_addr;
            awready<='0';
        end if;
    end if;
    end process;
    
    --write data channel
    process(SAXI_ACLK) begin
    if rising_edge(SAXI_ACLK) then
        if SAXI_ARESETN = '0' then
            wready<='1';
        elsif wready='0' and (SAXI_AWVALID='1' OR awready='0') and SAXI_BREADY='1' then 
            wready <= '1';
        elsif SAXI_WVALID='1' and not ( SAXI_AWVALID='1' and SAXI_BREADY='1') then
            --capture the read address and stop accepting new addresses 
            write_data_stall_reg<=SAXI_WDATA;
            if USE_WRITE_STROBES then
                write_strobe_stall_reg <= SAXI_WSTRB;
            end if;
            wready<='0';
        end if;
    end if;
    end process;
    
    --write response channel
    process(SAXI_ACLK) 
    begin
    if rising_edge(SAXI_ACLK) then
        if SAXI_ARESETN = '0' then
            bvalid<='0'; --required by spec
        else
            --complete handshake
            if bvalid='1' and SAXI_BREADY='1' then
                bvalid<='0';
            end if;
            --start new transaction (SIMPLIFY)
            if awready='0' and wready='0' and SAXI_BREADY='1' then
                bvalid<='1';
            elsif awready='0' and SAXI_WVALID='1' and SAXI_BREADY='1' then
                bvalid<='1';
            elsif SAXI_AWVALID='1' and wready='0' and SAXI_BREADY='1' then
                bvalid<='1';
            elsif  SAXI_AWVALID='1' and SAXI_WVALID='1' and SAXI_BREADY='1' then
                bvalid<='1';
            end if;
        end if;
    end if;
    end process;
    
    process(awready,wready,SAXI_BREADY,write_addr_stall_reg,write_data_stall_reg,write_strobe_stall_reg,SAXI_WDATA,SAXI_WSTRB,SAXI_WVALID,
        SAXI_AWVALID,local_write_addr) 
    begin
        --start new transaction (reverse priority of if's)
        
        if awready='0' and wready='0' and SAXI_BREADY='1' then
           write_address <= write_addr_stall_reg;
           write_data <= write_data_stall_reg;
           write_strobe <= write_strobe_stall_reg;
           write_enable <= '1';
        elsif awready='0' and SAXI_WVALID='1' and SAXI_BREADY='1' then
            write_address <=write_addr_stall_reg;
            write_data <= SAXI_WDATA;
            write_strobe <= SAXI_WSTRB;
            write_enable <= '1';
        elsif SAXI_AWVALID='1' and wready='0' and SAXI_BREADY='1' then
            write_address <= local_write_addr;
            write_data <= write_data_stall_reg;
           write_strobe <= write_strobe_stall_reg;
            write_enable <= '1';
        elsif  SAXI_AWVALID='1' and SAXI_WVALID='1' and SAXI_BREADY='1' then
            write_address <= local_write_addr;
            write_data <= SAXI_WDATA;
            write_strobe <= SAXI_WSTRB;
            write_enable <= '1';
        else
            write_enable <= '0';
            write_address <= (others => '-');
            write_data <= (others => '-');
            write_strobe <= (others => '-');
        end if;
    end process;
    


end arch_imp;