library work;
use work.all;
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity parallel_nco is
 generic (
	NCO_BITS: integer := 48;
	PARALLEL_BITS: integer := 20
 );
 port (
    restart: in std_ulogic;
	clock: in std_ulogic;
	fast_phase_inc: in unsigned(NCO_BITS - 1 downto 0);
	slow_phase_inc: in unsigned(NCO_BITS - 1 downto 0);
	data: out std_ulogic_vector(PARALLEL_BITS - 1 downto 0)
  );
end entity;

architecture syn of parallel_nco is

	type phases is array(integer range 0 to PARALLEL_BITS - 1) of unsigned(NCO_BITS - 1 downto 0);
	signal reset_phases: phases;	
	signal restart_reg: std_logic_vector(4 downto 0);
	signal current_phase: unsigned(NCO_BITS - 1 downto 0);
	signal reset: std_logic;
	signal filler_index: integer range 0 to PARALLEL_BITS - 1;

begin

	process(clock)
	begin
		if rising_edge(clock) then
			restart_reg <= restart_reg(3 downto 0) & restart;
			if restart_reg(4) = '1' then
				reset <= '1';
				filler_index <= 0;
				current_phase <= to_unsigned(0, NCO_BITS);
			end if;
			
			if reset = '1' then
				if filler_index = PARALLEL_BITS - 1 then
					reset <= '0';
				else
					filler_index <= filler_index + 1;
				end if;
				reset_phases(filler_index) <= current_phase;
				current_phase <= current_phase + fast_phase_inc;
			end if;
		end if;
	end process;

	loop_i: for i in 0 to PARALLEL_BITS - 1 generate 
		phase_accum_i: entity work.phase_accum
		generic map(
			NCO_BITS => NCO_BITS
		)
		port map (
			reset => reset,
			clock => clock,
			reset_phase => reset_phases(i),
			phase_inc => slow_phase_inc,
			sig => data(i)
		);
	end generate;
	
end architecture;