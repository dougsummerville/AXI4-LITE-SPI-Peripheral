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

entity spi_peripheral is
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

        read_address: in std_logic_vector(1 downto 0);
        write_address: in std_logic_vector(1 downto 0);
        write_enable: in std_logic;
        read_enable: in std_logic;
        read_data: out std_logic_vector(31 downto 0);
        write_data: in std_logic_vector(31 downto 0);
        write_strobe: in std_logic_vector(3 downto 0);
        clk: in std_logic;
        resetn: in std_logic
    );
end spi_peripheral;

architecture arch_imp of spi_peripheral is


	signal reg0	:std_logic_vector(31 downto 0);
	signal reg1	:std_logic_vector(31 downto 0);
	signal reg2	:std_logic_vector(31 downto 0);
	signal reg3	:std_logic_vector(31 downto 0);

	--SPI SIGNALS
	signal spidata_reg, spirxbuf_reg: std_logic_vector(7 downto 0);
	signal sptef,sptef_ack: std_logic; --transmission complete and SPI tx buf empty
    signal sprf, sprf_ack, sprf_set: std_logic; --spi read buffer full
    signal spi_busy: std_logic;
    signal baud_cntr: integer;
    TYPE SPI_STATE_TYPE IS (ST_IDLE, ST_SS_START, ST_BIT1, ST_BIT2, ST_SS_END, ST_RESTART );
    SIGNAL state   : SPI_STATE_TYPE;
    signal bit_cntr : integer;

    alias CPOL : std_logic is reg2(17);
    alias CPHA : std_logic is reg2(16);
    alias LOOPBACK : std_logic is reg2(18);
    alias LSBF: std_logic is reg2(19);
    alias BAUD_DVSR: std_logic_vector(15 downto 0) is reg2(15 downto 0);
    signal miso_sync: std_logic_vector(2 downto 0);
    signal ssn_sig: std_logic;
    signal data_in: std_logic;
    signal baud_clk: std_logic;
    signal spi_sample, spi_shift,spi_data: std_logic;
begin
	-- I/O Connections assignments
    data_in <= miso_sync(0) when LOOPBACK = '0' else spidata_reg(7);
    gpo <= reg3(GPIO_WIDTH-1 downto 0) when USE_GPIO = true else (others => '0');
	ss <= not ssn_sig when ACTIVE_LOW_SS = false else '0';
	ssn <= ssn_sig when ACTIVE_LOW_SS = true else '1';



	process (clk)
	begin
	  if rising_edge(clk) then 
	    if resetn = '0' then
	      reg0 <= (others => '0');
	      reg1 <= (others => '0');
	      reg2 <= (others => '0');
	      reg3 <= (others => '0');
	      sptef <='1';
	    else
	      if (write_enable = '1') then
	        case write_address is
	        --slv_reg 0 write is TX data; bit 8 is 
	          when b"00" => --slv_reg0 write is TX data and 
	              if ( write_strobe(0) = '1' ) then
	                reg0(7 downto 0) <= write_data(7 downto 0);
	                sptef <='0';
	              end if;
	              if ( write_strobe(1) = '1' ) then
	                reg0(15 downto 8) <= (others => '0');
	              end if;
	              if ( write_strobe(2) = '1' ) then
	                reg0(23 downto 16) <= (others => '0');
	             end if;
                 if ( write_strobe(3) = '1' ) then
	                reg0(31 downto 24) <= (others => '0');
                 end if;
	          when b"01" => --read only status register
	            reg1 <= (others => '0'); --register always 0 should be synthesized out
	          when b"10" =>
	              if ( write_strobe(0) = '1' ) then
	                reg2(7 downto 0) <= write_data(7 downto 0);
	              end if;
	              if ( write_strobe(1) = '1' ) then
	                reg2(15 downto 8) <= write_data(15 downto 8);
	              end if;
	              if ( write_strobe(2) = '1' ) then
	                reg2(23 downto 16) <= (others => '0');
                    reg2(19 downto 16) <= write_data(19 downto 16);
	             end if;
                 if ( write_strobe(3) = '1' ) then
	                reg3(31 downto 24) <= (others => '0');
                 end if;

	          when b"11" => --16 bit baud divisor register
	            if USE_GPIO then
	              for byte_index in 0 to 3 loop
	              if ( write_strobe(byte_index) = '1' AND byte_index * 8 < GPIO_WIDTH) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 3
	                reg3(byte_index*8+7 downto byte_index*8) <= write_data(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	            else
	              reg3 <= (others => '0'); --stuck at zero should synthesize out
	            end if;
	          when others =>
                  null;
	        end case;
	      end if;
	    end if;
	    if sptef_ack = '1' then
	      sptef <= '1';
	    end if;
	  end if;                   
	end process; 


--SPI peripheral asynchronous read port
	process (reg0, reg1, reg2, reg3, read_address, resetn, sptef,sprf,spirxbuf_reg)
	begin
	    -- Address decoding for reading registers
	    sprf_ack <= '0';
	    case read_address is
	      when b"00" =>
	        read_data <= (others => '0');
	        read_data(7 downto 0) <= spirxbuf_reg;
	      when b"01" =>
	        read_data <= (others => '0');
	        read_data(0) <= sptef;
	        read_data(1) <= sprf;
	        read_data(2) <= spi_busy;
	        sprf_ack <= '1'; --read clears sprf
	      when b"10" =>
	        read_data <= (others => '0');
	        read_data(19 downto 0) <= reg2(19 downto 0);
	      when b"11" =>
	        read_data <= reg3;
	      when others =>
	        read_data  <= (others => '0');
	    end case;
	end process; 

	-- SPRF flag register
	process( clk ) is
	begin
	  if (rising_edge (clk)) then
	    if ( resetn = '0' ) then
	      sprf <= '0';
	    else
	      if read_enable='1' then
	          if sprf_ack = '1' then
	             sprf <= '0';
	          end if;  	   
	      end if;   
	      if sprf_set = '1' then
	          sprf <= '1';
	      end if;
	    end if;
	  end if;
	end process;

	--spi data register
    mosi <= spidata_reg(7) when LSBF='0' else spidata_reg(0);
	process( clk ) is
	  variable spi_control: std_logic_vector(1 downto 0);
	begin
	  if (rising_edge (clk)) then
	    if ( resetn = '0' ) then
	      spidata_reg  <= (others => '0');
	      spi_data <= '0';
	    else
	      if spi_sample = '1' then 
	        spi_data <= data_in; --sampled data on miso
	      end if;
	      spi_control := spi_shift & sptef_ack; 
          case spi_control is
            when "10" => 
              if LSBF = '0' then
                spidata_reg <= spidata_reg(6 downto 0) & spi_data;
              else
                spidata_reg <= spi_data & spidata_reg(7 downto 1);
              end if;
            when "01" => null;
              spidata_reg <= reg0(7 downto 0);
            when others=> null;
          end case;
	    end if;
	  end if;
	end process;


	baud_clk <= '1' when baud_cntr = 0 else '0';
	process( clk ) is
	begin
	  if (rising_edge (clk)) then
	  --miso sync
	    miso_sync <= miso & miso_sync(2 downto 1);
	    if ( resetn = '0' ) then
          state <= ST_IDLE;
	    else
	      --baud clock endbler
	      if state = ST_IDLE OR baud_cntr = 0 then --don't count while idle
	        baud_cntr <=   to_integer(unsigned(BAUD_DVSR));
          else
            baud_cntr <= baud_cntr - 1;
          end if; 
        -----------------------------------------------------
        --state machine
        -----------------------------------------------------
          --defaults
          sptef_ack <= '0';
          sclk <= CPOL;
          sprf_set <= '0';
          ssn_sig<='0';
          spi_sample<='0';
          spi_shift <='0';
          spi_busy<='1';
          --state logic
          case state is
           when ST_IDLE=> --SPI is IDLE
            ssn_sig <= '1';
            spi_busy<='0'; 
            if sptef = '0' then 
                state <= ST_SS_START;
                sptef_ack <= '1';
            end if;
           when ST_SS_START=> --SS aserted; CPHA=0 SETUP
            if baud_clk='1' then 
              state <= ST_BIT1;
              bit_cntr <= 0;
              if CPHA = '0' then
                spi_sample <= '1';
              end if;
            end if;
           when ST_BIT1=> --CPHA=0 HOLD, CPHA1=SETUP
            sclk <= not CPOL; 
            if baud_clk='1' then 
              state <= ST_BIT2;
              if CPHA = '0' then
                spi_shift <= '1';
              else
                spi_sample <= '1';
              end if;
            end if;
            when ST_BIT2=>  --CPHA=0 SETUP, CPHA1=HOLD
             sclk <= CPOL; 
             if baud_clk='1' then
               if CPHA = '1' then
                 spi_shift <= '1';
               else
                 spi_sample <= '1';
               end if; 
               if bit_cntr = 7 then
                 state <= ST_SS_END;
               else
                 bit_cntr <= bit_cntr + 1;
                 state <= ST_BIT1;
               end if;
              end if;
             when ST_SS_END=> --CPHA=1 HOLD
              if baud_clk='1' then
                if CPHA = '1' then
                   spi_shift <= '1';
                end if;
                state <= ST_RESTART;
              end if;
             when ST_RESTART=> --ALLOW SS to remain low between xfers; bypass idle state if SPTEF
                 sprf_set <= '1';
                 spirxbuf_reg <= spidata_reg;
                if sptef = '0' then 
                    state <= ST_SS_START;
                    sptef_ack <= '1';
                else
                    state <= ST_IDLE;
                end if;
              when others=> --should not happen but allows reset
                state <= ST_IDLE;              
          end case;
	    end if;
	  end if;
	end process;
	-- User logic ends

end arch_imp;
