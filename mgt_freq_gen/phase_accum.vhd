library work;
use work.all;
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity phase_accum is
 generic (
	NCO_BITS: integer := 48
 );
 port (
    reset: in std_ulogic;
	clock: in std_ulogic;
	reset_phase: in unsigned(NCO_BITS - 1 downto 0);
	phase_inc: in unsigned(NCO_BITS - 1 downto 0);
	sig: out std_ulogic
  );
end entity;

architecture syn of phase_accum is

	signal current_phase: unsigned(NCO_BITS - 1 downto 0);

begin

	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
				current_phase <= reset_phase;
			else
				current_phase <= current_phase + phase_inc;
			end if;
			sig <= current_phase(NCO_BITS - 1);
		end if;
	end process;
	
end architecture;