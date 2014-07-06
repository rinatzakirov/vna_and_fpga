library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity multi_purpose_fpga is
	port (
		clk50 : in std_logic;                             -- clock
		reset : in std_logic;                           -- asynchronous reset
		led0  : out std_logic;
		freq_in: in std_logic;
		clk_out: out std_logic;
		sw: in std_logic;

		hd44780_db : out std_logic_vector(7 downto 0) := (others => '0'); -- HD44780 data bus
		hd44780_rw : out std_logic := '0';              -- HD44780 R/W signal
		hd44780_rs : out std_logic := '0';              -- HD44780 RS signal
		hd44780_en : out std_logic := '0'               -- HD44780 EN signal
	);
end altera_freq_counter;
 
architecture arch of multi_purpose_fpga is

begin

end architecture;