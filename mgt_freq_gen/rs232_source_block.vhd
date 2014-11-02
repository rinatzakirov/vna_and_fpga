--
-- Copyright 2008 FlexHDR Team
--
-- This file is part of FlexHDR.
--
-- FlexHDR is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- FlexHDR is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with FlexHDR. If not, see <http://www.gnu.org/licenses/>.
--
------------------------------------------------------------------------------
--RS232 Source Block
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;

--library flexhdr;
--use flexhdr.common.all;

------------------------------------------------------------------------------
--@category Sources
--@name "RS232 Source"
--@doc{
--@ Note: This block will drop bytes if the sink is not ready!
--@
--@ The width of the data out is the number of data bits.
--@}
entity rs232_source_block is
  generic (
    clock_rate    : real     := 100_000_000.0;
    baud_rate     : real     := 9600.0;
    num_stop_bits : positive := 1;
    width         : positive := 8
    );
  port (
    clk : in std_logic;
    rst : in std_logic;

    --@name out
    --@source slv_stream{
    out_data  : out std_logic_vector(width-1 downto 0);
    out_valid : out std_logic;
    out_ready : in  std_logic;
    --@}

    rx : in std_logic                   --rx pin from rs232
    );
end entity rs232_source_block;

------------------------------------------------------------------------------
architecture syn of rs232_source_block is
  constant quiescent_level                       : std_logic_vector(width+1 downto 0) := (others => '1');
  signal   shreg, shreg_next                     : std_logic_vector(width+1 downto 0);
  --calculate divisors
  constant actual_divisor                        : real                               := clock_rate/baud_rate;
  constant delta_divisor                         : real                               := actual_divisor - round(actual_divisor);
  constant approx_divisor                        : natural                            := natural(round(actual_divisor));
  signal   divisor_counter, divisor_counter_next : natural range 0 to approx_divisor-1;
  --calculate start bit offset
  constant start_bit_offset : natural := natural(round(
    actual_divisor/2.0 +                --half of actual divisor plus...
    delta_divisor*real(width+2)/2.0     --half of total divisor error
    ));
  signal start_bit_counter, start_bit_counter_next : natural range 0 to start_bit_offset-1;
  --rs232 state machine
  type   rs232_state_type is (WAIT_FOR_START, WAIT_FOR_START_OFF, SHIFT_SAMPLES, RELEASE_SAMPLE);
  signal rs232_state                               : rs232_state_type;
  signal out_valid_i                               : std_logic;
begin
  --internal signals
  out_valid              <= out_valid_i;
  --next signals
  shreg_next             <= rx & shreg(width+1 downto 1);
  divisor_counter_next   <= 0   when divisor_counter = approx_divisor-1     else divisor_counter + 1;
  start_bit_counter_next <= 0   when start_bit_counter = start_bit_offset-1 else start_bit_counter + 1;
  --flags
  out_valid_i            <= '1' when rs232_state = RELEASE_SAMPLE           else '0';
  out_data               <= shreg(width downto 1);
  -------------------------------------------
  --Process to shift bits
  -------------------------------------------
  Shifter : process(clk)
  begin
    if rising_edge(clk) then
      RS232State : case rs232_state is
        --stay in this state until we see a low signal
        when WAIT_FOR_START =>
          if rx = '0' then
            rs232_state <= WAIT_FOR_START_OFF;
          end if;
          start_bit_counter <= 0;
          --stay in state for start_bit_offset cycles
        when WAIT_FOR_START_OFF =>
          start_bit_counter <= start_bit_counter_next;
          if start_bit_counter = start_bit_offset-1 then
            rs232_state <= SHIFT_SAMPLES;
          end if;
          divisor_counter <= 0;
          shreg           <= '0' & quiescent_level(width downto 0);
          --stay in state until the LSB contains the start bit
        when SHIFT_SAMPLES =>
          divisor_counter <= divisor_counter_next;
          if divisor_counter = approx_divisor-1 then
            shreg <= shreg_next;
          end if;
          if divisor_counter = approx_divisor-1 and shreg_next(0) = '0' then
            rs232_state <= RELEASE_SAMPLE;
          end if;
          --stay in state until sample is released
        when RELEASE_SAMPLE =>
          if out_ready = '1' and out_valid_i = '1' then
            rs232_state <= WAIT_FOR_START;
          end if;
      end case RS232State;

      if rst = '1' then
        shreg             <= '0' & quiescent_level(width downto 0);
        divisor_counter   <= 0;
        start_bit_counter <= 0;
        rs232_state       <= WAIT_FOR_START;
      end if;
    end if;
  end process Shifter;
end architecture syn;
