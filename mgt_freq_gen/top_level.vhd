library work;
use work.all;
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity top_level is
 port (
    --refclkp, refclkn  :   in std_ulogic;
    hdoutp_ch3, hdoutn_ch3   :   out std_ulogic;
	led0 : out std_ulogic;
	led1 : out std_ulogic;
	led2 : out std_ulogic;
	led4 : out std_ulogic;
	dip0 : in std_ulogic;
	dip1 : in std_ulogic;
	dip2 : in std_ulogic;
	dip3 : in std_ulogic;
	dip4 : in std_ulogic;
    rst_n      :   in std_ulogic;
	X4_IO1: out std_ulogic;
	X4_IO3: in std_logic;
	clk100_p: in std_ulogic
	--clk100_n: in std_ulogic
  );
end top_level;

architecture syn of top_level is

	constant NCO_BITS: integer := 32;

	--constant slow_phase_inc: unsigned(31 downto 0) := to_unsigned(1187713076, 32);-- 34.567Mhz / 125Mhz * 2^32 = 1187713076.17
	--constant fast_phase_inc: unsigned(31 downto 0) := to_unsigned(59385654, 32); -- 34.567Mhz / 125Mhz / 20 * 2^32 = 59385653.8083

	--constant slow_phase_inc: unsigned(47 downto 0) := "010001101100101100010000001101000010101010101010"; -- 34.567Mhz / 125Mhz * 2^48 = 77837964159657.967616 = 77837964159658 = ...
	--constant fast_phase_inc: unsigned(47 downto 0) := "000000111000101000100111001101011100111011101111"; -- 34.567Mhz / 125Mhz / 20 * 2^32 = 59385653.8083

	signal slow_clk, mgt_rst, mgt_rst_qd, txclk, half_clk, full_clk: std_ulogic;
	signal txdata: std_logic_vector(19 downto 0);
	signal txdata_ulogic: std_ulogic_vector(19 downto 0);
	signal count: integer range 0 to 15 := 0;
	signal mgt_pwrup: std_ulogic;
	signal counter: integer range 0 to 9750000 := 0;
	signal refclk2fpga: std_ulogic;
	signal fpga_txrefclk, clk100: std_ulogic;
	signal rst: std_logic;
	
	component ILVDS port(A, AN: in std_logic; Z: out std_logic); end component;
	
	type state_t is (IDLE, GET_Fast0, GET_Fast1, GET_Fast2, GET_Fast3, GET_Slow0, GET_Slow1, GET_Slow2, GET_Slow3);
	signal state: state_t;
	
	signal uart_data: std_logic_vector(7 downto 0);
	signal uart_valid, sig_gen_rst: std_logic;
	
	signal fast_phase_inc, slow_phase_inc: unsigned(31 downto 0);

begin
	rst <= not rst_n;
	mgt_rst <= '0';
	mgt_rst_qd <= '0';
	txclk <= half_clk;
	mgt_pwrup <= '1';
	
	X4_IO1 <= txclk when dip1 = '1' else clk100;
	
	fpga_txrefclk <= clk100;

	uart: entity work.rs232_source_block
	generic map (
		clock_rate    => 125_000_000.0,
		baud_rate     => 460800.0,
		num_stop_bits => 1,
		width         => 8
    )
	port map (
		clk => txclk,
		rst => rst,
		out_data  => uart_data,
		out_valid => uart_valid,
		out_ready => '1',
		rx => X4_IO3
    );
	
	process(txclk)
	begin
		if rising_edge(txclk) then
			if rst_n = '0' then
				state <= IDLE;
			else
				if uart_valid = '1' then
					case state is
					when IDLE =>
						if uart_data = x"F0" then state <= GET_Fast0; end if;
						if uart_data = x"F1" then state <= GET_Fast1; end if;
						if uart_data = x"F2" then state <= GET_Fast2; end if;
						if uart_data = x"F3" then state <= GET_Fast3; end if;
						if uart_data = x"50" then state <= GET_Slow0; end if;
						if uart_data = x"51" then state <= GET_Slow1; end if;
						if uart_data = x"52" then state <= GET_Slow2; end if;
						if uart_data = x"53" then state <= GET_Slow3; end if;
						if uart_data = x"54" then sig_gen_rst <= '1'; end if;
						if uart_data = x"44" then sig_gen_rst <= '0'; end if;
					--
					when GET_Fast0=> fast_phase_inc(7 downto 0) <= unsigned(uart_data); state <= IDLE;
					when GET_Fast1=> fast_phase_inc(15 downto 8) <= unsigned(uart_data); state <= IDLE;
					when GET_Fast2=> fast_phase_inc(23 downto 16) <= unsigned(uart_data); state <= IDLE;
					when GET_Fast3=> fast_phase_inc(31 downto 24) <= unsigned(uart_data); state <= IDLE;
					--
					when GET_Slow0=> slow_phase_inc(7 downto 0) <= unsigned(uart_data); state <= IDLE;
					when GET_Slow1=> slow_phase_inc(15 downto 8) <= unsigned(uart_data); state <= IDLE;
					when GET_Slow2=> slow_phase_inc(23 downto 16) <= unsigned(uart_data); state <= IDLE;
					when GET_Slow3=> slow_phase_inc(31 downto 24) <= unsigned(uart_data); state <= IDLE;
					--
					end case;
				end if;
			end if;
		end if;
	end process;
	
	--process(txclk, rst_n)
	--begin
	--	if rst_n = '0' then
	--		count <= 0;
	--		led0 <= '0';
	--	elsif rising_edge(txclk) then
	--		led0 <= '1';
	--		if count /= 15 then
	--			count <= count + 1;
	--		else
	--			count <= 0;
	--		end if;
	--		--if count < 8 then
	--			--txdata <= (others => '0');
	--			--slow_clk <= '1';
	--		--else
	--			--txdata <= (others => '1');
	--			--slow_clk <= '0';
	--		--end if;
	--	end if;
	--end process;
	
	nco: entity work.parallel_nco
	generic map(
		NCO_BITS => NCO_BITS,
		PARALLEL_BITS => 20
	)
	port map (
		restart => sig_gen_rst, 
		clock => txclk,
		fast_phase_inc => fast_phase_inc,
		slow_phase_inc => slow_phase_inc,
		data => txdata_ulogic
	);
	
	txdata <= std_logic_vector(txdata_ulogic);
	
	--process(slow_clk)
	--begin
	--	if rising_edge(slow_clk) then
	--		if counter /= 9750000 then
	--			counter <= counter + 1;
	--		else
	--			counter <= 0;
	--		end if;
	--		if counter < (9750000 / 2) then
	--			led1 <= '1';
	--		else
	--			led1 <= '0';
	--		end if;
	--	end if;
	--end process;

	
	led4 <= dip0;

	mgt0: entity work.mgt
	port map (
		--refclkp => refclkp,
		--refclkn => refclkn,
		hdoutp_ch3 => hdoutp_ch3,
		hdoutn_ch3 => hdoutn_ch3,
		
		txiclk_ch3         => txclk,
		tx_full_clk_ch3    => full_clk,
		tx_half_clk_ch3    => half_clk,
		txdata_ch3         => txdata,
		tx_pwrup_ch3_c     => mgt_pwrup,
		tx_div2_mode_ch3_c => dip0,
		tx_serdes_rst_c    => mgt_rst,
		tx_pll_lol_qd_s    => led2,
		rst_n              => rst_n,
		refclk2fpga        => refclk2fpga,
		serdes_rst_qd_c    => mgt_rst_qd,
		fpga_txrefclk      => fpga_txrefclk
	);
	
	clk100 <= clk100_p;
   --clk100buf: ILVDS port map(A => clk100_p, AN => clk100_n, Z => clk100);

end architecture;